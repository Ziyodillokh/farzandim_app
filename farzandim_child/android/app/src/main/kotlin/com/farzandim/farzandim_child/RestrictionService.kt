package com.farzandim.farzandim_child

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

/**
 * App restriction foreground service — Sprint 4.2 implementation.
 *
 * Polling cycle (har 3 sek):
 *   1. SharedPreferences'dan bloklangan paket nomlar Set'ini o'qish
 *      (Dart RestrictionsSyncService Firestore stream'dan yozadi)
 *   2. UsageStatsManager.queryEvents'dan oxirgi foreground app
 *   3. Foreground app bloklanganmi?
 *      Ha → showOverlay (TYPE_APPLICATION_OVERLAY)
 *      Yo'q → hideOverlay (ko'rinib turgan bo'lsa)
 *
 * Overlay UI:
 *   - To'liq ekran qora overlay
 *   - Markazda lock icon + matn "Bu ilova bloklangan"
 *   - "Yopish" tugmasi (HOME intent yuboradi)
 *
 * Sharthsharoit:
 *   - PACKAGE_USAGE_STATS permission yoqilgan bo'lishi shart
 *   - SYSTEM_ALERT_WINDOW permission yoqilgan bo'lishi shart
 *   - Android 8+ (API 26+) uchun yozilgan
 */
class RestrictionService : Service() {

    companion object {
        private const val TAG = "RestrictionService"
        private const val CHANNEL_ID = "farzandim_restriction"
        private const val NOTIFICATION_ID = 4242
        // 1 sek — bloklangan ilova ochilganda overlay tezroq chiqsin
        // (avval 3 sek edi → "sal kechroq ochilyapti" muammosi).
        private const val POLL_INTERVAL_MS = 1000L

        const val ACTION_START = "com.farzandim.action.START_RESTRICTION"
        const val ACTION_STOP = "com.farzandim.action.STOP_RESTRICTION"

        // SharedPreferences key — Dart RestrictionsSyncService yozadi.
        // Schema: "com.app1,com.app2,..." (comma-separated)
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PREFS_KEY_BLOCKED = "flutter.restriction.blocked_packages"
        private const val PREFS_KEY_LIMITS = "flutter.restriction.limits"

        // "Notanish manbalardan ilovalar" — Play'dan boshqa manbadagi
        // ilovalarni bloklash flag'i (Dart device-policy sync yozadi).
        private const val PREFS_KEY_BLOCK_UNKNOWN =
            "flutter.restriction.block_unknown_sources"

        // Ruxsat etilgan o'rnatuvchilar (rasmiy do'konlar) — bulardan
        // o'rnatilgan ilovalar bloklanmaydi. Qolgani "notanish manba".
        private val ALLOWED_INSTALLERS = setOf(
            "com.android.vending",             // Google Play
            "com.google.android.feedback",     // Play (ba'zi qurilmalar)
            "com.sec.android.app.samsungapps", // Samsung Galaxy Store
            "com.huawei.appmarket",            // Huawei AppGallery
            "com.amazon.venezia",              // Amazon Appstore
            "com.xiaomi.market",               // Xiaomi GetApps
            "com.heytap.market",               // Oppo/Realme App Market
            "com.vivo.appstore",               // Vivo App Store
        )
    }

    private val handler = Handler(Looper.getMainLooper())
    private var isRunning = false

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var currentBlockedPackage: String? = null

