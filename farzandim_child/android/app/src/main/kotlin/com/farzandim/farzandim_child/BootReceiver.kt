package com.farzandim.farzandim_child

import android.app.AppOpsManager
import android.app.ForegroundServiceStartNotAllowedException
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import android.util.Log
import androidx.core.content.ContextCompat
import com.pravera.flutter_foreground_task.models.ForegroundServiceAction
import com.pravera.flutter_foreground_task.models.ForegroundServiceStatus
import com.pravera.flutter_foreground_task.models.ForegroundTaskOptions
import com.pravera.flutter_foreground_task.service.ForegroundService
import java.util.Collections

/**
 * BootReceiver — telefon yoqilganda, ilova yangilanganda va har ~5 daqiqada
 * (watchdog alarm, RestrictionService.scheduleWatchdog) ikki servisni tiklaydi:
 *  - native `RestrictionService` (bloklash, o'yin aniqlash);
 *  - flutter_foreground_task FGS — Dart isolate (sync, heartbeat, usage, joylashuv).
 *
 * Ilgari watchdog FAQAT RestrictionService'ni tiklardi: Dart isolate o'lgan
 * bo'lsa jadval/School Mode oynalari muzlab qolardi (kill-native-enforcement-
 * depends-on-dart). Endi tick'da plugin FGS ham tekshiriladi va tirik bo'lsa
 * unga `parvoz:tick` yuboriladi (Dart'ning yagona davriy uyg'otuvchisi).
 *
 * Arzon "issiq yo'l" (bat-native-watchdog-60s): servis tirik bo'lsa qayta
 * startForegroundService YO'Q (notification qayta post qilinmaydi), AppOps /
 * queryUsageStats faqat RestrictionService o'lik bo'lganda; alarm bitta joydan.
 *
 * Juftlanmagan (unpair qilingan) telefonda HECH NARSA boshlanmaydi va watchdog
 * zanjiri to'xtatiladi — eski cheklov kalitlari bilan bloklash reboot'dan keyin
 * qayta yoqilmaydi (fn-unpair-leaves-enforcement).
 *
 * Har bir start himoyalangan; fon start cheklovi (Android 12+) Crashlytics'ga
 * non-fatal sifatida yoziladi — jarayon hech qachon yiqilmaydi.
 */
open class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val trigger = BootPolicy.triggerOf(intent.action)
        if (trigger == BootPolicy.Trigger.IGNORED) return
        // Watchdog tick faqat yopiq (exported=false) [WatchdogReceiver] orqali keladi:
        // bu receiver tashqariga ochiq, istalgan ilova ACTION_WATCHDOG yuborib har
        // safar 30 s wakelock va servis startini chaqirib batareyani yeya olardi.
        if (trigger == BootPolicy.Trigger.WATCHDOG && this !is WatchdogReceiver) return

        if (!ParvozTaskBridge.isPaired(ctx)) {
            Log.d(TAG, "Juftlanmagan — servislar boshlanmadi ($trigger)")
            RestrictionService.cancelWatchdog(ctx)
            return
        }

        // Tick: Dart isolate ishini tugatguncha CPU uxlamasin (vaqtli, max 30 s).
        if (trigger == BootPolicy.Trigger.WATCHDOG) ParvozTaskBridge.holdTickWakeLock(ctx)

        var keepChain = true
        try {
            keepChain = runServices(ctx, trigger)
        } catch (e: Exception) {
            Log.e(TAG, "Servislarni tiklashda xato ($trigger)", e)
        } finally {
            // Zanjir uzilmasin: alarm FAQAT shu yerdan qayta o'rnatiladi (servis
            // tirik bo'lsa ikkinchi chaqiruv yo'q). Hech bir servis kerak bo'lmasa
            // (USAGE ruxsati yo'q + FGS dasturchi tomonidan to'xtatilgan) —
            // keraksiz alarm aylanmaydi; ilova ochilganda Dart qayta yoqadi.
            if (keepChain) {
                RestrictionService.scheduleWatchdog(ctx)
            } else {
                Log.d(TAG, "Hech bir servis kerak emas — watchdog to'xtadi")
            }
        }
    }

    /** @return true — kamida bitta servis kerak (watchdog zanjiri davom etadi). */
    private fun runServices(ctx: Context, trigger: BootPolicy.Trigger): Boolean {
        val reason = trigger.name.lowercase()
        val restrictionWanted = ParvozTaskBridge.reviveRestriction(ctx, reason)
        // Boot/update'da plugin'ning o'z RebootReceiver'i (autoRunOnBoot) FGS'ni
        // yoqadi — ikkinchi start task engine'ni ikki marta yaratardi.
        val pluginWillStart = ParvozTaskBridge.pluginAutoRunCovers(ctx, trigger)
        val task = ParvozTaskBridge.ensureTaskService(ctx, reason, pluginWillStart)
        // Yangi start qilingan FGS onStart'da o'zi to'liq sync qiladi — tick faqat
        // allaqachon ishlab turganiga.
        if (trigger == BootPolicy.Trigger.WATCHDOG &&
            task == ParvozTaskBridge.TaskState.RUNNING
        ) {
            ParvozTaskBridge.sendToTask(BootPolicy.TICK_MESSAGE)
        }
        return restrictionWanted || task != ParvozTaskBridge.TaskState.NOT_WANTED
    }

    companion object {
        private const val TAG = "BootReceiver"
    }
}

