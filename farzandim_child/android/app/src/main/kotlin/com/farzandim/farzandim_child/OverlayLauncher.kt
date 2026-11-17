package com.farzandim.farzandim_child

import android.app.ActivityOptions
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log

/**
 * Overlay tugmalaridan activity ochish (fn-overlay-buttons-miui-bg-start).
 *
 * Servis kontekstidan oddiy `startActivity` MIUI/HyperOS'da "fonda oyna
 * ochish" ruxsatisiz jimgina bloklanadi; Android 14+ da esa fon activity
 * start'i uchun PendingIntent yuboruvchisi ham, yaratuvchisi ham ruxsatini
 * ochiq bildirishi kerak. Shuning uchun avval PendingIntent + BAL opsiyalari
 * (overlay oynasi ko'rinib turgan va foydalanuvchi uni bosgan — tizim
 * ruxsat beradigan holat), xato bo'lsa — oddiy `startActivity`. MIUI jim
 * rad etsa — [UnlockWatch] + bildirishnoma zaxirasi.
 *
 * MUHIM: overlay YOPILISHIDAN OLDIN chaqirilsin (Android 15+ da ko'rinib
 * turgan oyna fon start'iga ruxsat sharti).
 */
internal object OverlayLauncher {

    private const val TAG = "OverlayLauncher"

    /** @return true — start so'rovi yuborildi (MIUI baribir jim rad etishi mumkin). */
    fun start(ctx: Context, intent: Intent, requestCode: Int): Boolean {
        try {
            val pi = PendingIntent.getActivity(
                ctx,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                creatorOptions(),
            )
            pi.send(ctx, 0, null, null, null, null, senderOptions())
            return true
        } catch (e: Exception) {
            Log.w(TAG, "PendingIntent orqali ochilmadi: ${e.message}")
        }
        return try {
            ctx.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Activity ochilmadi", e)
            false
        }
    }

    private fun creatorOptions(): Bundle? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            @Suppress("DEPRECATION")
            ActivityOptions.makeBasic()
                .setPendingIntentCreatorBackgroundActivityStartMode(
                    ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED,
                )
                .toBundle()
        } else {
            null
        }

    private fun senderOptions(): Bundle? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            @Suppress("DEPRECATION")
            ActivityOptions.makeBasic()
                .setPendingIntentBackgroundActivityStartMode(
                    ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED,
                )
                .toBundle()
        } else {
            null
        }
}
