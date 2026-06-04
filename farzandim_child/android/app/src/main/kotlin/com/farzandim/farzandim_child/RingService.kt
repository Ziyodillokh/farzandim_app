package com.farzandim.farzandim_child

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * RingService — bola qurilmasini BALAND ovozda jiringlatadi (qurilmani topish).
 *
 * Ota-ona "Baland ovoz" tugmasini bossa, backend FCM data push yuboradi;
 * [FarzandimMessagingService] uni ushlab shu xizmatni ishga tushiradi.
 *
 * MUHIM: silent / vibratsiya rejimida ham eshitilishi uchun ringtone
 * STREAM_ALARM (USAGE_ALARM) orqali ijro etiladi va alarm ovozi vaqtincha
 * maksimal qilinadi. Avvalgi alarm ovozi SharedPreferences'ga saqlanadi va
 * to'xtaganda tiklanadi (xizmat halok bo'lsa ham keyingi ishga tushishda
 * tiklanadi).
 */
class RingService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())
    private val stopRunnable = Runnable { stopSelf() }

    companion object {
        private const val TAG = "RingService"
        const val CHANNEL_ID = "farzandim_child_ring"
        const val NOTIFICATION_ID = 7711
        const val ACTION_START = "com.farzandim.farzandim_child.RING_START"
        const val ACTION_STOP = "com.farzandim.farzandim_child.RING_STOP"
        const val EXTRA_DURATION = "durationMs"
        private const val PREFS = "ring_prefs"
        private const val KEY_PREV_VOL = "prev_alarm_vol"
        private const val MAX_DURATION_MS = 120_000L
        private const val MIN_DURATION_MS = 3_000L

        fun start(ctx: Context, durationMs: Long) {
            val i = Intent(ctx, RingService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_DURATION, durationMs)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(i)
            } else {
                ctx.startService(i)
            }
        }

        fun stop(ctx: Context) {
            ctx.startService(
                Intent(ctx, RingService::class.java).apply { action = ACTION_STOP },
            )
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        // Crash-safety: agar avvalgi ring alarm ovozini tiklamasdan halok bo'lgan
        // bo'lsa, hozir tiklaymiz.
        restoreAlarmVolumeIfPending()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        val duration = (intent?.getLongExtra(EXTRA_DURATION, 30_000L) ?: 30_000L)
            .coerceIn(MIN_DURATION_MS, MAX_DURATION_MS)

        startAsForeground()
        startRinging()

        handler.removeCallbacks(stopRunnable)
        handler.postDelayed(stopRunnable, duration)
        return START_NOT_STICKY
    }

    private fun startAsForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startRinging() {
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            // Joriy alarm ovozini saqlaymiz (crash-safety uchun diskka ham) va
            // maksimal qilamiz — silent/vibratsiyada ham eshitiladi.
            val prev = am.getStreamVolume(AudioManager.STREAM_ALARM)
            getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putInt(KEY_PREV_VOL, prev).apply()
            am.setStreamVolume(
                AudioManager.STREAM_ALARM,
                am.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                0,
            )

            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            mediaPlayer = MediaPlayer().apply {
                setDataSource(this@RingService, uri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                isLooping = true
                prepare()
                start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "startRinging error", e)
        }

        // Vibratsiya (cheksiz takror, to'xtatilguncha). minSdk 28 → VibrationEffect
        // har doim mavjud. getSystemService(VIBRATOR_SERVICE) API 31+'da deprecated,
        // lekin minSdk 28 uchun to'g'ri ishlaydi (val deklaratsiyada suppress).
        try {
            @Suppress("DEPRECATION")
            val vib = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            vibrator = vib
            vib?.vibrate(
                VibrationEffect.createWaveform(longArrayOf(0, 800, 400), 0),
            )
        } catch (e: Exception) {
            Log.e(TAG, "vibrate error", e)
        }

        // WakeLock — ekran o'chiq bo'lsa ham jiringlashni ta'minlaydi.
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "farzandim:ring",
            ).apply { acquire(MAX_DURATION_MS + 10_000L) }
        } catch (e: Exception) {
            Log.e(TAG, "wakelock error", e)
        }
    }

    private fun stopRinging() {
        handler.removeCallbacks(stopRunnable)
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {
        }
        try {
            mediaPlayer?.release()
        } catch (_: Exception) {
        }
        mediaPlayer = null
        try {
            vibrator?.cancel()
        } catch (_: Exception) {
        }
        vibrator = null
        restoreAlarmVolumeIfPending()
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
        }
        wakeLock = null
    }

    private fun restoreAlarmVolumeIfPending() {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val saved = prefs.getInt(KEY_PREV_VOL, -1)
        if (saved >= 0) {
            try {
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                am.setStreamVolume(AudioManager.STREAM_ALARM, saved, 0)
            } catch (e: Exception) {
                Log.e(TAG, "restore volume error", e)
            }
            prefs.edit().remove(KEY_PREV_VOL).apply()
        }
    }

    override fun onDestroy() {
        stopRinging()
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, RingService::class.java).apply {
            action = ACTION_STOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val stopPending = PendingIntent.getService(this, 1, stopIntent, flags)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Farzandim")
            .setContentText("Qurilma chaqirilmoqda")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "To'xtatish",
                stopPending,
            )
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Qurilmani chaqirish",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Ota-ona qurilmani chaqirganda jiringlaydi"
                    // Ovozni MediaPlayer (STREAM_ALARM) chiqaradi — kanal jim.
                    setSound(null, null)
                    setShowBadge(false)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }
}