/** BootReceiver qarorlari (pure — JVM testda Android'siz tekshiriladi). */
internal object BootPolicy {
    /** Kontrakt: native → FGS Dart isolate (ChildBackgroundTaskHandler.onReceiveData). */
    const val TICK_MESSAGE = "parvoz:tick"

    private const val ACTION_BOOT_COMPLETED = "android.intent.action.BOOT_COMPLETED"
    private const val ACTION_QUICKBOOT = "android.intent.action.QUICKBOOT_POWERON"
    private const val ACTION_PACKAGE_REPLACED = "android.intent.action.MY_PACKAGE_REPLACED"

    enum class Trigger { BOOT, PACKAGE_REPLACED, WATCHDOG, IGNORED }

    fun triggerOf(action: String?): Trigger =
        when (action) {
            ACTION_BOOT_COMPLETED, ACTION_QUICKBOOT -> Trigger.BOOT
            ACTION_PACKAGE_REPLACED -> Trigger.PACKAGE_REPLACED
            RestrictionService.ACTION_WATCHDOG -> Trigger.WATCHDOG
            else -> Trigger.IGNORED
        }

    /** Plugin'ning RebootReceiver'i shu hodisada FGS'ni o'zi yoqadimi. */
    fun pluginAutoRunCovers(
        trigger: Trigger,
        autoRunOnBoot: Boolean,
        autoRunOnPackageReplaced: Boolean,
    ): Boolean =
        when (trigger) {
            Trigger.BOOT -> autoRunOnBoot
            Trigger.PACKAGE_REPLACED -> autoRunOnPackageReplaced
            Trigger.WATCHDOG, Trigger.IGNORED -> false
        }

    /** Juftlanganmi — Dart `prefs.setString('childId', ...)` (unpair'da o'chiriladi). */
    fun isPairedValue(childId: String?): Boolean = !childId.isNullOrBlank()
}

/**
 * Native → FGS Dart isolate ko'prigi (dizayn kontrakti, "Native ↔ Dart").
 * BootReceiver (watchdog tick) va FarzandimMessagingService (data push)
 * ishlatadi. FGS start/sendData — BOSH OQIMDA (MethodChannel talabi).
 */
internal object ParvozTaskBridge {
    private const val TAG = "ParvozTaskBridge"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY_CHILD_ID = "flutter.childId"
    private const val TICK_WAKELOCK_TAG = "Parvoz:tick"
    private const val TICK_WAKELOCK_MS = 30_000L
    private const val DAY_MS = 24L * 60L * 60L * 1000L

    /** Plugin FGS holati: ishlayapti / start so'raldi / kerak emas (API_STOP). */
    enum class TaskState { RUNNING, RESTART_REQUESTED, NOT_WANTED }

    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    @Volatile
    private var tickWakeLock: PowerManager.WakeLock? = null

    // Bir jarayonda bir xil start xatosi Crashlytics'ga faqat bir marta yoziladi.
    private val reportedFailures: MutableSet<String> =
        Collections.synchronizedSet(HashSet())

    fun isPaired(ctx: Context): Boolean =
        try {
            BootPolicy.isPairedValue(
                ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                    .getString(KEY_CHILD_ID, null),
            )
        } catch (e: Exception) {
            // O'qib bo'lmadi — eski xulq (juftlanish tekshiruvisiz) saqlanadi.
            Log.w(TAG, "childId o'qilmadi", e)
            true
        }

    fun isTaskRunning(): Boolean =
        try {
            ForegroundService.isRunningServiceState.value
        } catch (t: Throwable) {
            false
        }

    /**
     * Plugin FGS'ni kafolatlaydi. Dasturchi to'xtatgan bo'lsa (API_STOP —
     * unpair/logout) qayta yoqilmaydi. [pluginWillStart] — plugin'ning o'z
     * RebootReceiver'i shu hodisada yoqadi (bu yerda start qilinmaydi).
     */
    fun ensureTaskService(
        ctx: Context,
        reason: String,
        pluginWillStart: Boolean = false,
    ): TaskState {
        if (isTaskRunning()) return TaskState.RUNNING
        if (isTaskStoppedByApp(ctx)) return TaskState.NOT_WANTED
        if (!pluginWillStart) startTaskService(ctx, reason)
        return TaskState.RESTART_REQUESTED
    }

    fun pluginAutoRunCovers(ctx: Context, trigger: BootPolicy.Trigger): Boolean {
        if (trigger == BootPolicy.Trigger.WATCHDOG || trigger == BootPolicy.Trigger.IGNORED) {
            return false
        }
        return try {
            val options = ForegroundTaskOptions.getData(ctx)
            BootPolicy.pluginAutoRunCovers(
                trigger,
                options.autoRunOnBoot,
                options.autoRunOnMyPackageReplaced,
            )
        } catch (e: Exception) {
            false
        }
    }

