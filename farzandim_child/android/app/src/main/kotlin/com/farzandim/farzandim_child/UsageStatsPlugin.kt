package com.farzandim.farzandim_child

import android.app.AppOpsManager
import android.app.usage.UsageEvents
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
            // Bugun: kalendar kun boshidan (00:00) hozirgacha.
            val cal = java.util.Calendar.getInstance().apply {
                set(java.util.Calendar.HOUR_OF_DAY, 0)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
            }
            cal.timeInMillis
        } else {
            endTime - (days * 24L * 60L * 60L * 1000L)
        }

        // package → jami foreground ms / oxirgi ts / ochiq sessiya boshi.
        val totals = HashMap<String, Long>()
        val lastUsed = HashMap<String, Long>()
        val resumeAt = HashMap<String, Long>()

        val events = usageStatsManager.queryEvents(startTime, endTime)
        val ev = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(ev)
            val pkg = ev.packageName ?: continue
            when (ev.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    resumeAt[pkg] = ev.timeStamp
                }
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED -> {
                    val start = resumeAt.remove(pkg)
                    if (start != null && ev.timeStamp > start) {
                        totals[pkg] = (totals[pkg] ?: 0L) + (ev.timeStamp - start)
                        lastUsed[pkg] = ev.timeStamp
                    }
                }
            }
        }
        // Hozir ham foreground'da ochiq sessiyalarni hozirgacha yopamiz.
        for ((pkg, start) in resumeAt) {
            if (endTime > start) {
                totals[pkg] = (totals[pkg] ?: 0L) + (endTime - start)
                lastUsed[pkg] = endTime
            }
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
