package com.farzandim.farzandim_child

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * ListenService — "Ota-onangiz tinglamoqda" indikatori + mikrofon foreground
 * service qobig'i.
 *
 * ⚠️ BU SERVIS OVOZNI YOZMAYDI VA UZATMAYDI. Ovozni Flutter tomonidagi WebRTC
 * (flutter_webrtc) ushlaydi va bola→ota-ona to'g'ridan-to'g'ri (P2P) yuboradi —
 * serverga tegmaydi, faylga yozilmaydi. Bu servisning YAGONA vazifasi:
 *   1. O'CHIRILMAYDIGAN bildirishnoma ko'rsatish ("Ota-onangiz tinglamoqda")
 *      — funksiyaning qonuniyligini ta'minlaydigan indikator (Google Play
 *      farzand-nazorati istisnosi talabi);
 *   2. `microphone` tipidagi foreground service sifatida ishlab, Flutter
 *      WebRTC mikrofon oqimini fon rejimida QONUNIY ushlab turish (Android
 *      14+ da busiz fonda mikrofon ishlamaydi).
 *
 * ⚠️ FONDAN ISHGA TUSHIRMANG: Android 14+ da `microphone` tipidagi FGS'ni
 * fondan (FCM) boshlab bo'lmaydi (SYSTEM_ALERT_WINDOW ham yordam bermaydi).
 * Shuning uchun bu servis FAQAT ilova FOREGROUND'da bo'lganda, Dart tomondan
 * (MethodChannel orqali) ishga tushiriladi. FCM push esa avval
 * [buildIndicatorNotification] bilan indikatorni ko'rsatib, MainActivity'ni
 * (Flutter) full-screen intent orqali oldinga chiqaradi.
 */
class ListenService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val stopRunnable = Runnable { stopSelf() }

    companion object {
        private const val TAG = "ListenService"
        const val CHANNEL_ID = "farzandim_child_listen"
        const val NOTIFICATION_ID = 7712
        const val ACTION_START = "com.farzandim.farzandim_child.LISTEN_START"
        const val ACTION_STOP = "com.farzandim.farzandim_child.LISTEN_STOP"
        const val EXTRA_SESSION_ID = "sessionId"

        /**
         * Backend'dagi 30 daqiqalik chegara bilan mos MUSTAQIL xavfsizlik
         * timeout'i — biror nosozlikda mikrofon uzoq qolib ketmasin.
         */
        private const val MAX_DURATION_MS = 30 * 60 * 1000L

        /**
         * Bola "To'xtatish" bosganda yoki timeout'da Dart'ga xabar berish uchun
         * callback. MainActivity uni MethodChannel bilan bog'laydi. null bo'lsa
         * (Flutter engine tirik emas) — WebRTC allaqachon ishlamayapti, faqat
         * FGS to'xtaydi va backend cron sessiyani yopadi.
         */
        @Volatile
        var onStopRequested: (() -> Unit)? = null

        /** Dart (foreground) ishga tushiradi — ilova oldinda bo'lishi SHART. */
        fun start(ctx: Context, sessionId: String) {
            val i = Intent(ctx, ListenService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_SESSION_ID, sessionId)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(i)
            } else {
                ctx.startService(i)
            }
        }

        fun stop(ctx: Context) {
            ctx.startService(
                Intent(ctx, ListenService::class.java).apply { action = ACTION_STOP },
            )
        }

        /**
         * Indikatorni DARHOL ko'rsatadi (ilova yopiq bo'lsa ham) — FCM
         * `listen_request` kelganda [FarzandimMessagingService] chaqiradi.
         * Full-screen intent MainActivity'ni (Flutter) oldinga chiqaradi va
         * mikrofon FGS o'sha foreground kontekstdan ishga tushadi.
         */
        fun notifyIndicator(ctx: Context, sessionId: String) {
            ensureChannel(ctx)
            val nm =
                ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, buildIndicatorNotification(ctx, sessionId))
        }

        fun ensureChannel(ctx: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager =
                ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) != null) return
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Jonli tinglash holati",
                // HIGH — indikator yaqqol ko'rinishi SHART (qonuniylik).
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description =
                    "Ota-ona atrofingizni tinglayotganda doim ko'rinadigan belgi"
                setSound(null, null)
                setShowBadge(true)
            }
            manager.createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            // Bola notification'dagi "To'xtatish" ni bosdi → Dart WebRTC'ni
            // yopadi va backend'ga POST /end yuboradi.
            try {
                onStopRequested?.invoke()
            } catch (e: Exception) {
                Log.w(TAG, "onStopRequested failed", e)
            }
            stopSelf()
            return START_NOT_STICKY
        }

        val sessionId = intent?.getStringExtra(EXTRA_SESSION_ID) ?: ""
        startAsForeground(sessionId)

        handler.removeCallbacks(stopRunnable)
        handler.postDelayed(stopRunnable, MAX_DURATION_MS)
        return START_NOT_STICKY
    }

    private fun startAsForeground(sessionId: String) {
        val notification = buildIndicatorNotification(this, sessionId)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // Fondan ishga tushsa (kutilmagan holat) bu yerga tushadi. Dart
            // faqat foreground'da chaqiradi, shuning uchun odatda bo'lmaydi.
            Log.e(TAG, "startForeground failed", e)
            stopSelf()
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(stopRunnable)
        onStopRequested = null
        super.onDestroy()
    }
}

/**
 * "Ota-onangiz tinglamoqda" indikator bildirishnomasi. FarzandimMessagingService
 * (FCM, ilova yopiq) ham, ListenService (FGS) ham SHU funksiyani ishlatadi —
 * shu sabab indikator FCM kelgan lahzadan boshlab ko'rinadi va uzluksiz qoladi.
 *
 * setOngoing(true) — bola surib yubora olmaydi. To'xtatish esa faqat aniq
 * "To'xtatish" tugmasi orqali.
 */
fun buildIndicatorNotification(ctx: Context, sessionId: String): Notification {
    val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    } else {
        PendingIntent.FLAG_UPDATE_CURRENT
    }

    // To'xtatish → ListenService (ACTION_STOP) → Dart WebRTC'ni yopadi.
    val stopIntent = Intent(ctx, ListenService::class.java).apply {
        action = ListenService.ACTION_STOP
    }
    val stopPending = PendingIntent.getService(ctx, 3, stopIntent, piFlags)

    // Bosilganda / qulf ustida — MainActivity (Flutter) ochiladi va jonli
    // ekranni ("Ota-onangiz tinglamoqda") ko'rsatadi.
    val openIntent = Intent(ctx, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        putExtra("listen_session_id", sessionId)
    }
    val openPending = PendingIntent.getActivity(ctx, 4, openIntent, piFlags)

    return NotificationCompat.Builder(ctx, ListenService.CHANNEL_ID)
        .setContentTitle("Ota-onangiz tinglamoqda")
        .setContentText("Atrofdagi ovoz jonli eshitilmoqda. To'xtatish uchun bosing.")
        .setSmallIcon(R.drawable.ic_stat_parvoz)
        .setColor(0xFF216BFF.toInt())
        .setPriority(NotificationCompat.PRIORITY_MAX)
        .setCategory(NotificationCompat.CATEGORY_CALL)
        .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        .setOngoing(true)
        .setFullScreenIntent(openPending, true)
        .setContentIntent(openPending)
        .addAction(
            android.R.drawable.ic_menu_close_clear_cancel,
            "To'xtatish",
            stopPending,
        )
        .build()
}
