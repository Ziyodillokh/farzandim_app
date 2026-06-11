package com.farzandim.farzandim_child

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Base64
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream

class UsageStatsPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "farzandim/usage_stats")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasUsageStatsPermission())
            "openSettings" -> {
                openUsageAccessSettings()
                result.success(null)
            }
            "getUsageStats" -> {
                val days = call.argument<Int>("days") ?: 1
                result.success(getUsageStats(days))
            }
            "getInstalledApps" -> {
                result.success(getInstalledApps())
            }
            "getRecentGameForegrounds" -> {
                val sinceMs = call.argument<Number>("sinceMs")?.toLong() ?: 0L
                result.success(getRecentGameForegrounds(sinceMs))
            }
            "hasOverlayPermission" -> result.success(hasOverlayPermission())
            "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())
            "openOverlaySettings" -> {
                openOverlaySettings()
                result.success(null)
            }
            "startRestrictionService" -> {
                startRestrictionService()
                result.success(null)
            }
            "stopRestrictionService" -> {
                stopRestrictionService()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    /**
     * RestrictionService (Accessibility Service) yoqilganmi — ota-onaga
     * "Accessibility holati"ni ko'rsatish uchun (Block 4 / M12). Tizimning
     * yoqilgan accessibility xizmatlari ro'yxatida bizning servismiz bormi.
     */
    private fun isAccessibilityEnabled(): Boolean {
        return try {
            val expected = "${context.packageName}/${RestrictionService::class.java.name}"
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            enabled.split(':').any { it.equals(expected, ignoreCase = true) }
        } catch (_: Exception) {
            false
        }
    }

    private fun openOverlaySettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${context.packageName}"),
        )
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    private fun startRestrictionService() {
        val intent = Intent(context, RestrictionService::class.java).apply {
            action = RestrictionService.ACTION_START
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    private fun stopRestrictionService() {
        val intent = Intent(context, RestrictionService::class.java).apply {
            action = RestrictionService.ACTION_STOP
        }
        context.startService(intent)
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOpsManager =
            context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOpsManager.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    /// Drawable → 96x96 PNG → base64 (NO_WRAP). Xato bo'lsa null.
    private fun drawableToBase64(drawable: Drawable): String? {
        return try {
            val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
                drawable.bitmap
            } else {
                val w = drawable.intrinsicWidth.coerceAtLeast(1)
                val h = drawable.intrinsicHeight.coerceAtLeast(1)
                val bm = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bm)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
                bm
            }

            val resized = Bitmap.createScaledBitmap(bitmap, 96, 96, true)

            val baos = ByteArrayOutputStream()
            resized.compress(Bitmap.CompressFormat.PNG, 80, baos)
            Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP)
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Bola foydalanish statistikasi — bugungi (kalendar kun 00:00 → hozir)
     * yoki oxirgi N kun.
     *
     * EVENT-BASED — Android "Raqamli Salomatlik" bilan bir xil. Har paketning
     * ACTIVITY_RESUMED → ACTIVITY_PAUSED/STOPPED sessiyalari yig'iladi: ya'ni
     * FAQAT foydalanuvchi ekranni yoqib, ilovani ochib, ekranda ko'rgan vaqt.
     *
     * Nega aggregate (totalTimeInForeground) emas:
     *  - Fon-service ilovalar (Internet Speed Meter, musiqa pleyer, navigator)
     *    hech qachon activity ochmaydi → 0 (hisoblanmaydi). Avval ular ham
     *    "ekran vaqti"ga kirib ketardi.
     *  - Ekran o'chsa, foreground activity PAUSED bo'ladi → sessiya yopiladi,
     *    ekran o'chiq vaqt qo'shilmaydi.
     */
    private fun getUsageStats(days: Int): List<Map<String, Any>> {
        if (!hasUsageStatsPermission()) return emptyList()

        val usageStatsManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        val endTime = System.currentTimeMillis()
        val startTime: Long = if (days <= 1) {
            // Bugun: Toshkent (Asia/Tashkent, UTC+5) kun boshidan (00:00)
            // hozirgacha. Backend va ota-ona ilovasi "bugun"ni Toshkent
            // bo'yicha hisoblaydi — bir xil chegara enforcement (Restriction
            // Service) bilan ham mos kelishi uchun.
            val cal = java.util.Calendar.getInstance(
                java.util.TimeZone.getTimeZone("Asia/Tashkent"),
            ).apply {
                set(java.util.Calendar.HOUR_OF_DAY, 0)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
            }
            cal.timeInMillis
        } else {
            endTime - (days * 24L * 60L * 60L * 1000L)
        }

        val totals = HashMap<String, Long>()
        val lastUsed = HashMap<String, Long>()

        // SINGLE-CURRENT-FOREGROUND state machine. OS foreground'da bir vaqtda
        // FAQAT bitta ilova bo'ladi. Yangi ACTIVITY_RESUMED kelganda oldingi
        // ilovaning sessiyasi o'sha vaqtda yopiladi (parallel hisob yo'q).
        // Ekran o'chsa/qulflansa sessiya yopiladi va ekran o'chiq vaqt
        // hisoblanmaydi. Bu — orphan RESUMED (PAUSED kelmagan) butun kunni
        // qo'shib yuborgan "21 soat" xatosini va fon ilovalarni bartaraf etadi.
        var currentPkg: String? = null
        var currentStart = 0L
        var screenInteractive = true // oyna boshida yoniq deb hisoblaymiz

        fun closeCurrent(at: Long) {
            val pkg = currentPkg ?: return
            if (at > currentStart) {
                totals[pkg] = (totals[pkg] ?: 0L) + (at - currentStart)
                lastUsed[pkg] = at
            }
            currentPkg = null
            currentStart = 0L
        }

        val events = usageStatsManager.queryEvents(startTime, endTime)
        val ev = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(ev)
            val t = ev.timeStamp
            when (ev.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    val pkg = ev.packageName ?: continue
                    // Ekran o'chiq paytdagi fon activity launch'larini
                    // (masalan com.microsoft.appmanager) hisoblamaymiz.
                    if (!screenInteractive) continue
                    if (currentPkg != pkg) {
                        closeCurrent(t) // oldingi foreground ilovani yopamiz
                        currentPkg = pkg
                        currentStart = t
                    }
                }
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED -> {
                    if (currentPkg == ev.packageName) {
                        closeCurrent(t)
                    }
                }
                UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                UsageEvents.Event.KEYGUARD_SHOWN,
                UsageEvents.Event.DEVICE_SHUTDOWN -> {
                    // Ekran o'chdi / qulflandi / o'chirildi — sessiyani yopamiz
                    // va ekran qayta yonguncha hisoblamaymiz.
                    closeCurrent(t)
                    screenInteractive = false
                }
                UsageEvents.Event.SCREEN_INTERACTIVE,
                UsageEvents.Event.KEYGUARD_HIDDEN -> {
                    screenInteractive = true
                    // Bu yerda avtomatik sessiya ochmaymiz — keyingi haqiqiy
                    // ACTIVITY_RESUMED kutiladi.
                }
            }
        }
        // Hali ochiq sessiyani FAQAT ekran yoniq bo'lsa hozirgacha yopamiz.
        // Ekran o'chgan bo'lsa currentPkg allaqachon null — butun kun qo'shilmaydi.
        if (screenInteractive) {
            closeCurrent(endTime)
        }

        val pm = context.packageManager
        return totals.entries
            .filter { it.value > 0L }
            .map { (pkg, totalMs) ->
                var appName = pkg
                var iconBase64: String? = null

                try {
                    val appInfo = pm.getApplicationInfo(pkg, 0)
                    appName = pm.getApplicationLabel(appInfo).toString()
                    iconBase64 = drawableToBase64(pm.getApplicationIcon(appInfo))
                } catch (_: PackageManager.NameNotFoundException) {
                    // Package endi yo'q — packageName fallback.
                }

                val map = mutableMapOf<String, Any>(
                    "packageName" to pkg,
                    "appName" to appName,
                    "totalTimeMs" to totalMs,
                    "lastTimeUsed" to (lastUsed[pkg] ?: endTime),
                )
                if (iconBase64 != null) {
                    map["iconBase64"] = iconBase64
                }
                map
            }
            .sortedByDescending { it["totalTimeMs"] as Long }
    }

    /**
     * Ilova O'YIN'mi. Ikkala signalni ham tekshiramiz (kengroq, ishonchli):
     *  1) ApplicationInfo.category == CATEGORY_GAME (Play o'rnatadi, API 26+) —
     *     lekin ba'zi o'yinlarda UNDEFINED bo'ladi, shuning uchun yetarli emas.
     *  2) FLAG_IS_GAME (deprecated, lekin ba'zi o'yinlar manifestida bor).
     */
    private fun isGame(appInfo: ApplicationInfo): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            appInfo.category == ApplicationInfo.CATEGORY_GAME
        ) {
            return true
        }
        @Suppress("DEPRECATION")
        return (appInfo.flags and ApplicationInfo.FLAG_IS_GAME) != 0
    }

    /**
     * `sinceMs` dan beri foreground'ga chiqqan O'YINLAR (CATEGORY_GAME).
     * Har paket uchun oxirgi foreground vaqti. Faqat o'yinlar filtrlanadi —
     * ChildBackgroundTaskHandler buni har siklda o'qib backend'ga POST qiladi
     * (ota-onaga "o'yin o'ynayapti" push). O'zimizning paketni hisoblamaymiz.
     */
    private fun getRecentGameForegrounds(sinceMs: Long): List<Map<String, Any>> {
        if (!hasUsageStatsPermission()) return emptyList()

        val usageStatsManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        // Default: oxirgi 5 daqiqa (sinceMs noto'g'ri bo'lsa).
        val startTime =
            if (sinceMs in 1 until endTime) sinceMs else endTime - 5L * 60L * 1000L

        val pm = context.packageManager
        // package → oxirgi foreground vaqti (faqat o'yinlar).
        val gameLast = LinkedHashMap<String, Long>()
        // appInfo keshi — har paketni bir marta tekshiramiz.
        val gameCache = HashMap<String, Boolean>()

        val events = usageStatsManager.queryEvents(startTime, endTime)
        val ev = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(ev)
            if (ev.eventType != UsageEvents.Event.ACTIVITY_RESUMED) continue
            val pkg = ev.packageName ?: continue
            if (pkg == context.packageName) continue
            val isGamePkg = gameCache.getOrPut(pkg) {
                try {
                    isGame(pm.getApplicationInfo(pkg, 0))
                } catch (_: PackageManager.NameNotFoundException) {
                    false
                }
            }
            if (isGamePkg) {
                gameLast[pkg] = ev.timeStamp
            }
        }

        return gameLast.entries.map { (pkg, ts) ->
            var appName = pkg
            try {
                appName = pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0))
                    .toString()
            } catch (_: PackageManager.NameNotFoundException) {
                // packageName fallback
            }
            mapOf(
                "packageName" to pkg,
                "appName" to appName,
                "timestamp" to ts,
            )
        }
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val resolveInfos = pm.queryIntentActivities(intent, 0)

        return resolveInfos.map { info ->
            val drawable = info.loadIcon(pm)
            val iconBase64 = drawableToBase64(drawable)

            val map = mutableMapOf<String, Any>(
                "packageName" to info.activityInfo.packageName,
                "appName" to info.loadLabel(pm).toString(),
            )
            if (iconBase64 != null) {
                map["iconBase64"] = iconBase64
            }
            map
        }
    }
}