    /** BOSH OQIMDA. FGS ishlamasa — jim (plugin o'zi tekshiradi). */
    fun sendToTask(message: String) {
        try {
            ForegroundService.sendData(message)
        } catch (e: Exception) {
            Log.w(TAG, "sendData xato ($message)", e)
        }
    }

    /**
     * Istalgan oqimdan (FCM worker): bosh oqimda FGS ishlayotgan bo'lsa xabar
     * yuboradi, aks holda uni qayta yoqadi (high-priority FCM oynasida fon
     * start ruxsat etilgan) — yangi start onStart'da o'zi to'liq sync qiladi.
     */
    fun deliverFromBackground(ctx: Context, message: String, reason: String) {
        val app = ctx.applicationContext
        mainHandler.post { deliver(app, message, reason) }
    }

    private fun deliver(ctx: Context, message: String, reason: String) {
        try {
            if (!isPaired(ctx)) return
            if (ensureTaskService(ctx, reason) == TaskState.RUNNING) sendToTask(message)
        } catch (e: Exception) {
            Log.w(TAG, "deliver xato ($reason)", e)
        }
    }

    /**
     * RestrictionService o'lik bo'lsa (va USAGE ruxsati bo'lsa) qayta yoqadi.
     * Tirik bo'lsa hech narsa qilmaydi (AppOps ham chaqirilmaydi).
     * @return true — servis kerak (ishlayapti yoki start so'raldi).
     */
    fun reviveRestriction(ctx: Context, reason: String): Boolean {
        if (isRestrictionRunning()) return true
        if (!hasUsageAccess(ctx)) {
            Log.d(TAG, "USAGE_STATS yo'q — RestrictionService boshlanmadi ($reason)")
            return false
        }
        try {
            val svc = Intent(ctx, RestrictionService::class.java).apply {
                action = RestrictionService.ACTION_START
            }
            ContextCompat.startForegroundService(ctx, svc)
            Log.d(TAG, "RestrictionService qayta boshlandi ($reason)")
        } catch (e: Exception) {
            reportStartFailure(ctx, "restriction", reason, e)
        }
        return true
    }

    /** Tick wakelock — vaqtli (30 s), reference-count'siz: qayta olish muddatni yangilaydi. */
    fun holdTickWakeLock(ctx: Context) {
        try {
            val lock = tickWakeLock ?: createTickWakeLock(ctx).also { tickWakeLock = it }
            lock.acquire(TICK_WAKELOCK_MS)
        } catch (e: Exception) {
            Log.w(TAG, "tick wakelock olinmadi", e)
        }
    }

    private fun createTickWakeLock(ctx: Context): PowerManager.WakeLock {
        val pm = ctx.applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, TICK_WAKELOCK_TAG).apply {
            setReferenceCounted(false)
        }
    }

    private fun isTaskStoppedByApp(ctx: Context): Boolean =
        try {
            ForegroundServiceStatus.getData(ctx).isCorrectlyStopped()
        } catch (e: Exception) {
            true
        }

    private fun startTaskService(ctx: Context, reason: String) {
        try {
            // Plugin'ning RebootReceiver/RestartReceiver'i bilan bir xil: holat
            // RESTART yoziladi → onStartCommand task (Dart isolate)ni qayta yaratadi.
            ForegroundServiceStatus.setData(ctx, ForegroundServiceAction.RESTART)
            ContextCompat.startForegroundService(ctx, Intent(ctx, ForegroundService::class.java))
            Log.d(TAG, "Plugin FGS qayta ishga tushirildi ($reason)")
        } catch (e: Exception) {
            reportStartFailure(ctx, "task", reason, e)
        }
    }

    private fun isRestrictionRunning(): Boolean =
        try {
            RestrictionService.isServiceRunning()
        } catch (t: Throwable) {
            false
        }

    /** PACKAGE_USAGE_STATS ruxsati (AppOps). Faqat RestrictionService o'lik bo'lganda chaqiriladi. */
    private fun hasUsageAccess(ctx: Context): Boolean =
        try {
            val aom = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
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
            mode == AppOpsManager.MODE_ALLOWED || hasRecentUsageData(ctx)
        } catch (e: Exception) {
            false
        }

    private fun hasRecentUsageData(ctx: Context): Boolean {
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        return !usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - DAY_MS, now)
            .isNullOrEmpty()
    }

    private fun reportStartFailure(ctx: Context, target: String, reason: String, e: Exception) {
        val notAllowed = isStartNotAllowed(e)
        Log.e(TAG, "$target start bo'lmadi ($reason, notAllowed=$notAllowed)", e)
        if (!reportedFailures.add("$target:${e.javaClass.name}")) return
        NativeCrashlytics.recordNonFatal(
            ctx,
            e,
            "fgs_start_failed target=$target reason=$reason notAllowed=$notAllowed",
        )
    }

    /** Android 12+ fon FGS start cheklovi. */
    private fun isStartNotAllowed(e: Exception): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            e is ForegroundServiceStartNotAllowedException
}
