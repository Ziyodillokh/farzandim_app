package com.farzandim.farzandim_child

import android.app.AppOpsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.util.Log

/**
 * BootReceiver — telefon yoqilganda yoki ilova yangilanganda native
 * `RestrictionService`'ni avtomatik qayta ishga tushiradi.
 *
 * NEGA KERAK: `RestrictionService` (o'yin aniqlash + ilova bloklash) faqat
 * Dart `_startRestrictionServiceIfReady()` (pairing_provider) orqali, ya'ni
 * ilova OCHILGANDA boshlanadi. Telefon o'chib-yongach yoki ilova
 * yangilangach (APK update) servis o'ladi va bola Parvoz'ni qayta ochmasa
 * — o'yin aniqlash UMUMAN ishlamaydi (notifyGamePlay hech qachon
 * chaqirilmaydi → ota-onaga "o'ynayapti" push kelmaydi).
 *
 * `flutter_foreground_task` servisi o'zining `autoRunOnBoot` +
 * `autoRunOnMyPackageReplaced` sozlamasi bilan o'zi qaytadi (lokatsiya/
 * batareya/o'yin-POST). Bu receiver esa FAQAT native RestrictionService'ni
 * tiklaydi — shu bilan o'yin aniqlash reboot/update'dan keyin ham ishlaydi.
 *
 * Android 12+ (API 31+) background'dan foreground-service boshlash
 * cheklangan, AMMO BOOT_COMPLETED / MY_PACKAGE_REPLACED qabul qiluvchilar
 * bunga ISTISNO — shuning uchun bu yerdan startForegroundService xavfsiz.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != "android.intent.action.QUICKBOOT_POWERON" &&
            action != RestrictionService.ACTION_WATCHDOG
        ) {
            return
        }

        // Watchdog tick — servis fonda o'ldirilgan bo'lsa qayta tiklaydi va
        // (pastda) keyingi alarmni rejalashtiradi (o'z-o'zini davolovchi zanjir).
        val isWatchdog = action == RestrictionService.ACTION_WATCHDOG

        // RestrictionService faqat USAGE_STATS ruxsati bo'lsa ma'noli ishlaydi
        // (getForegroundPackage/detectAndQueueGame shu ruxsatga tayanadi).
        // Ruxsat berilmagan (hali sozlanmagan / bekor qilingan) bo'lsa servisni
        // boshlamaymiz VA watchdog zanjirini davom ettirmaymiz (keraksiz alarm
        // aylanmasin — ilova qayta ochilganda Dart uni qaytadan yoqadi).
        if (!hasUsageStats(ctx)) {
            Log.d(TAG, "USAGE_STATS yo'q — RestrictionService boshlanmadi")
            return
        }

        val svc = Intent(ctx, RestrictionService::class.java).apply {
            this.action = RestrictionService.ACTION_START
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(svc)
            } else {
                ctx.startService(svc)
            }
            Log.d(TAG, "RestrictionService qayta boshlandi ($action)")
        } catch (e: Exception) {
            Log.e(TAG, "RestrictionService boshlashda xato ($action)", e)
        } finally {
            // Zanjir uzilmasin: watchdog tick keyingi alarmni HAR DOIM qayta
            // o'rnatadi (servis start muvaffaqiyatli bo'lsa u ham o'rnatadi —
            // bu ikki-himoya: FGS-start bloklansa ham zanjir davom etadi).
            if (isWatchdog) RestrictionService.scheduleWatchdog(ctx)
        }
    }

    /** Ilovada PACKAGE_USAGE_STATS ruxsati yoqilganmi (AppOps). */
    private fun hasUsageStats(ctx: Context): Boolean {
        return try {
            val aom =
                ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                aom.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    ctx.packageName,
                )
            } else {
                @Suppress("DEPRECATION")
                aom.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    ctx.packageName,
                )
            }
            // MODE_ALLOWED — aniq ruxsat. Aks holda (OEM: Samsung ruxsat
            // berilgan-u MODE_ALLOWED bermaydi) — haqiqiy usage so'rovi bilan.
            if (mode == AppOpsManager.MODE_ALLOWED) {
                true
            } else {
                val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE)
                    as android.app.usage.UsageStatsManager
                val now = System.currentTimeMillis()
                val stats = usm.queryUsageStats(
                    android.app.usage.UsageStatsManager.INTERVAL_DAILY,
                    now - 24L * 60L * 60L * 1000L,
                    now,
                )
                !stats.isNullOrEmpty()
            }
        } catch (e: Exception) {
            false
        }
    }

    companion object {
        private const val TAG = "BootReceiver"
    }
}
