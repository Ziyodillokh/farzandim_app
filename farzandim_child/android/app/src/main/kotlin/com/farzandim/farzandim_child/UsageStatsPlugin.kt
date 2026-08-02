package com.farzandim.farzandim_child

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
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
import io.flutter.plugin.common.StandardMethodCodec
import java.io.ByteArrayOutputStream

class UsageStatsPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        // MUHIM (ANR/qotish tuzatildi): kanal BACKGROUND task queue'da ishlaydi.
        // Avval `getInstalledApps`/`getUsageStats` — har o'rnatilgan ilova
        // ikonasini 96x96 ga scale + PNG + base64 (60-150 ilova!) — Android
        // MAIN thread'ida bajarilardi va UI'ni 1-3s bloklab "javob bermayapti"
        // (ANR) chiqarardi. Endi bu og'ir ish alohida oqimda; natija Dart'ga
        // MethodChannel orqali xavfsiz qaytadi. Activity/service ochish
        // (openSettings/startRestrictionService) applicationContext + NEW_TASK
        // bilan background'dan ham xavfsiz.
        val taskQueue = binding.binaryMessenger.makeBackgroundTaskQueue()
        channel = MethodChannel(
            binding.binaryMessenger,
            "farzandim/usage_stats",
            StandardMethodCodec.INSTANCE,
            taskQueue,
        )
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        // MUHIM: butun handler try/catch bilan o'ralgan. Aks holda native
        // metod (Settings.canDrawOverlays, startActivity, UsageStatsManager,
        // PackageManager) ushlanmagan exception tashlasa — butun ilova
        // crash bo'ladi (foydalanuvchi "ilovadan chiqib ketyapti" deydi).
        // Endi xato Dart tomonga `result.error` orqali uzatiladi va u yerda
        // try/catch bilan jim yutiladi (permission ekrani ochiq qoladi).
        try {
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
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(null)
                }
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
        } catch (e: Throwable) {
            android.util.Log.e("UsageStatsPlugin", "onMethodCall ${call.method} xato", e)
            result.error("USAGE_STATS_ERROR", e.message, null)
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
     * Bloklash accessibility xizmati yoqilganmi.
     *
     * ⚠️ Avval bu funksiya `RestrictionService`ni qidirardi — u esa oddiy
     * `Service`, accessibility xizmati EMAS. Ya'ni HECH QACHON `true`
     * qaytarmasdi va backend'ga doim `accessibilityEnabled=false` ketardi.
     * Endi haqiqiy [BlockAccessibilityService] tekshiriladi.
     *
     * Ikki manba: avval `AccessibilityManager` (ishonchli), bo'lmasa
     * `Settings.Secure`. Ba'zi OEM'lar komponentni QISQA shaklda saqlaydi
     * (`paket/.Klass`), shuning uchun oddiy string solishtiruv yetarli emas —
     * `ComponentName.unflattenFromString` bilan normallashtiramiz.
     */
    private fun isAccessibilityEnabled(): Boolean {
        val target = ComponentName(
            context.packageName,
            BlockAccessibilityService::class.java.name,
        )

        // 1) Rasmiy API.
        try {
            val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE)
                as? android.view.accessibility.AccessibilityManager
            val list = am?.getEnabledAccessibilityServiceList(
                android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_ALL_MASK,
            )
            if (list != null) {
                val found = list.any {
                    val id = it.id ?: return@any false
                    ComponentName.unflattenFromString(id) == target
                }
                if (found) return true
            }
        } catch (e: Exception) {
            android.util.Log.w("UsageStatsPlugin", "a11y manager xato: ${e.message}")
        }

        // 2) Zaxira — Settings.Secure ro'yxati.
        return try {
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            enabled.split(':').any {
                ComponentName.unflattenFromString(it.trim()) == target
            }
        } catch (_: Exception) {
            false
        }
    }

    /** Tizimning "Maxsus imkoniyatlar" sozlamalarini ochadi. */
    private fun openAccessibilitySettings() {
        try {
            context.startActivity(
                Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (e: Exception) {
            context.startActivity(
                Intent(Settings.ACTION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
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
        return try {
            val appOpsManager =
                context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            // Android 10+ (Q): checkOpNoThrow eskirgan va jarayon qayta ishga
            // tushgach BERILGAN ruxsatga ham MODE_DEFAULT qaytarishi mumkin.
            // Shuning uchun unsafeCheckOpNoThrow (BootReceiver bilan izchil).
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOpsManager.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName,
                )
            } else {
                @Suppress("DEPRECATION")
                appOpsManager.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName,
                )
            }
            // MODE_ALLOWED — aniq ruxsat bor. Aks holda (MODE_DEFAULT/IGNORED)
            // ba'zi OEM'lar (Samsung One UI) ruxsat BERILGANDA ham MODE_ALLOWED
            // bermaydi — AppOps'ga ishonmay, HAQIQIY usage so'rovi bilan
            // aniqlaymiz: ma'lumot qaytsa ruxsat amalda bor.
            if (mode == AppOpsManager.MODE_ALLOWED) true else hasUsageDataAccess()
        } catch (e: Exception) {
            false
        }
    }

    /**
     * AppOps noaniq (MODE_DEFAULT/IGNORED) bo'lganda ruxsatni QAT'IY aniqlaydi:
     * oxirgi 24 soat HODISALARINI so'raydi. `queryEvents` — INTERVAL_DAILY
     * agregatsiyasidan farqli — ruxsat BERILGAN zahoti (yangi grant'da ham)
     * hodisalarni darhol qaytaradi (agregat bucket bir kungacha bo'sh bo'lishi
     * mumkin edi → "yig'ilmoqda" darhol grant'dan keyin). Ruxsat yo'q → bo'sh
     * (istisnosiz). Samsung kabi AppOps MODE_ALLOWED bermaydigan qurilmalarda
     * ham to'g'ri ishlaydi.
     */
    private fun hasUsageDataAccess(): Boolean {
        return try {
            val usm =
                context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val events = usm.queryEvents(now - 24L * 60L * 60L * 1000L, now)
            events != null && events.hasNextEvent()
        } catch (e: Exception) {
            false
        }
    }

    private fun openUsageAccessSettings() {
        // Umumiy "Ilova statistikasi (usage access)" ro'yxatini ochamiz — bu
        // BARCHA qurilmalarda ishonchli ishlaydi.
        //
        // ⚠️ Avval `package:` URI bilan to'g'ridan-to'g'ri ilova sahifasiga
        // o'tardik (qulaylik uchun). LEKIN ba'zi OEM'larda (Samsung One UI,
        // Xiaomi/MIUI) o'sha maxsus sahifada TOGGLE ko'rinmasdi yoki ruxsat
        // berib bo'lmasdi — natijada foydalanuvchi usage-access'ni yoqa olmay,
        // onboarding'da qotib qolib ilovaga KIRA OLMASDI. Umumiy ro'yxatda esa
        // foydalanuvchi "Parvoz Growth"ni topib yoqadi — hamma joyda ishlaydi.
        try {
            context.startActivity(
                Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (e: Exception) {
            // Juda kam qurilmada bu ekran yo'q — umumiy Sozlamalarga.
            context.startActivity(
                Intent(Settings.ACTION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
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
                    // Foreground activity RESUME = ekran ochiq, foydalanuvchi
                    // ilovaga qarab turibdi (SELF-HEAL). Avval `screenInteractive`
                    // latch bo'lib qotib qolar edi — Samsung/Xiaomi KEYGUARD_HIDDEN
                    // yubormasa yoki re-enable timestamp startTime'dan oldin bo'lsa
                    // flag abadiy false qolib, BUTUN ro'yxat bo'shab ketardi
                    // ("ma'lumotlar yig'ilmoqda" abadiy). Endi haqiqiy resume
                    // flag'ni tiklaydi.
                    screenInteractive = true
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
                UsageEvents.Event.DEVICE_SHUTDOWN -> {
                    // FAQAT haqiqiy ekran o'chishi sessiyani yopadi. KEYGUARD_SHOWN
                    // (qulf ekrani) ekran YONIQ bo'lsa ham chiqadi (uyg'otish,
                    // bildirishnoma peek, AOD) va ba'zi OEM'larda KEYGUARD_HIDDEN
                    // ishonchsiz — shuning uchun keyguard hisobga OLINMAYDI (aks
                    // holda flag noto'g'ri false bo'lib ro'yxat bo'shardi).
                    closeCurrent(t)
                    screenInteractive = false
                }
                UsageEvents.Event.SCREEN_INTERACTIVE -> {
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
            // Haqiqiy Android kategoriyasi (GAME/SOCIAL/VIDEO) — backend
            // kategoriya-bloklashda paket-nomi taxminidan ustun. Noaniq bo'lsa
            // qo'shmaymiz → backend classifyPackage hal qiladi.
            val appInfo = info.activityInfo?.applicationInfo
            if (appInfo != null) {
                deviceCategory(appInfo)?.let { map["category"] = it }
            }
            map
        }
    }

    /**
     * ApplicationInfo'dan ishonchli kategoriya (GAME/SOCIAL/VIDEO) yoki null.
     * Faqat yengil signal — manifest kategoriyasi/flag (og'ir APK-skan YO'Q;
     * bu 100+ ilova uchun chaqiriladi). EDU/OTHER va aniqlanmaganlar backend
     * klassifikatoriga qoldiriladi.
     */
    private fun deviceCategory(ai: ApplicationInfo): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            when (ai.category) {
                ApplicationInfo.CATEGORY_GAME -> return "GAME"
                ApplicationInfo.CATEGORY_SOCIAL -> return "SOCIAL"
                ApplicationInfo.CATEGORY_VIDEO -> return "VIDEO"
            }
        }
        @Suppress("DEPRECATION")
        if ((ai.flags and ApplicationInfo.FLAG_IS_GAME) != 0) return "GAME"
        return null
    }
}
