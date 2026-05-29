package com.farzandim.farzandim_child

import android.app.AppOpsManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
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
            "hasOverlayPermission" -> result.success(hasOverlayPermission())
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
     * Sprint 4.4.37: `queryUsageStats(INTERVAL_DAILY, ...)` o'rniga
     * `queryAndAggregateUsageStats(start, end)` ishlatamiz. INTERVAL_DAILY
     * eski snapshot qaytaradi (hozirgi sessiya hisoblanmaydi), va kalendar
     * kun emas, balki rolling 24h interval bo'lar edi. Aggregate metod —
     * real-time (hozirgi foreground ham hisoblanadi) va bitta package
     * uchun 1 ta jami qiymat qaytaradi.
     */
    private fun getUsageStats(days: Int): List<Map<String, Any>> {
        if (!hasUsageStatsPermission()) return emptyList()

        val usageStatsManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        val endTime = System.currentTimeMillis()
        val startTime: Long = if (days <= 1) {
            // Bugun: kalendar kun boshidan (00:00) hozirgacha — real-time.
            val cal = java.util.Calendar.getInstance().apply {
                set(java.util.Calendar.HOUR_OF_DAY, 0)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
            }
            cal.timeInMillis
        } else {
            // Ko'p kun: rolling N×24h (haftalik view uchun, real-time
            // emasligi muhim emas — aggregate haftalik).
            endTime - (days * 24L * 60L * 60L * 1000L)
        }

        // queryAndAggregateUsageStats: Map<packageName, UsageStats>
        // real-time totalTimeInForeground bilan (hozirgi sessiya ham).
        val aggregateStats: Map<String, UsageStats> =
            usageStatsManager.queryAndAggregateUsageStats(startTime, endTime)

        val pm = context.packageManager
        return aggregateStats.values
            .map { stat ->
                // Sprint 4.4.39: foreground vaqt + foreground service vaqt
                // (Android 10+). YouTube fon audio, Spotify, navigator —
                // foreground service sifatida ishlaydi va totalTimeInForeground
                // ga kirmaydi. totalTimeForegroundServiceUsed bilan qo'shamiz.
                val foregroundMs = stat.totalTimeInForeground
                val serviceMs = getForegroundServiceTimeMs(stat)
                val totalMs = foregroundMs + serviceMs
                Triple(stat, totalMs, serviceMs)
            }
            .filter { it.second > 0 }
            .map { (stat, totalMs, _) ->
                var appName = stat.packageName
                var iconBase64: String? = null

                try {
                    val appInfo = pm.getApplicationInfo(stat.packageName, 0)
                    appName = pm.getApplicationLabel(appInfo).toString()
                    val drawable = pm.getApplicationIcon(appInfo)
                    iconBase64 = drawableToBase64(drawable)
                } catch (_: PackageManager.NameNotFoundException) {
                    // Package no longer installed — fall back to packageName
                }

                val map = mutableMapOf<String, Any>(
                    "packageName" to stat.packageName,
                    "appName" to appName,
                    "totalTimeMs" to totalMs,
                    "lastTimeUsed" to stat.lastTimeUsed,
                    "firstTimeStamp" to stat.firstTimeStamp,
                    "lastTimeStamp" to stat.lastTimeStamp,
                )
                if (iconBase64 != null) {
                    map["iconBase64"] = iconBase64
                }
                map
            }
            .sortedByDescending { it["totalTimeMs"] as Long }
    }

    /**
     * Sprint 4.4.39: foreground service vaqt (Android 10+, API 29).
     * YouTube fon audio, Spotify, navigation app — foreground service
     * sifatida ishlaydi. UsageStats.totalTimeForegroundServiceUsed field
     * shu vaqtni o'lchaydi. Eski Android versiyalarda 0 qaytaradi.
     */
    private fun getForegroundServiceTimeMs(stat: UsageStats): Long {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return 0L
        return try {
            stat.totalTimeForegroundServiceUsed
        } catch (_: NoSuchMethodError) {
            0L
        } catch (_: Exception) {
            0L
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
