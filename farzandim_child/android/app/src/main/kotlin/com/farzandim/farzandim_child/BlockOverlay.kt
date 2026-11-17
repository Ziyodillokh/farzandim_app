package com.farzandim.farzandim_child

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager

/** Ko'rsatilishi kerak bo'lgan blok overlay (poll oqimi → main oqim). */
internal data class OverlayRequest(
    val pkg: String,
    val reason: String,
    /** Faqat '*' (hammasini blokla) tufayli — audio fokus olinmaydi. */
    val wildcard: Boolean,
    /** Maktab bloki tugash vaqti ("HH:MM") yoki bo'sh. */
    val schoolUntil: String,
)

/**
 * Blok overlay oynasi — FAQAT main oqimdan ishlatiladi (WindowManager).
 *
 *  - Kerakli overlay allaqachon ko'rinib tursa hech narsa qilinmaydi; paket,
 *    sabab, orientatsiya yoki tugash vaqti o'zgarsa qayta quriladi; tizim
 *    oynani olib tashlagan bo'lsa (masalan ruxsat qaytarib olindi) qayta
 *    qo'shiladi.
 *  - Settings.canDrawOverlays 30 s keshlanadi (yangi paket va ekran yonishida
 *    qayta tekshiriladi); addView xatosidan keyin paket bo'yicha 1 s → 5 s →
 *    30 s kutiladi, log — sessiyada bir marta (bat-native-overlay-retry-loop).
 *  - '*' bo'lmagan blok birinchi ko'rsatilganda AUDIOFOCUS_GAIN olinadi —
 *    bloklangan video/musiqa to'xtaydi; overlay yopilganda qaytariladi
 *    (fn-blocked-app-keeps-playing).
 */
