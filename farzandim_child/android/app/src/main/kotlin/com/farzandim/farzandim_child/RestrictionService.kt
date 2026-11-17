package com.farzandim.farzandim_child

import android.app.AlarmManager
import android.app.ForegroundServiceStartNotAllowedException
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import androidx.core.content.ContextCompat
import com.pravera.flutter_foreground_task.service.ForegroundService

/**
 * Ilova cheklovlari foreground servisi (bloklash overlay'i, kunlik limit,
 * School Mode, o'yin aniqlash).
 *
 * Tuzilma (Growth 1.0.20):
 *  - Poll "parvoz-restriction-poll" oqimida ([EnforcementEngine]) — ekran
 *    yoniq paytda har 1 s (cheklov yo'q bo'lsa 3 s, faqat o'yin aniqlash),
 *    ekran o'chiq paytda UMUMAN yo'q (bat-native-no-screen-off-pause).
 *  - Overlay faqat main oqimda ([BlockOverlay]).
 *  - SCREEN_ON / USER_PRESENT — darhol tekshiruv va FGS Dart isolate'ga
 *    `parvoz:screen_on` (Dart cheklovlarni qayta qo'llaydi / yangilaydi).
 *  - Qurilma juftlanmagan (childId yo'q) — overlay yopiladi, watchdog
 *    bekor qilinadi, servis to'xtaydi (fn-unpair-leaves-enforcement).
 *
 * Shartlar: PACKAGE_USAGE_STATS va SYSTEM_ALERT_WINDOW (overlay'siz ham
 * o'yin aniqlash ishlaydi).
 */
class RestrictionService : Service() {

    companion object {
        private const val TAG = "RestrictionService"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"

        // Cheklov bor — bloklangan ilova ochilganda overlay ~1 s ichida chiqsin.
        private const val POLL_INTERVAL_MS = 1_000L

        // Cheklov yo'q — faqat o'yin aniqlash: 3 s yetarli.
        private const val IDLE_POLL_INTERVAL_MS = 3_000L

        // SCREEN_ON va USER_PRESENT ketma-ket kelsa — Dart'ga bitta signal.
        private const val SCREEN_ON_SIGNAL_DEBOUNCE_MS = 3_000L
        private const val SCREEN_ON_MESSAGE = "parvoz:screen_on"

        const val ACTION_START = "com.farzandim.action.START_RESTRICTION"
        const val ACTION_STOP = "com.farzandim.action.STOP_RESTRICTION"

        // Watchdog — OEM batareya-menejeri servisni o'ldirsa uni tiklaydi va
        // FGS Dart isolate'ga 5 daqiqalik `parvoz:tick` yuboradi (BootReceiver).
        const val ACTION_WATCHDOG = "com.farzandim.action.WATCHDOG_RESTART"
        private const val WATCHDOG_REQ = 4243
        private const val WATCHDOG_INTERVAL_MS = 5 * 60 * 1000L

        /** Tirik servis nusxasi (accessibility hook va [isServiceRunning]). */
        @Volatile
        private var instance: RestrictionService? = null

        /** Shu jarayonda servis kuzatayotgan bo'lsa true (BootReceiver ortiqcha start qilmasin). */
        fun isServiceRunning(): Boolean = instance?.isRunning == true

        /**
         * Accessibility servis foreground'ni ANIQLAGANDA chaqiriladi: paket
         * eslab qolinadi va poll oqimiga bitta darhol tekshiruv yuboriladi
         * (overlay egasi yagona — [BlockOverlay]). Servis tirik bo'lmasa jim.
         */
        @Suppress("UNUSED_PARAMETER")
        fun onForegroundFromAccessibility(ctx: Context, pkg: String) {
            val svc = instance ?: return
            try {
                svc.engine.a11yPkg = pkg
                svc.engine.a11yAt = System.currentTimeMillis()
                svc.requestImmediateTick()
            } catch (e: Exception) {
                Log.w(TAG, "a11y hook xato: ${e.message}")
            }
        }

        /**
         * Watchdog alarmni (qayta) o'rnatadi — ~5 daqiqadan keyin BootReceiver
         * `ACTION_WATCHDOG` oladi. `setAndAllowWhileIdle` — Doze'da ham
         * ishlaydi, SCHEDULE_EXACT_ALARM shart emas. Fondan FGS start'i
         * Android 12+ da cheklangan — BootReceiver uni himoyalangan qiladi.
         */
        fun scheduleWatchdog(ctx: Context) {
            try {
                val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val at = System.currentTimeMillis() + WATCHDOG_INTERVAL_MS
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, watchdogPi(ctx))
            } catch (e: Exception) {
                Log.e(TAG, "scheduleWatchdog error", e)
            }
        }

        /** Watchdog alarmni bekor qiladi (servis ATAYIN to'xtatilganda). */
        fun cancelWatchdog(ctx: Context) {
            try {
                val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                am.cancel(watchdogPi(ctx))
                // 1.0.19 va eskiroq: alarm BootReceiver'ga qo'yilgan edi — u ham bekor.
                legacyWatchdogPi(ctx)?.let { am.cancel(it) }
            } catch (e: Exception) {
                Log.e(TAG, "cancelWatchdog error", e)
            }
        }