    // Install-source kesh (paket → noma'lum manbami). O'rnatish manbasi
    // o'zgarmaydi, shuning uchun bir marta hisoblab keshlaymiz (har 3s
    // PackageManager chaqirmaslik uchun).
    private val unknownSourceCache = HashMap<String, Boolean>()

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!isRunning) return

            try {
                checkRestrictions()
            } catch (e: Exception) {
                Log.e(TAG, "Poll error", e)
            }

            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        createNotificationChannel()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startMonitoring()
            ACTION_STOP -> stopMonitoring()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
        stopMonitoring()
    }

    private fun startMonitoring() {
        if (isRunning) return

        Log.d(TAG, "Monitoring started")

        val notification = buildNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        isRunning = true
        handler.post(pollRunnable)
    }

    private fun stopMonitoring() {
        Log.d(TAG, "Monitoring stopped")
        isRunning = false
        handler.removeCallbacks(pollRunnable)
        hideOverlay()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    /**
     * Polling cycle asosiy logikasi — 2 turdagi restriction:
     *   1. Hard block (isBlocked: true) — paket nomi ro'yxatda bo'lsa
     *      darhol overlay
     *   2. Time-based limit (limitMinutes > 0) — paket foreground bo'lsa
     *      UsageStatsManager bilan bugungi vaqtni hisoblab, limit'dan
     *      oshgan bo'lsa overlay
     */
    private fun checkRestrictions() {
        val blocked = readBlockedPackages()
        val limits = readLimits() // Map<String, Int> minutes
        val blockUnknown = readBlockUnknown()

        if (blocked.isEmpty() && limits.isEmpty() && !blockUnknown) {
            hideOverlay()
            return
        }

        val foreground = getForegroundPackage() ?: return

        // O'zining app'ini block qilmaslik (overlay loop'dan saqlash).
        if (foreground == packageName) {
            hideOverlay()
            return
        }

        // 1. Hard block check (prioritet — har holatda overlay)
        //    "*" wildcard — Schedule whole-window BLOCK (Sprint 4.4.25).
        //    Har qanday foreground'ga overlay.
        if (foreground in blocked || "*" in blocked) {
            if (currentBlockedPackage != foreground) {
                showOverlay(foreground)
                currentBlockedPackage = foreground
            }
            return
        }

        // 2. Time-based limit check
        val limitMinutes = limits[foreground]
        if (limitMinutes != null && limitMinutes > 0) {
            val usageMs = getTodayUsageMs(foreground)
            val limitMs = limitMinutes * 60L * 1000L
            if (usageMs >= limitMs) {
                if (currentBlockedPackage != foreground) {
                    Log.d(
                        TAG,
                        "Limit oshdi: $foreground ${usageMs / 60000} min " +
                            ">= $limitMinutes min",
                    )
                    showOverlay(foreground)
                    currentBlockedPackage = foreground
                }
                return
            }
        }

        // 2b. "Notanish manbalardan ilovalar" — Play/rasmiy do'kondan
        //     bo'lmagan (sideload APK) ilova bo'lsa bloklash.
        if (blockUnknown && isUnknownSource(foreground)) {
            if (currentBlockedPackage != foreground) {
                Log.d(TAG, "Notanish manba bloklandi: $foreground")
                showOverlay(foreground)
                currentBlockedPackage = foreground
            }
            return
        }

        // 3. Bloklanmagan va limit oshmagan — overlay yopamiz
        if (overlayView != null) {
            hideOverlay()
        }
    }

    /** SharedPreferences'dan "notanish manba bloklash" flag'i. */
    private fun readBlockUnknown(): Boolean {
        val prefs: SharedPreferences =
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(PREFS_KEY_BLOCK_UNKNOWN, false)
    }

    /**
     * Ilova "notanish manba"danmi (Play/rasmiy do'kon emas)?
     *   - Tizim/oldindan o'rnatilgan ilovalar → ruxsat (false).
     *   - Rasmiy do'kondan (ALLOWED_INSTALLERS) → ruxsat (false).
     *   - Aks holda (sideload APK / null) → notanish manba (true).
     * Aniqlay olmasak — bloklamaymiz (false), false-positive xavfi.
     */
    private fun isUnknownSource(pkg: String): Boolean {
        unknownSourceCache[pkg]?.let { return it }
        return try {
            val pm = packageManager
            val ai = pm.getApplicationInfo(pkg, 0)
            val isSystem = (ai.flags and
                (ApplicationInfo.FLAG_SYSTEM or
                    ApplicationInfo.FLAG_UPDATED_SYSTEM_APP)) != 0
            val unknown: Boolean
            if (isSystem) {
                unknown = false
                Log.d(TAG, "install-source: $pkg = SYSTEM (ruxsat)")
            } else {
                val installer: String? =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        pm.getInstallSourceInfo(pkg).installingPackageName
                    } else {
                        @Suppress("DEPRECATION")
                        pm.getInstallerPackageName(pkg)
                    }
                unknown = installer == null || installer !in ALLOWED_INSTALLERS
                Log.d(
                    TAG,
                    "install-source: $pkg installer=$installer unknown=$unknown",
                )
            }
            // Faqat MUVAFFAQIYATLI aniqlashda keshlaymiz — xato bo'lsa
            // keshlamaymiz (keyingi pollda qayta urinadi, fail-open emas).
            unknownSourceCache[pkg] = unknown
            unknown
        } catch (e: Exception) {
            Log.w(TAG, "install-source aniqlanmadi: $pkg — ${e.message}")
            false
        }
    }

    private fun readBlockedPackages(): Set<String> {
        val prefs: SharedPreferences =
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(PREFS_KEY_BLOCKED, null) ?: return emptySet()
        return raw.split(",").mapNotNull { it.trim().ifBlank { null } }.toSet()
    }

    /**
     * "com.youtube:15,com.instagram:30" → {com.youtube=15, com.instagram=30}
     */
    private fun readLimits(): Map<String, Int> {
        val prefs: SharedPreferences =
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(PREFS_KEY_LIMITS, null) ?: return emptyMap()
        if (raw.isBlank()) return emptyMap()

        return raw.split(",")
            .mapNotNull { entry ->
                val parts = entry.split(":")
                if (parts.size != 2) return@mapNotNull null
                val pkg = parts[0].trim()
                val min = parts[1].trim().toIntOrNull()
                if (pkg.isBlank() || min == null) null else pkg to min
            }
            .toMap()
    }

    /**
     * Bugun (00:00 dan hozirgacha) paket EKRANDA FAOL foreground'da bo'lgan
     * vaqt (ms). Event-based (queryEvents) — UsageStatsPlugin.getUsageStats
     * bilan bir xil mantiq: faqat ekran yoniq paytdagi haqiqiy foreground
     * sessiyalari. Fon-service / fon activity launch hisoblanmaydi (aks holda
     * limit noto'g'ri ishlardi).
     */
    private fun getTodayUsageMs(packageName: String): Long {
        return try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE)
                as UsageStatsManager

            // Kun chegarasi — Toshkent (Asia/Tashkent, UTC+5). Ota-ona ilovasi
            // va backend "bugun"ni Toshkent bo'yicha hisoblaydi; enforcement
            // ham ayni shu chegarani ishlatishi shart (aks holda yarim kechada
            // limit noto'g'ri reset bo'ladi yoki usage mos kelmaydi).
            val cal = java.util.Calendar.getInstance(
                java.util.TimeZone.getTimeZone("Asia/Tashkent"),
            ).apply {
                set(java.util.Calendar.HOUR_OF_DAY, 0)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
            }
            val startOfDay = cal.timeInMillis
            val now = System.currentTimeMillis()

            val events = usm.queryEvents(startOfDay, now)
            val ev = UsageEvents.Event()
            var total = 0L
            var openStart = 0L // >0 → paket hozir foreground'da
            var screenInteractive = true
            while (events.hasNextEvent()) {
                events.getNextEvent(ev)
                val t = ev.timeStamp
                when (ev.eventType) {
                    UsageEvents.Event.ACTIVITY_RESUMED -> {
                        if (ev.packageName == packageName) {
                            if (screenInteractive && openStart == 0L) openStart = t
                        } else if (openStart > 0L) {
                            // boshqa ilova foreground'ga chiqdi — bizniki yopiladi
                            total += t - openStart
                            openStart = 0L
                        }
                    }
                    UsageEvents.Event.ACTIVITY_PAUSED,
                    UsageEvents.Event.ACTIVITY_STOPPED -> {
                        if (ev.packageName == packageName && openStart > 0L) {
                            total += t - openStart
                            openStart = 0L
                        }
                    }
                    UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                    UsageEvents.Event.KEYGUARD_SHOWN,
                    UsageEvents.Event.DEVICE_SHUTDOWN -> {
                        if (openStart > 0L) {
                            total += t - openStart
                            openStart = 0L
                        }
                        screenInteractive = false
                    }
                    UsageEvents.Event.SCREEN_INTERACTIVE,
                    UsageEvents.Event.KEYGUARD_HIDDEN -> {
                        screenInteractive = true
                    }
                }
            }
            if (screenInteractive && openStart > 0L) total += now - openStart
            total
        } catch (e: Exception) {
            Log.e(TAG, "getTodayUsageMs error", e)
            0L
        }
    }

    /**
     * Oxirgi 5 sek ichida foreground bo'lgan paket nomi. UsageStatsManager
     * MOVE_TO_FOREGROUND event'larini scan qiladi.
     */
    private fun getForegroundPackage(): String? {
        return try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE)
                as UsageStatsManager
            val end = System.currentTimeMillis()
            val begin = end - 5000

            val events = usm.queryEvents(begin, end)
            val event = UsageEvents.Event()
            var lastForeground: String? = null

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                    lastForeground = event.packageName
                }
            }
            lastForeground
        } catch (e: Exception) {
            Log.e(TAG, "getForegroundPackage error", e)
            null
        }
    }

    /**
     * To'liq ekran overlay ko'rsatish. SYSTEM_ALERT_WINDOW permission
     * kerak. Permission yo'q bo'lsa jim chiqadi.
     */
    private fun showOverlay(packageName: String) {
        if (!Settings.canDrawOverlays(this)) {
            Log.w(TAG, "SYSTEM_ALERT_WINDOW permission yo'q")
            return
        }

        if (overlayView != null) {
            hideOverlay()
        }

        val appLabel = try {
            val pm = packageManager
            val info = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(info).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            packageName
        }

        val view = buildOverlayView(appLabel)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.OPAQUE,
        )
        params.gravity = Gravity.CENTER

        try {
            windowManager?.addView(view, params)
            overlayView = view
            Log.d(TAG, "Overlay ko'rsatildi: $packageName ($appLabel)")
        } catch (e: Exception) {
            Log.e(TAG, "Overlay qo'shishda xato", e)
        }
    }

    private fun hideOverlay() {
        val view = overlayView ?: return
        try {
            windowManager?.removeView(view)
        } catch (e: Exception) {
            Log.e(TAG, "Overlay olib tashlashda xato", e)
        }
        overlayView = null
        currentBlockedPackage = null
    }

    /**
     * Overlay UI dasturiy quriladi (XML resource shart emas).
     * Qora fon, markazda lock icon + matn + "Yopish" tugma.
     */
    private fun buildOverlayView(appLabel: String): View {
        val ctx = this
        val container = FrameLayout(ctx).apply {
            setBackgroundColor(Color.parseColor("#F00A0A12")) // dark, opaque
        }

        val column = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(32), dp(32), dp(32), dp(32))
        }

        // Lock icon (Unicode emoji o'rniga TypedValue bilan boy icon).
        val icon = TextView(ctx).apply {
            text = "🔒" // 🔒
            setTextColor(Color.parseColor("#C5F562")) // AppColors.primary lime
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 64f)
            gravity = Gravity.CENTER
        }

        val title = TextView(ctx).apply {
            text = "Bu ilova bloklangan"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(0, dp(24), 0, dp(8))
        }

        val subtitle = TextView(ctx).apply {
            text = appLabel
            setTextColor(Color.parseColor("#9999A8")) // AppColors.textSecondary
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            gravity = Gravity.CENTER
        }

        val hint = TextView(ctx).apply {
            text = "Ota-onangiz tomonidan bloklangan"
            setTextColor(Color.parseColor("#6B6B78")) // AppColors.textTertiary
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            gravity = Gravity.CENTER
            setPadding(0, dp(16), 0, dp(32))
        }

        val closeButton = Button(ctx).apply {
            text = "Yopish"
            setTextColor(Color.BLACK)
            setBackgroundColor(Color.parseColor("#C5F562")) // primary lime
            setPadding(dp(48), dp(12), dp(48), dp(12))
            // Pill shape:
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(28).toFloat()
                setColor(Color.parseColor("#C5F562"))
            }
            background = bg
            setOnClickListener {
                // HOME ekrani Intent — bola bloklangan ilovadan chiqib ketadi.
                val home = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                ctx.startActivity(home)
                hideOverlay()
            }
        }

        column.addView(icon)
        column.addView(title)
        column.addView(subtitle)
        column.addView(hint)
        column.addView(closeButton)

        val params = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
        ).apply { gravity = Gravity.CENTER }
        container.addView(column, params)

        return container
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Farzandim cheklov xizmati",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Ilova cheklovlarini kuzatish"
                setShowBadge(false)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Farzandim faol")
            .setContentText("Ilova cheklovlari kuzatilmoqda")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