internal class BlockOverlay(
    private val service: Service,
    texts: NativeTexts,
    private val unlockWatch: UnlockWatch,
    private val dismissLatch: DismissLatch,
) {
    companion object {
        private const val TAG = "BlockOverlay"
        private const val PERMISSION_CACHE_MS = 30_000L
        private val RETRY_BACKOFF_MS = longArrayOf(1_000L, 5_000L, 30_000L)
        private const val REQ_HOME = 4250
        private const val REQ_UNLOCK = 4251
    }

    private val windowManager = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val audioManager = service.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
    private val viewFactory = BlockOverlayView(service, texts)

    private var view: View? = null
    private var shown: OverlayRequest? = null
    private var shownOrientation = Configuration.ORIENTATION_UNDEFINED

    private var canDraw = false
    private var canDrawCheckedAt = 0L
    private var sessionPkg: String? = null
    private var permissionLogged = false
    private var failureCount = 0
    private var retryAt = 0L

    private var focusRequest: AudioFocusRequest? = null

    // Tizim oynani o'zi olib tashlasa (masalan overlay ruxsati qaytarib
    // olindi) — keyingi so'rovda qayta qo'shiladi. O'zimiz olib tashlaganda
    // `view` avval null qilinadi, shuning uchun bu yerda hech narsa bo'lmaydi.
    private val detachListener = object : View.OnAttachStateChangeListener {
        override fun onViewAttachedToWindow(v: View) = Unit

        override fun onViewDetachedFromWindow(v: View) {
            if (v !== view) return
            view = null
            shown = null
        }
    }

    /** null — overlay yopilsin. */
    fun apply(request: OverlayRequest?) {
        if (request == null) hide() else ensure(request)
    }

    /** Ruxsat keshini bekor qiladi (ekran yonganda). */
    fun invalidatePermission() {
        canDrawCheckedAt = 0L
    }

    fun hide() {
        removeView()
        shown = null
        shownOrientation = Configuration.ORIENTATION_UNDEFINED
        abandonAudioFocus()
    }

    private fun ensure(request: OverlayRequest) {
        val orientation = service.resources.configuration.orientation
        if (view != null && shown == request && shownOrientation == orientation) return

        val now = SystemClock.elapsedRealtime()
        if (sessionPkg != request.pkg) {
            // Yangi foreground sessiya: ruxsat qayta tekshiriladi, backoff/log yangidan.
            sessionPkg = request.pkg
            permissionLogged = false
            failureCount = 0
            retryAt = 0L
            invalidatePermission()
        }
        if (!canDrawOverlays(now)) {
            if (!permissionLogged) {
                Log.w(TAG, "SYSTEM_ALERT_WINDOW ruxsati yo'q — overlay ko'rsatilmadi")
                permissionLogged = true
            }
            return
        }
        if (now < retryAt) return

        val previousPkg = shown?.pkg
        val newView = viewFactory.build(
            request,
            onOk = ::onOk,
            onRequestAccess = { onRequestAccess(request.pkg) },
        )
        removeView()
        try {
            windowManager.addView(newView, layoutParams())
            newView.addOnAttachStateChangeListener(detachListener)
            view = newView
            shown = request
            shownOrientation = orientation
            failureCount = 0
            retryAt = 0L
            Log.d(TAG, "Overlay ko'rsatildi: ${request.pkg} (reason=${request.reason})")
            if (request.wildcard) {
                abandonAudioFocus()
            } else if (previousPkg != request.pkg) {
                requestAudioFocus()
            }
        } catch (e: Exception) {
            shown = null
            failureCount++
            retryAt = now + RETRY_BACKOFF_MS[minOf(failureCount, RETRY_BACKOFF_MS.size) - 1]
            if (failureCount == 1) Log.e(TAG, "Overlay qo'shishda xato: ${request.pkg}", e)
        }
    }

    private fun canDrawOverlays(now: Long): Boolean {
        if (canDrawCheckedAt == 0L || now - canDrawCheckedAt >= PERMISSION_CACHE_MS) {
            canDraw = try {
                Settings.canDrawOverlays(service)
            } catch (e: Exception) {
                false
            }
            canDrawCheckedAt = now
        }
        return canDraw
    }

    private fun removeView() {
        val current = view ?: return
        view = null
        try {
            windowManager.removeView(current)
        } catch (e: Exception) {
            // Tizim allaqachon olib tashlagan — muammo emas.
            Log.w(TAG, "Overlay olib tashlashda xato: ${e.message}")
        }
    }

    @Suppress("DEPRECATION") // FLAG_SHOW_WHEN_LOCKED — oyna (activity emas) uchun yagona yo'l.
    private fun layoutParams() = WindowManager.LayoutParams(
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            // Bloklangan ilova qulf ekranini "occlude" qilsa (showWhenLocked
            // o'yin/ilova) overlay ustida qolsin: AOSP DisplayPolicy activity
            // bo'lmagan oynani keyguard paytida shu bayroqsiz yashiradi.
            // Oddiy qulf ekranida overlay baribir ko'rinmaydi — kerakli xulq.
            // (Qo'ng'iroq ekrani esa endi umuman bloklanmaydi — TelephonyGuard.)
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED,
        PixelFormat.OPAQUE,
    ).apply { gravity = Gravity.CENTER }

    // ───────────────────────── Tugmalar ─────────────────────────

    /** OK — HOME (bola bloklangan ilovadan chiqadi), keyin overlay yopiladi. */
    private fun onOk() {
        val home = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        OverlayLauncher.start(service, home, REQ_HOME)
        shown?.let { dismissLatch.dismissed(it.pkg) }
        hide()
    }

    /**
     * "Ruxsat so'rash" — Parvoz unlock modali bilan ochiladi. MIUI jim rad
     * etsa [UnlockWatch] bir necha soniyadan keyin bildirishnoma zaxirasini
     * ishga tushiradi. Overlay har holda yopiladi (ilova hali bloklangan
     * bo'lsa keyingi tick qaytaradi).
     */
    private fun onRequestAccess(pkg: String) {
        val open = Intent(service, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(BlockNotifications.EXTRA_UNLOCK_PACKAGE, pkg)
        }
        OverlayLauncher.start(service, open, REQ_UNLOCK)
        unlockWatch.started(pkg, SystemClock.elapsedRealtime())
        dismissLatch.dismissed(pkg)
        hide()
    }

    // ───────────────────────── Audio fokus ─────────────────────────

    private fun requestAudioFocus() {
        val am = audioManager ?: return
        abandonAudioFocus()
        try {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                .build()
            if (am.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                focusRequest = request
            }
        } catch (e: Exception) {
            Log.w(TAG, "Audio fokus olinmadi: ${e.message}")
        }
    }

    private fun abandonAudioFocus() {
        val request = focusRequest ?: return
        focusRequest = null
        try {
            audioManager?.abandonAudioFocusRequest(request)
        } catch (e: Exception) {
            Log.w(TAG, "Audio fokus qaytarilmadi: ${e.message}")
        }
    }
}