        private fun legacyWatchdogPi(ctx: Context): PendingIntent? {
            val i = Intent(ctx, BootReceiver::class.java).apply { action = ACTION_WATCHDOG }
            return PendingIntent.getBroadcast(
                ctx,
                WATCHDOG_REQ,
                i,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun watchdogPi(ctx: Context): PendingIntent {
            val i = Intent(ctx, WatchdogReceiver::class.java).apply { action = ACTION_WATCHDOG }
            return PendingIntent.getBroadcast(
                ctx,
                WATCHDOG_REQ,
                i,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var pollThread: HandlerThread? = null
    private var pollHandler: Handler? = null

    @Volatile
    private var isRunning = false

    @Volatile
    private var screenInteractive = true

    // Main oqim holati.
    private var isForeground = false
    private var receiverRegistered = false
    private var lastScreenOnSignalAt = 0L

    private lateinit var notifications: BlockNotifications
    private lateinit var overlay: BlockOverlay
    private lateinit var snapshots: SnapshotSource
    private lateinit var engine: EnforcementEngine
    private val unlockWatch = UnlockWatch()
    private val dismissLatch = DismissLatch { SystemClock.elapsedRealtime() }

    @Volatile
    private var pendingOverlay: OverlayRequest? = null
    private val applyOverlay = Runnable { if (isRunning) overlay.apply(pendingOverlay) }

    private val pollRunnable = object : Runnable {
        override fun run() {
            val handler = pollHandler ?: return
            // Navbatdagi boshqa nusxa (darhol tekshiruv) — bitta zanjir qolsin.
            handler.removeCallbacks(this)
            if (!isRunning || !screenInteractive) return
            try {
                engine.tick()
            } catch (t: Throwable) {
                // Error (OOM va h.k.) ham — oddiy HandlerThread'dan chiqib ketsa
                // butun jarayonni (UI va fon isolate bilan) yiqitardi.
                Log.e(TAG, "Poll error", t)
            }
            if (isRunning && screenInteractive) {
                handler.postDelayed(this, if (engine.hasRules) POLL_INTERVAL_MS else IDLE_POLL_INTERVAL_MS)
            }
        }
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_OFF -> onScreenOff()
                Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT -> onScreenOn()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        val flutterPrefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val texts = NativeTexts(flutterPrefs)
        notifications = BlockNotifications(this, texts)
        notifications.createChannels()
        overlay = BlockOverlay(this, texts, unlockWatch, dismissLatch)
        snapshots = SnapshotSource(flutterPrefs) { requestImmediateTick() }
        engine = EnforcementEngine(this, host, snapshots, NativeStore(this), notifications, unlockWatch, dismissLatch)
        pollThread = HandlerThread("parvoz-restriction-poll").also {
            it.start()
            pollHandler = Handler(it.looper)
        }
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // START_STICKY qayta ishga tushganda OS NULL intent yuboradi — u ham
        // startMonitoring (idempotent).
        when (intent?.action) {
            ACTION_STOP -> stopMonitoring(explicit = true)
            else -> startMonitoring()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * Recents'dan surib tashlanganda ba'zi OEM'lar servisni ham o'ldiradi —
     * monitoring faol bo'lsa watchdog tez tiklasin.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        if (isRunning) scheduleWatchdog(this)
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
        if (instance === this) instance = null
        // Tizim/OEM o'ldirganda ham onDestroy keladi — watchdog O'CHIRILMAYDI
        // (explicit=false), aks holda o'z-o'zini tiklovchi zanjir uzilardi.
        stopMonitoring(explicit = false)
        engine.shutdown()
        pollThread?.quitSafely()
        pollThread = null
        pollHandler = null
    }

    private fun startMonitoring() {
        if (!enterForeground()) return
        if (isRunning) return
        isRunning = true
        Log.d(TAG, "Monitoring started")
        // Avval qabul qiluvchi, keyin holat: oradagi SCREEN_OFF yo'qolmasin.
        registerScreenReceiver()
        screenInteractive = isInteractiveNow()
        snapshots.register()
        // Zanjirni birinchi startda yoqamiz; keyin BootReceiver qayta o'rnatadi.
        scheduleWatchdog(this)
        val flutterPrefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        pollHandler?.post { guarded("onStart") { engine.onStart(flutterPrefs) } }
        requestImmediateTick()
    }

    /**
     * Foreground'ga o'tadi. Allaqachon foreground bo'lsa bildirishnoma qayta
     * post qilinmaydi (tizim yangi startForegroundService uchun vaqt cheklovi
     * qo'ymaydi). Android 12+ da fondan ruxsat yo'q bo'lsa
     * (ForegroundServiceStartNotAllowedException — sticky restart) jarayon
     * yiqilmaydi: servis to'xtaydi, watchdog keyinroq qayta urinadi
     * (kill-native-restriction-startfg-unguarded).
     */
    private fun enterForeground(): Boolean {
        if (isForeground) return true
        return try {
            val notification = notifications.buildServiceNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    BlockNotifications.NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
                )
            } else {
                startForeground(BlockNotifications.NOTIFICATION_ID, notification)
            }
            isForeground = true
            true
        } catch (e: Exception) {
            // Hech qaysi xato jarayonni yiqitmasin: bu jarayonda UI va fon
            // isolate ham bor, START_STICKY + watchdog esa crash siklini berardi.
            val notAllowed = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                e is ForegroundServiceStartNotAllowedException
            if (notAllowed) {
                Log.w(TAG, "startForeground fondan ruxsat etilmadi — watchdog qayta urinadi", e)
            } else {
                Log.e(TAG, "startForeground xato — servis to'xtaydi, watchdog qayta urinadi", e)
            }
            try {
                com.google.firebase.crashlytics.FirebaseCrashlytics.getInstance().recordException(e)
            } catch (_: Throwable) {
            }
            isRunning = false
            stopSelf()
            false
        }
    }

    private fun stopMonitoring(explicit: Boolean) {
        Log.d(TAG, "Monitoring stopped (explicit=$explicit)")
        isRunning = false
        pollHandler?.removeCallbacksAndMessages(null)
        // Watchdog FAQAT atayin to'xtatishda (ACTION_STOP / unpair) o'chadi.
        if (explicit) cancelWatchdog(this)
        unregisterScreenReceiver()
        snapshots.unregister()
        mainHandler.removeCallbacks(applyOverlay)
        overlay.hide()
        if (isForeground) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            isForeground = false
        }
        stopSelf()
    }

    /** Poll oqimiga darhol tekshiruv (istalgan oqimdan). */
    private fun requestImmediateTick() {
        val handler = pollHandler ?: return
        if (!isRunning || !screenInteractive) return
        handler.removeCallbacks(pollRunnable)
        handler.post(pollRunnable)
    }

    // ───────────────────── EnforcementHost (poll oqimidan) ─────────────────────

    private val host = object : EnforcementHost {
        override fun requestOverlay(request: OverlayRequest?) {
            pendingOverlay = request
            mainHandler.removeCallbacks(applyOverlay)
            mainHandler.post(applyOverlay)
        }

        override fun onUnpaired() {
            mainHandler.post {
                if (!isRunning) return@post
                Log.i(TAG, "Qurilma juftlanmagan (childId yo'q) — cheklov xizmati to'xtatildi")
                stopMonitoring(explicit = true)
            }
        }
    }

    // ───────────────────────── Ekran holati (main) ─────────────────────────

    private fun isInteractiveNow(): Boolean =
        try {
            (getSystemService(Context.POWER_SERVICE) as? PowerManager)?.isInteractive ?: true
        } catch (e: Exception) {
            true
        }

    private fun registerScreenReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        try {
            ContextCompat.registerReceiver(this, screenReceiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
            receiverRegistered = true
        } catch (e: Exception) {
            Log.e(TAG, "Ekran receiver ro'yxatdan o'tmadi", e)
        }
    }

    private fun unregisterScreenReceiver() {
        if (!receiverRegistered) return
        receiverRegistered = false
        try {
            unregisterReceiver(screenReceiver)
        } catch (e: Exception) {
            Log.w(TAG, "Ekran receiver o'chirilmadi: ${e.message}")
        }
    }

    /** Poll oqimiga yuborilgan ish xatosi jarayonni yiqitmasin. */
    private inline fun guarded(what: String, block: () -> Unit) {
        try {
            block()
        } catch (t: Throwable) {
            Log.e(TAG, "$what xato", t)
        }
    }

    /** Ekran o'chdi: poll to'xtaydi, foreground va limit sessiyasi tozalanadi. */
    private fun onScreenOff() {
        screenInteractive = false
        val handler = pollHandler ?: return
        handler.removeCallbacks(pollRunnable)
        val at = System.currentTimeMillis()
        handler.post { guarded("onScreenOff") { engine.onScreenOff(at) } }
    }

    /** Ekran yondi / qulf ochildi: darhol tekshiruv + Dart'ga signal. */
    private fun onScreenOn() {
        if (!isRunning) return
        screenInteractive = true
        overlay.invalidatePermission()
        signalScreenOn()
        requestImmediateTick()
    }

    /** FGS Dart isolate'ga `parvoz:screen_on` (MAIN oqimda; FGS ishlamasa plugin jim). */
    private fun signalScreenOn() {
        val now = SystemClock.elapsedRealtime()
        if (lastScreenOnSignalAt != 0L && now - lastScreenOnSignalAt < SCREEN_ON_SIGNAL_DEBOUNCE_MS) return
        lastScreenOnSignalAt = now
        try {
            ForegroundService.sendData(SCREEN_ON_MESSAGE)
        } catch (t: Throwable) {
            Log.w(TAG, "$SCREEN_ON_MESSAGE yuborilmadi: ${t.message}")
        }
    }
}
