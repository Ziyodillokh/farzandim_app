package com.farzandim.farzandim_child

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.telecom.TelecomManager
import android.util.Log

/**
 * Qo'ng'iroq xavfsizligi — Android qismi (qoidalar: [TelephonyRules]).
 *
 *  - [packages]: standart/tizim teruvchisi, ACTION_DIAL'ni ochadigan tizim
 *    ilovalari va ma'lum qo'ng'iroq UI paketlari — hech qachon bloklanmaydi
 *    ([BlockPolicy.alwaysAllow] orqali). Ruxsat talab qilinmaydi.
 *  - [audioMode]: qo'ng'iroq paytida overlay ko'rsatilmaydi (ruxsatsiz).
 */
internal object TelephonyGuard {

    private const val TAG = "TelephonyGuard"
    private const val CACHE_TTL_MS = 5 * 60 * 1000L

    @Volatile
    private var cache: Set<String>? = null

    @Volatile
    private var cacheAt = 0L

    fun packages(ctx: Context): Set<String> {
        val now = SystemClock.elapsedRealtime()
        cache?.let { if (now - cacheAt < CACHE_TTL_MS) return it }
        val telecom = ctx.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
        val defaultDialer = try {
            telecom?.defaultDialerPackage
        } catch (e: Exception) {
            null
        }
        val systemDialer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                telecom?.systemDialerPackage
            } catch (e: Exception) {
                null
            }
        } else {
            null
        }
        val out = TelephonyRules.allowSet(defaultDialer, systemDialer, systemDialHandlers(ctx))
        cache = out
        cacheAt = now
        return out
    }

    /** ACTION_DIAL'ni ochadigan TIZIM ilovalari (uchinchi tomon DIAL e'loni blokdan qochirmaydi). */
    private fun systemDialHandlers(ctx: Context): List<String> {
        val pm = ctx.packageManager
        val out = ArrayList<String>()
        val intents = listOf(Intent(Intent.ACTION_DIAL), Intent(Intent.ACTION_DIAL, Uri.parse("tel:")))
        for (intent in intents) {
            try {
                for (ri in pm.queryIntentActivities(intent, 0)) {
                    val ai = ri.activityInfo?.applicationInfo ?: continue
                    val isSystem = (ai.flags and
                        (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP)) != 0
                    if (isSystem) out += ai.packageName
                }
            } catch (e: Exception) {
                Log.w(TAG, "DIAL ilovalari aniqlanmadi: ${e.message}")
            }
        }
        return out
    }

    /** Joriy audio rejimi (xato bo'lsa — oddiy). */
    fun audioMode(ctx: Context): Int =
        try {
            (ctx.getSystemService(Context.AUDIO_SERVICE) as? AudioManager)?.mode
                ?: TelephonyRules.MODE_NORMAL
        } catch (e: Exception) {
            TelephonyRules.MODE_NORMAL
        }
}
