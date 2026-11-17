package com.farzandim.farzandim_child

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Native matnlar tarjimasi: Dart (UI isolate) `flutter.restriction.i18n.<key>`
 * ga yozadi; yo'q bo'lsa Uzbek fallback (regressiya yo'q).
 */
internal class NativeTexts(private val prefs: SharedPreferences) {
    fun get(key: String, fallback: String): String =
        try {
            prefs.getString("flutter.restriction.i18n.$key", null)
                ?.takeIf { it.isNotBlank() } ?: fallback
        } catch (e: Exception) {
            fallback
        }
}

/**
 * RestrictionService bildirishnomalari: doimiy FGS bildirishnomasi, "vaqting
 * tugayapti" ogohlantirishi va MIUI uchun "Ruxsat so'rash" zaxirasi. Barcha
 * matnlar [NativeTexts] orqali (fn-minor-enforcement-edges).
 */
internal class BlockNotifications(
    private val ctx: Context,
    private val texts: NativeTexts,
) {
    companion object {
        private const val TAG = "BlockNotifications"
        const val CHANNEL_ID = "farzandim_restriction"
        const val NOTIFICATION_ID = 4242
        private const val WARN_CHANNEL_ID = "farzandim_limit_warning"
        private const val WARN_NOTIFICATION_BASE = 5200
        private const val UNLOCK_NOTIFICATION_BASE = 5600
        private const val ID_MASK = 0xFFF
        private const val BRAND_COLOR = 0xFF216BFF.toInt()
        const val EXTRA_UNLOCK_PACKAGE = "unlock_request_package"
    }

    private val manager: NotificationManager? =
        ctx.getSystemService(NotificationManager::class.java)

    /** Kanallar (qayta chaqirilsa nomi/tavsifi yangilanadi). */
    fun createChannels() {
        try {
            manager?.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    texts.get("serviceChannel", "Parvoz cheklov xizmati"),
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = texts.get("serviceChannelDesc", "Ilova cheklovlarini kuzatish")
                    setShowBadge(false)
                },
            )
            // Limit ogohlantirish kanali — HIGH (heads-up + ovoz), bola sezsin.
            manager?.createNotificationChannel(
                NotificationChannel(
                    WARN_CHANNEL_ID,
                    texts.get("warnChannel", "Vaqt tugashi ogohlantirishi"),
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = texts.get(
                        "warnChannelDesc",
                        "Ilova vaqti tugashidan oldin ogohlantirish",
                    )
                    setShowBadge(true)
                },
            )
        } catch (e: Exception) {
            Log.w(TAG, "Kanallar yaratilmadi: ${e.message}")
        }
    }

    /**
     * Doimiy FGS bildirishnomasi. Brend Parvoz ikonkasi — Play Monitoring
     * siyosati ilovani ANIQ identifikatsiya qilishni talab qiladi.
     * ⚠️ @drawable/ic_stat_parvoz — ALPHA-ONLY vektor; @mipmap/ic_launcher
     * ishlatilmasin (status bar'da oq kvadrat chiqadi).
     */
    fun buildServiceNotification(): Notification =
        NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setContentTitle(texts.get("serviceTitle", "Parvoz faol"))
            .setContentText(texts.get("serviceText", "Ilova cheklovlari kuzatilmoqda"))
            .setSmallIcon(R.drawable.ic_stat_parvoz)
            .setColor(BRAND_COLOR)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    /** "Vaqting tugayapti" — bosilsa unlock so'rov modali ochiladi. */
    fun showLimitWarning(pkg: String, label: String, remainingMinutes: Long) {
        val template = texts.get(
            "timeRunningOutBody",
            "{label} uchun bugungi vaqtingga ~{min} daqiqa qoldi. " +
                "Ko'proq vaqt uchun bosib ota-onangdan so'ra.",
        )
        val text = LimitWarningRules.formatBody(template, label, remainingMinutes)
        notify(
            id = WARN_NOTIFICATION_BASE + (pkg.hashCode() and ID_MASK),
            title = texts.get("timeRunningOut", "Vaqting tugayapti"),
            text = text,
            pkg = pkg,
        )
    }

    /**
     * MIUI/HyperOS zaxirasi: "Ruxsat so'rash" bosildi, lekin Parvoz ochilmadi
     * (fonda oyna ochish taqiqlangan). Bildirishnoma bosilishi har doim
     * activity ocha oladi.
     */
    fun showUnlockFallback(pkg: String, label: String) {
        notify(
            id = UNLOCK_NOTIFICATION_BASE + (pkg.hashCode() and ID_MASK),
            title = texts.get("requestAccess", "Ruxsat so'rash"),
            text = texts.get("requestAccessTap", "{label}: ruxsat so'rash uchun shu yerga bosing")
                .replace("{label}", label),
            pkg = pkg,
        )
    }

    private fun notify(id: Int, title: String, text: String, pkg: String) {
        try {
            val tapIntent = Intent(ctx, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(EXTRA_UNLOCK_PACKAGE, pkg)
            }
            val pi = PendingIntent.getActivity(
                ctx,
                id,
                tapIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val notification = NotificationCompat.Builder(ctx, WARN_CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .setSmallIcon(R.drawable.ic_stat_parvoz)
                .setColor(BRAND_COLOR)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pi)
                .build()
            manager?.notify(id, notification)
        } catch (e: Exception) {
            Log.w(TAG, "Bildirishnoma ko'rsatilmadi: ${e.message}")
        }
    }
}
