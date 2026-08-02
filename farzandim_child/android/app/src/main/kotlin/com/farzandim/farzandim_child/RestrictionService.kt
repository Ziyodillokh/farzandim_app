package com.farzandim.farzandim_child

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.content.res.Configuration
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
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import java.util.Calendar

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

        // Watchdog — servis OEM batareya-menejeri (Xiaomi/Huawei/Oppo/Vivo/
        // Samsung) tomonidan fonda o'ldirilsa, START_STICKY ko'pincha yordam
        // bermaydi → bloklash "jimgina" to'xtaydi (bola app'ni qayta ochmaguncha).
        // Bu alarm zanjiri har ~60s da BootReceiver'ga broadcast yuboradi va
        // servisni qayta ishga tushiradi (o'lgan bo'lsa) hamda keyingi alarmni
        // qayta rejalashtiradi. Shu bilan enforcement fonda ham tirik qoladi.
        const val ACTION_WATCHDOG = "com.farzandim.action.WATCHDOG_RESTART"
        private const val WATCHDOG_REQ = 4243
        private const val WATCHDOG_INTERVAL_MS = 60_000L

        // Overlay sababi — matn/ikona shunga qarab tanlanadi (#12).
        // BLOCKED = to'liq blok (ota-ona/kategoriya/jadval). LIMIT = kunlik
        // vaqt tugadi.
        private const val REASON_BLOCKED = "blocked"
        private const val REASON_LIMIT = "limit"

        // Limitga shu vaqt qolganda bolaga "vaqting tugayapti" ogohlantirish
        // (kuniga bir marta/ilova) — bola qo'shimcha vaqt so'rashga ulgursin.
        private const val PRE_WARNING_MS = 10 * 60 * 1000L
        private const val WARN_CHANNEL_ID = "farzandim_limit_warning"
        private const val WARN_NOTIFICATION_BASE = 5200
        // SharedPreferences: "<prefix><paket>.<limit>.<sana>" → ogohlantirildi.
        // Limit grant bilan oshsa kalit o'zgaradi → yangi ogohlantirish mumkin.
        private const val PREFS_KEY_WARNED_PREFIX =
            "flutter.restriction.limit_warned."

        // SharedPreferences key — Dart RestrictionsSyncService yozadi.
        // Schema: "com.app1,com.app2,..." (comma-separated)
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PREFS_KEY_BLOCKED = "flutter.restriction.blocked_packages"
        private const val PREFS_KEY_LIMITS = "flutter.restriction.limits"

        // O'yin (CATEGORY_GAME) foreground'ga chiqqanda shu prefs queue'ga
        // JSON string sifatida yoziladi. Dart bg isolate (~60s) o'qib, tozalab,
        // backend'ga POST qiladi → ota-onaga "o'ynayapti" push. (MethodChannel
        // bg isolate'da ishlamaydi, shuning uchun aniqlash NATIVE shu yerda.)
        private const val PREFS_KEY_GAME_PENDING = "flutter.game.pending"
        // Bir o'yin shu muddat ichida queue'ga faqat bir marta (takror push yo'q).
        private const val GAME_DEDUP_MS = 5 * 60 * 1000L

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

        /**
         * Watchdog alarmni (qayta) o'rnatadi — ~60s dan keyin BootReceiver
         * `ACTION_WATCHDOG` broadcast oladi, servisni tekshirib/qayta ishga
         * tushiradi va keyingi alarmni rejalashtiradi (o'z-o'zini davolovchi
         * zanjir). `setAndAllowWhileIdle` — Doze'da ham ishlaydi, maxsus
         * SCHEDULE_EXACT_ALARM ruxsati kerak emas. Fondan foreground-service
         * boshlash bu ilovada SYSTEM_ALERT_WINDOW (overlay) ruxsati tufayli
         * mumkin (A12+ background-FGS cheklovidan istisno).
         */
        fun scheduleWatchdog(ctx: Context) {
            try {
                val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val at = System.currentTimeMillis() + WATCHDOG_INTERVAL_MS
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, watchdogPi(ctx))
                } else {
                    am.set(AlarmManager.RTC_WAKEUP, at, watchdogPi(ctx))
                }
            } catch (e: Exception) {
                Log.e(TAG, "scheduleWatchdog error", e)
            }
        }

        /** Watchdog alarmni bekor qiladi (servis ATAYIN to'xtatilganda). */
        fun cancelWatchdog(ctx: Context) {
            try {
                (ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
                    .cancel(watchdogPi(ctx))
            } catch (e: Exception) {
                Log.e(TAG, "cancelWatchdog error", e)
            }
        }

        private fun watchdogPi(ctx: Context): PendingIntent {
            val i = Intent(ctx, BootReceiver::class.java).apply {
                action = ACTION_WATCHDOG
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            return PendingIntent.getBroadcast(ctx, WATCHDOG_REQ, i, flags)
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var isRunning = false

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var currentBlockedPackage: String? = null

    /** Overlay qaysi sabab bilan qurilgan — aylanganda qayta qurish uchun. */
    private var currentReason: String? = null

    /**
     * Overlay qurilgan paytdagi ekran orientatsiyasi.
     *
     * Layout portret/landshaftda TURLICHA (landshaftda rasm chapda, matn
     * o'ngda) va u dasturiy quriladi — ya'ni telefon aylanganda o'zi
     * moslashmaydi. `ensureOverlay` har poll'da (1s) shu qiymatni solishtirib,
     * o'zgargan bo'lsa overlay'ni qayta quradi.
     */
    private var currentOrientation: Int = Configuration.ORIENTATION_UNDEFINED

    // Install-source kesh (paket → noma'lum manbami). O'rnatish manbasi
    // o'zgarmaydi, shuning uchun bir marta hisoblab keshlaymiz (har 3s
    // PackageManager chaqirmaslik uchun).
    private val unknownSourceCache = HashMap<String, Boolean>()

    // O'yin aniqlash keshlari: paket → o'yinmi; paket → oxirgi queue vaqti;
    // oxirgi foreground paket (edge-trigger — faqat YANGI ochilganda queue).
    // gameCache — 2 oqimdan o'qiladi/yoziladi (poll + background executor) →
    // ConcurrentHashMap.
    private val gameCache = java.util.concurrent.ConcurrentHashMap<String, Boolean>()
    // Hozir background'da hisoblanayotgan paketlar (takror ish yo'q).
    private val gameComputing =
        java.util.Collections.synchronizedSet(HashSet<String>())
    // O'yin aniqlash (APK ZIP skani — OG'IR) uchun alohida oqim: poll
    // (main looper) bloklanmasin.
    private val gameExecutor =
        java.util.concurrent.Executors.newSingleThreadExecutor()
    private val lastGameQueued = HashMap<String, Long>()
    private var lastForegroundForGame: String? = null

    // getForegroundPackage() "sticky" qiymati — uzoq turgan o'yin/ilovada
    // queryEvents oynasida yangi ACTIVITY_RESUMED bo'lmasa, oxirgi ma'lum
    // foreground'ni qaytaramiz (null o'rniga). Aks holda o'yin aniqlash oynasi
    // juda tor bo'lib qoladi va uzoq o'ynalgan o'yin queue'ga tushmaydi.
    private var lastForegroundSticky: String? = null

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
        // START_STICKY qayta ishga tushganda OS NULL intent yuboradi. Avval
        // bunda hech qaysi branch ishlamay startForeground() chaqirilmasdi →
        // Android 12+/14 da ForegroundServiceDidNotStartInTimeException crash.
        // Endi null/noma'lum action → startMonitoring (idempotent: isRunning guard).
        when (intent?.action) {
            ACTION_STOP -> stopMonitoring()
            else -> startMonitoring()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * App recents'dan surib tashlanganda ba'zi OEM'lar started/foreground
     * servisni ham o'ldiradi. Agar monitoring faol bo'lsa — watchdog alarm
     * bilan tez qayta tiklanishini kafolatlaymiz (bloklash uzilib qolmasin).
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        if (isRunning) scheduleWatchdog(this)
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
        // MUHIM: tizim/OEM FGS'ni o'ldirganda ham onDestroy chaqiriladi —
        // bunda watchdog'ni O'CHIRMAYMIZ (explicit=false), aks holda o'z-o'zini
        // tiklovchi zanjir uzilib, bloklash butunlay to'xtardi. Watchdog faqat
        // ATAYIN to'xtatishda (ACTION_STOP) o'chadi.
        stopMonitoring(explicit = false)
        gameExecutor.shutdownNow()
    }

    private fun startMonitoring() {
        Log.d(TAG, "Monitoring started")

        // startForeground()'ni HAR startForegroundService chaqiruvida bajaramiz
        // (idempotent — bir xil NOTIFICATION_ID qayta post qilinsa notification
        // shunchaki yangilanadi). Avval `if (isRunning) return` startForeground'DAN
        // OLDIN edi: servis (BootReceiver / UsageStatsPlugin / pairing re-entry)
        // qayta ishga tushganda 2-startForegroundService isRunning=true'da
        // early-return qilib, o'z 5s muddatida startForeground'siz qolib, A12+
        // ForegroundServiceDidNotStartInTimeException crash qilardi.
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

        // Watchdog zanjirini HAR startda qayta yoqamiz (idempotent — bitta
        // alarm yangilanadi). Servis o'lsa ~60s ichida tiklanadi.
        scheduleWatchdog(this)

        // Poll-loop esa FAQAT bir marta ishga tushadi (2 marta ishlamasin).
        if (isRunning) return
        isRunning = true
        handler.post(pollRunnable)
    }

    /**
     * Overlay/notification matnini prefs'dan o'qiydi (Dart main-isolate tarjima
     * yozadi: `flutter.restriction.i18n.<key>`). Yo'q bo'lsa Uzbek fallback —
     * regressiya yo'q (prefs yozilmasa hozirgi xulq saqlanadi).
     */
    private fun i18n(key: String, fallback: String): String {
        return try {
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString("flutter.restriction.i18n.$key", null) ?: fallback
        } catch (e: Exception) {
            fallback
        }
    }

    private fun stopMonitoring(explicit: Boolean = true) {
        Log.d(TAG, "Monitoring stopped (explicit=$explicit)")
        isRunning = false
        handler.removeCallbacks(pollRunnable)
        // Watchdog FAQAT atayin to'xtatishda (ACTION_STOP / unpair) o'chadi.
        // Tizim FGS'ni o'ldirib onDestroy chaqirsa (explicit=false) — watchdog
        // QOLADI va servisni ~60s ichida qayta tiklaydi.
        if (explicit) cancelWatchdog(this)
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
        // O'YIN aniqlash — cheklovlardan QAT'IY NAZAR har poll'da ishlaydi
        // (foreground o'yin bo'lsa prefs queue'ga qo'shiladi). Cheklov yo'q
        // bo'lsa ham ishlashi shart — shuning uchun early-return'dan OLDINDA.
        val foreground = getForegroundPackage()
        if (foreground != null && foreground != packageName) {
            detectAndQueueGame(foreground)
        }

        val blocked = readBlockedPackages()
        val limits = readLimits() // Map<String, Int> minutes
        val blockUnknown = readBlockUnknown()

        if (blocked.isEmpty() && limits.isEmpty() && !blockUnknown) {
            hideOverlay()
            return
        }

        if (foreground == null) return

        // O'zining app'ini block qilmaslik (overlay loop'dan saqlash).
        if (foreground == packageName) {
            hideOverlay()
            return
        }

        // 1. Hard block check (prioritet — har holatda overlay)
        //    "*" wildcard — Schedule whole-window BLOCK (Sprint 4.4.25).
        //    Har qanday foreground'ga overlay.
        if (foreground in blocked || "*" in blocked) {
            ensureOverlay(foreground)
            return
        }

        // 2. Time-based limit check
        val limitMinutes = limits[foreground]
        if (limitMinutes != null && limitMinutes > 0) {
            val usageMs = getTodayUsageMs(foreground)
            val limitMs = limitMinutes * 60L * 1000L
            if (usageMs >= limitMs) {
                if (currentBlockedPackage != foreground || overlayView == null) {
                    Log.d(
                        TAG,
                        "Limit oshdi: $foreground ${usageMs / 60000} min " +
                            ">= $limitMinutes min",
                    )
                }
                ensureOverlay(foreground, REASON_LIMIT)
                return
            }
            // Limitga PRE_WARNING_MS (10 daqiqa) yoki kamroq qoldi — bir marta
            // ogohlantiramiz (bola qo'shimcha vaqt so'rashga ulgursin). Bosilsa
            // unlock modal ochiladi (MainActivity unlock_request_package extra).
            if (limitMs - usageMs <= PRE_WARNING_MS) {
                maybeShowLimitWarning(foreground, limitMinutes)
            }
        }

        // 2b. "Notanish manbalardan ilovalar" — Play/rasmiy do'kondan
        //     bo'lmagan (sideload APK) ilova bo'lsa bloklash.
        if (blockUnknown && isUnknownSource(foreground)) {
            if (currentBlockedPackage != foreground || overlayView == null) {
                Log.d(TAG, "Notanish manba bloklandi: $foreground")
            }
            ensureOverlay(foreground)
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

    // ───────────────────────── O'YIN ANIQLASH ─────────────────────────

    /**
     * Ilova O'YIN'mi — 3 signal (birortasi yetarli):
     *   1. CATEGORY_GAME (O+) — manifest `android:appCategory="game"`.
     *   2. FLAG_IS_GAME — eski `android:isGame` atributi.
     *   3. O'yin engine native lib'lari — KO'P o'yinlar (ayniqsa klon/
     *      kichik studiya, masalan "Counter Strike 2" mobil klonlari)
     *      manifest'da kategoriya QO'YMAYDI → 1-2 signal o'tkazib yuboradi.
     *      Deyarli barcha mobil o'yinlar Unity/Unreal/Cocos/Godot/libGDX
     *      engine'ida — lib papkasida izi qoladi.
     */
    private fun isGame(ai: ApplicationInfo): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            ai.category == ApplicationInfo.CATEGORY_GAME
        ) {
            return true
        }
        @Suppress("DEPRECATION")
        if ((ai.flags and ApplicationInfo.FLAG_IS_GAME) != 0) return true
        return hasGameEngineLibs(ai)
    }

    /** Fayl nomi o'yin engine native kutubxonasimi. */
    private fun isEngineLibName(name: String): Boolean =
        name == "libunity.so" ||         // Unity (mono/IL2CPP'da ham bor)
            name == "libil2cpp.so" ||    // Unity IL2CPP
            name.startsWith("libUE") ||  // Unreal UE4 (libUE4.so)
            name == "libUnreal.so" ||    // Unreal UE5
            name.startsWith("libcocos") || // Cocos2d-x / Creator
            name.startsWith("libgodot") || // Godot
            name == "libgdx.so"            // libGDX

    /**
     * O'yin engine native kutubxonalari bormi (Unity/UE/Cocos/Godot/libGDX).
     *
     * 2 yo'l: (1) extractNativeLibs=true (eski/sideload APK) — .so'lar diskda
     * `nativeLibraryDir`da. (2) extractNativeLibs=false (Play/AAB DEFAULT,
     * 2021'dan beri yangi Play ilovalari) — .so'lar APK ichida (ko'pincha
     * split_config.<abi>.apk'da), `nativeLibraryDir` BO'SH. Shu sababli APK
     * zip entry'larini ham skan qilamiz — aks holda Play'dan o'rnatilgan
     * Unity "CS2 klon" kabi o'yinlar aniqlanmasdi. ZipFile faqat markaziy
     * katalogni o'qiydi (arzon); natija gameCache bilan paketga bir marta.
     */
    private fun hasGameEngineLibs(ai: ApplicationInfo): Boolean {
        // 1) Tez yo'l — diskka chiqarilgan .so'lar.
        try {
            val dir = ai.nativeLibraryDir
            if (dir != null) {
                val libs = java.io.File(dir).list()
                if (libs != null && libs.any(::isEngineLibName)) return true
            }
        } catch (_: Exception) {
            // APK skaniga o'tamiz
        }
        // 2) Fallback — APK(lar) ichidagi lib/<abi>/*.so entry'lari.
        val apks = ArrayList<String>()
        ai.sourceDir?.let { apks.add(it) }
        ai.splitSourceDirs?.let { apks.addAll(it) }
        for (path in apks) {
            try {
                java.util.zip.ZipFile(path).use { zip ->
                    val entries = zip.entries()
                    while (entries.hasMoreElements()) {
                        val name = entries.nextElement().name
                        if (name.startsWith("lib/") &&
                            isEngineLibName(name.substringAfterLast('/'))
                        ) {
                            return true
                        }
                    }
                }
            } catch (_: Exception) {
                // bu APK'ni tashlab keyingisiga o'tamiz
            }
        }
        return false
    }

    /**
     * Paket o'yinmi — KESHDAN sinxron. Hali hisoblanmagan bo'lsa, og'ir
     * aniqlashni (APK ZIP skani, `hasGameEngineLibs`) BACKGROUND oqimga
     * yuboradi va hozircha `false` qaytaradi (keyingi poll'da kesh to'ladi).
     *
     * MUHIM (ANR tuzatildi): avval bu birinchi chaqiruvda ZIP skanini POLL
     * (main looper) oqimida bajarardi — katta o'yin (split APK, 100MB+)
     * ochilganda yuzlab ms–sekund main thread'ni bloklab "javob bermayapti"
     * chiqarardi.
     */
    private fun isGamePkg(pkg: String): Boolean {
        gameCache[pkg]?.let { return it }
        if (gameComputing.add(pkg)) {
            gameExecutor.execute {
                val res = try {
                    isGame(packageManager.getApplicationInfo(pkg, 0))
                } catch (e: Exception) {
                    false
                }
                gameCache[pkg] = res
                gameComputing.remove(pkg)
            }
        }
        return false
    }

    /**
     * Foreground paket o'yin bo'lsa, u YANGI ochilgan bo'lsa (edge-trigger) va
     * dedup oynasidan tashqarida bo'lsa — prefs queue'ga qo'shadi. Bola o'yinda
     * uzoq tursa ham (har poll'da bir xil foreground) faqat bir marta qo'shiladi.
     */
    private fun detectAndQueueGame(foreground: String) {
        if (foreground == packageName) return
        if (!isGamePkg(foreground)) {
            // Diagnostika: yangi ochilgan ilova o'yin deb TOPILMADI — logcat'da
            // ko'rinadi (qaysi o'yin signal bermayotganini aniqlash uchun).
            if (lastForegroundForGame != foreground) {
                Log.d(TAG, "not-game: $foreground")
            }
            lastForegroundForGame = foreground
            return
        }
        val now = System.currentTimeMillis()
        val isNewForeground = lastForegroundForGame != foreground
        lastForegroundForGame = foreground
        val last = lastGameQueued[foreground] ?: 0L
        // Faqat yangi ochilganda VA dedup oynasidan tashqarida.
        if (!isNewForeground) return
        if (now - last < GAME_DEDUP_MS) return
        lastGameQueued[foreground] = now
        appendGameToQueue(foreground, now)
    }

    /** O'yinni prefs JSON queue'ga qo'shadi (Dart bg isolate o'qiydi). */
    private fun appendGameToQueue(pkg: String, ts: Long) {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val raw = prefs.getString(PREFS_KEY_GAME_PENDING, null)
            val arr = if (raw.isNullOrBlank()) {
                org.json.JSONArray()
            } else {
                org.json.JSONArray(raw)
            }
            // Bir xil paketning eski (dedup oynasidagi) yozuvini olib tashlaymiz.
            val out = org.json.JSONArray()
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                if (o.optString("pkg") == pkg &&
                    ts - o.optLong("ts") < GAME_DEDUP_MS
                ) {
                    continue
                }
                out.put(o)
            }
            val name = try {
                packageManager
                    .getApplicationLabel(packageManager.getApplicationInfo(pkg, 0))
                    .toString()
            } catch (e: Exception) {
                pkg
            }
            out.put(
                org.json.JSONObject()
                    .put("pkg", pkg)
                    .put("name", name)
                    .put("ts", ts),
            )
            // Cheksiz o'smaslik uchun oxirgi 50 ta.
            val capped = if (out.length() > 50) {
                org.json.JSONArray().also {
                    for (i in out.length() - 50 until out.length()) it.put(out.get(i))
                }
            } else {
                out
            }
            prefs.edit().putString(PREFS_KEY_GAME_PENDING, capped.toString()).apply()
            Log.d(TAG, "Game queued: $pkg ($name)")
        } catch (e: Exception) {
            Log.e(TAG, "appendGameToQueue error", e)
        }
    }

    /**
     * Hozirgi foreground paket nomi. UsageStatsManager ACTIVITY_RESUMED
     * event'larini scan qiladi.
     *
     * MUHIM: queryEvents FAQAT oyna ICHIDAGI event'larni qaytaradi (holat
     * emas — hodisa). O'yin/ilova ochilib uzoq tursa, yangi RESUMED chiqmaydi
     * → tor oyna (avval 5s) ~5s'dan keyin null qaytarardi va uzoq o'ynalgan
     * o'yin aniqlanmasdi. Yechim: (1) oynani 60s ga kengaytirdik, (2) RESUMED
     * topilmasa oxirgi ma'lum foreground'ni ("sticky") qaytaramiz. Edge-trigger
     * buzilmaydi — sticky ham bir xil paket, isNewForeground=false bo'ladi.
     */
    private fun getForegroundPackage(): String? {
        return try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE)
                as UsageStatsManager
            val end = System.currentTimeMillis()
            val begin = end - 60_000L

            val events = usm.queryEvents(begin, end)
            val event = UsageEvents.Event()
            var lastForeground: String? = null

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                    lastForeground = event.packageName
                }
            }

            if (lastForeground != null) {
                lastForegroundSticky = lastForeground
                lastForeground
            } else {
                // 60s ichida ham RESUMED yo'q (juda uzoq turgan o'yin / OEM
                // usage throttling): oxirgi ma'lum foreground'ni qaytaramiz.
                lastForegroundSticky
            }
        } catch (e: Exception) {
            Log.e(TAG, "getForegroundPackage error", e)
            null
        }
    }

    /**
     * Overlay bloklangan ilova ustida TURISHINI kafolatlaydi (maksimal
     * to'siq). Ilova hali o'sha bo'lsa-yu overlay tushib qolgan bo'lsa
     * (`overlayView == null` — sistema olib tashlagan) qayta ko'rsatadi.
     * Har poll'da (1s) chaqiriladi — shuning uchun bloklangan ilovadan
     * qutulib bo'lmaydi.
     */
    private fun ensureOverlay(pkg: String, reason: String = REASON_BLOCKED) {
        // Orientatsiya o'zgargan bo'lsa ham qayta quramiz: layout portret va
        // landshaftda TURLICHA (dasturiy qurilgani uchun o'zi moslashmaydi).
        // Aks holda telefon yonbosh burilganda vertikal layout siqilib, matn
        // ekranga sig'may kesilib qolardi.
        val orientation = resources.configuration.orientation
        if (currentBlockedPackage != pkg ||
            overlayView == null ||
            currentOrientation != orientation ||
            currentReason != reason
        ) {
            showOverlay(pkg, reason)
            currentBlockedPackage = pkg
            currentReason = reason
            currentOrientation = orientation
        }
    }

    /**
     * To'liq ekran overlay ko'rsatish. SYSTEM_ALERT_WINDOW permission
     * kerak. Permission yo'q bo'lsa jim chiqadi.
     */
    private fun showOverlay(packageName: String, reason: String = REASON_BLOCKED) {
        if (!Settings.canDrawOverlays(this)) {
            Log.w(TAG, "SYSTEM_ALERT_WINDOW permission yo'q")
            return
        }

        if (overlayView != null) {
            hideOverlay()
        }

        val view = buildOverlayView(packageName, reason)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                // Bloklangan ilova qulflangan ekran USTIDA ochilsa (masalan
                // showWhenLocked bilan chiquvchi qo'ng'iroq/o'yin ekrani)
                // overlay'ni tizim YASHIRARDI: AOSP DisplayPolicy
                // shouldBeHiddenByKeyguard() activity bo'lmagan oynani
                // keyguard paytida yashiradi, agar canShowWhenLocked() rost
                // bo'lmasa — activity bo'lmagan oyna uchun bu aynan shu
                // bayroq. Endi bloklangan ilova keyguard'ni "occlude" qilsa
                // ham overlay ustida qoladi. Oddiy (occlude qilinmagan) qulf
                // ekranida overlay baribir ko'rinmaydi — bu KERAKLI xulq.
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED,
            PixelFormat.OPAQUE,
        )
        params.gravity = Gravity.CENTER

        try {
            windowManager?.addView(view, params)
            overlayView = view
            Log.d(TAG, "Overlay ko'rsatildi: $packageName (reason=$reason)")
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
        currentReason = null
        currentOrientation = Configuration.ORIENTATION_UNDEFINED
    }

    /**
     * Overlay UI dasturiy quriladi (XML resource shart emas) — professional
     * "Ilova bloklangan" sahifasi. Telefon TEMASIga qarab (tungi/kunduzgi)
     * to'liq OQ yoki QORA fonda, mos "bolakay" rasmi bilan. Tugmalar ota-ona
     * onboardingidagi primary (ko'k "OK") + secondary ("Ruxsat so'rash").
     * Fon TO'LIQ OPAQUE — bloklangan ilova umuman ko'rinmaydi.
     *
     * LAYOUT ORIENTATSIYAGA QARAB:
     *   - Portret   — ustma-ust: rasm, sarlavha, matn, tugmalar.
     *   - Landshaft — yonma-yon: rasm CHAPDA, matn+tugmalar O'NGDA.
     *
     * Avval landshaftda ham vertikal layout ishlatilardi: balandlik ~360dp,
     * kontent esa ~450dp talab qilardi (padding 96 + rasm 190 + sarlavha 68 +
     * matn 40 + tugma 56) → matn va tugmalar ekranga sig'may kesilardi.
     */
    private fun buildOverlayView(
        blockedPackage: String,
        reason: String,
    ): View {
        val isLimit = reason == REASON_LIMIT
        val ctx = this

        // Telefon tungi rejimda ekanmi? (kunduzgi = oq, tungi = qora).
        val isNight = (resources.configuration.uiMode and
            Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

        // Yonbosh (landshaft) — balandlik kam, kenglik ko'p.
        val isLandscape = resources.configuration.orientation ==
            Configuration.ORIENTATION_LANDSCAPE

        // ── Tema ranglari ─────────────────────────────────────────────
        val pageBg = if (isNight) Color.parseColor("#0B0D12") else Color.WHITE
        val titleColor =
            if (isNight) Color.WHITE else Color.parseColor("#0F1720")
        val subColor =
            if (isNight) Color.parseColor("#98A2B3") else Color.parseColor("#667085")
        val primaryBlue = Color.parseColor("#216BFF")
        val secondaryBg =
            if (isNight) Color.parseColor("#232936") else Color.parseColor("#EEF0F3")
        val secondaryText =
            if (isNight) Color.parseColor("#E6EAF2") else Color.parseColor("#3A4150")
        val imgName = if (isNight) "bolakay_dark" else "bolakay_light"

        // Root — butun ekranni to'ldiruvchi OPAQUE fon (maksimal to'siq).
        val root = FrameLayout(ctx).apply { setBackgroundColor(pageBg) }

        // ── Bo'laklar — pastda orientatsiyaga qarab yig'iladi ─────────

        // "Bolakay" rasmi (qo'l ko'targan bola) — temaga mos.
        val image = ImageView(ctx).apply {
            val id = resources.getIdentifier(imgName, "drawable", packageName)
            if (id != 0) setImageResource(id)
            scaleType = ImageView.ScaleType.FIT_CENTER
            adjustViewBounds = true
        }

        // Landshaftda matn CHAPGA tekislanadi (rasm yonida ustun bo'lgani
        // uchun markaz g'alati ko'rinadi), portretda MARKAZDA.
        val textGravity = if (isLandscape) Gravity.START else Gravity.CENTER

        val title = TextView(ctx).apply {
            text = if (isLimit) {
                i18n("limitReached", "Bugungi vaqt tugadi")
            } else {
                i18n("blocked", "Ilova bloklangan")
            }
            setTextColor(titleColor)
            // Landshaftda balandlik kam — sarlavha biroz kichikroq.
            setTextSize(TypedValue.COMPLEX_UNIT_SP, if (isLandscape) 22f else 26f)
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            gravity = textGravity
            setPadding(0, if (isLandscape) 0 else dp(24), 0, dp(10))
        }

        val subtitle = TextView(ctx).apply {
            text = if (isLimit) {
                i18n(
                    "limitSub",
                    "Bu ilova uchun bugungi vaqting tugadi.\n" +
                        "Ko'proq vaqt uchun ota-onangdan so'ra.",
                )
            } else {
                i18n(
                    "blockedSub",
                    "Bu ilovadan foydalanish hozircha cheklangan.\n" +
                        "Ruxsat olish uchun ota-onangizga murojaat qiling.",
                )
            }
            setTextColor(subColor)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            gravity = textGravity
            setLineSpacing(dp(4).toFloat(), 1f)
        }

        // ── Tugmalar qatori: [OK ko'k] [Ruxsat so'rash kulrang] ──────
        val okButton = makeOverlayButton(
            label = i18n("ok", "OK"),
            bgColor = primaryBlue,
            textColor = Color.WHITE,
        ) {
            // HOME — bola bloklangan ilovadan chiqib ketadi (auto-exit).
            val home = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            ctx.startActivity(home)
            hideOverlay()
        }
        val requestButton = makeOverlayButton(
            label = i18n("requestAccess", "Ruxsat so'rash"),
            bgColor = secondaryBg,
            textColor = secondaryText,
        ) {
            try {
                val open = Intent(ctx, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("unlock_request_package", blockedPackage)
                }
                ctx.startActivity(open)
            } catch (e: Exception) {
                Log.e(TAG, "Ruxsat so'rash: Parvoz'ni ochishda xato", e)
            }
            hideOverlay()
        }

        val buttonRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        buttonRow.addView(
            okButton,
            LinearLayout.LayoutParams(0, dp(56), 1f),
        )
        buttonRow.addView(
            requestButton,
            LinearLayout.LayoutParams(0, dp(56), 1f).apply {
                marginStart = dp(12)
            },
        )

        // ── Yig'ish ──────────────────────────────────────────────────
        val content: View = if (isLandscape) {
            buildLandscapeContent(image, title, subtitle, buttonRow)
        } else {
            buildPortraitContent(image, title, subtitle, buttonRow)
        }

        root.addView(
            content,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        return root
    }

    /** Portret: ustma-ust — rasm, sarlavha, matn, (bo'sh joy), tugmalar. */
    private fun buildPortraitContent(
        image: ImageView,
        title: TextView,
        subtitle: TextView,
        buttonRow: LinearLayout,
    ): View {
        val ctx = this
        val col = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            // Yuqorida status bar, pastda navigatsiya paneli uchun joy.
            setPadding(dp(28), dp(56), dp(28), dp(40))
        }

        // Yuqori bo'sh joy — mazmunni biroz pastga suradi (markazroq).
        col.addView(View(ctx), LinearLayout.LayoutParams(0, 0, 1.1f))

        col.addView(
            image,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                dp(190),
            ),
        )
        col.addView(title)
        col.addView(
            subtitle,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        // Pastki bo'sh joy — tugmalarni ekran pastiga suradi.
        col.addView(View(ctx), LinearLayout.LayoutParams(0, 0, 1.5f))

        col.addView(
            buttonRow,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )
        return col
    }

    /**
     * Landshaft: yonma-yon — rasm CHAPDA, matn+tugmalar O'NGDA.
     *
     * Yonbosh holatda balandlik kam (~360dp), shuning uchun vertikal layout
     * sig'masdi. Rasm balandlikni to'ldiradi (MATCH_PARENT + FIT_CENTER —
     * nisbati saqlanadi), matn ustuni esa qolgan kenglikda markazlashadi.
     */
    private fun buildLandscapeContent(
        image: ImageView,
        title: TextView,
        subtitle: TextView,
        buttonRow: LinearLayout,
    ): View {
        val ctx = this
        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(32), dp(20), dp(32), dp(20))
        }

        row.addView(
            image,
            LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.MATCH_PARENT,
                1f,
            ),
        )

        val textCol = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
        }
        textCol.addView(
            title,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )
        textCol.addView(
            subtitle,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )
        textCol.addView(
            buttonRow,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(20) },
        )

        row.addView(
            textCol,
            LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1.15f,
            ).apply { marginStart = dp(28) },
        )
        return row
    }

    /** Onboarding uslubidagi tekis, dumaloq-burchak tugma (soyasiz). */
    private fun makeOverlayButton(
        label: String,
        bgColor: Int,
        textColor: Int,
        onClick: () -> Unit,
    ): Button {
        return Button(this).apply {
            text = label
            setTextColor(textColor)
            isAllCaps = false
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            minWidth = 0
            minimumWidth = 0
            minHeight = 0
            minimumHeight = 0
            setPadding(dp(10), 0, dp(10), 0)
            // Android tugmasidagi standart ko'tarilish (elevation) soyasini
            // olib tashlaymiz — tekis, zamonaviy ko'rinish.
            stateListAnimator = null
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(16).toFloat()
                setColor(bgColor)
            }
            setOnClickListener { onClick() }
        }
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Parvoz cheklov xizmati",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Ilova cheklovlarini kuzatish"
                setShowBadge(false)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)

            // Limit ogohlantirish kanali — HIGH (heads-up + ovoz), bola
            // "vaqting tugayapti" xabarini sezsin.
            val warnChannel = NotificationChannel(
                WARN_CHANNEL_ID,
                "Vaqt tugashi ogohlantirishi",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Ilova vaqti tugashidan oldin ogohlantirish"
                setShowBadge(true)
            }
            manager?.createNotificationChannel(warnChannel)
        }
    }

    /**
     * Limitga ~10 daqiqa qolganda bir marta (paket+limit+sana bo'yicha)
     * ogohlantirish notification ko'rsatadi. Limit grant bilan oshsa kalit
     * o'zgaradi → yangi limitga yaqinlashganda yana ogohlantirish mumkin.
     */
    private fun maybeShowLimitWarning(packageName: String, limitMinutes: Int) {
        val prefs: SharedPreferences =
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val cal = Calendar.getInstance()
        val dayKey = "${cal.get(Calendar.YEAR)}-${cal.get(Calendar.DAY_OF_YEAR)}"
        val key = "$PREFS_KEY_WARNED_PREFIX$packageName.$limitMinutes.$dayKey"
        if (prefs.getBoolean(key, false)) return
        prefs.edit().putBoolean(key, true).apply()
        showLimitWarningNotification(packageName)
    }

    /** "Vaqting tugayapti" notification — bosilsa unlock modal ochiladi. */
    private fun showLimitWarningNotification(packageName: String) {
        val label = appLabelFor(packageName)
        // Bosilganda MainActivity ochilib, unlock so'rov modalini ko'rsatadi
        // (overlay "Ruxsat so'rash" tugmasi bilan bir xil extra).
        val tapIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("unlock_request_package", packageName)
        }
        val piFlags =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        val pi = PendingIntent.getActivity(
            this,
            packageName.hashCode(),
            tapIntent,
            piFlags,
        )
        val text = i18n(
            "timeRunningOutBody",
            "{label} uchun bugungi vaqtingga ~10 daqiqa qoldi. " +
                "Ko'proq vaqt uchun bosib ota-onangdan so'ra.",
        ).replace("{label}", label)
        val notif = NotificationCompat.Builder(this, WARN_CHANNEL_ID)
            .setContentTitle(i18n("timeRunningOut", "Vaqting tugayapti"))
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pi)
            .build()
        val manager = getSystemService(NotificationManager::class.java)
        manager?.notify(
            WARN_NOTIFICATION_BASE + (packageName.hashCode() and 0xFFF),
            notif,
        )
    }

    /** Paket uchun foydalanuvchiga ko'rinadigan ilova nomi (yo'q bo'lsa paket). */
    private fun appLabelFor(packageName: String): String {
        return try {
            val pm = packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0))
                .toString()
        } catch (e: Exception) {
            packageName
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Parvoz faol")
            .setContentText("Ilova cheklovlari kuzatilmoqda")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
