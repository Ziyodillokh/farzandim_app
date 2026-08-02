package com.farzandim.farzandim_child

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent

/**
 * Bloklangan ilovaga KIRISHNI to'sadi (Play: "child_monitoring").
 *
 * ── Nima uchun kerak ──────────────────────────────────────────────────────
 * [RestrictionService] bloklangan ilovani UsageStats'ni har 1 soniyada
 * so'rab aniqlaydi va ustiga overlay qo'yadi. Ikki muammo:
 *   1. Kechikish. `queryEvents` — hodisa oqimi, holat emas; ko'p OEM (Samsung,
 *      Xiaomi) uni tejamkorlik uchun bo'g'adi. Natijada bloklangan ilova
 *      ochilgach 1-3 soniya ISHLAB turadi (qimor ilovasida bu — real pul).
 *   2. Overlay ilovani faqat YOPADI, to'xtatmaydi: orqada u ishlayveradi.
 *
 * Bu servis `TYPE_WINDOW_STATE_CHANGED` hodisasini TIZIMDAN darhol oladi
 * (~50-300 ms, so'rovsiz) va `GLOBAL_ACTION_HOME` bilan bolani ilovadan
 * DARHOL chiqarib yuboradi — u interaktiv ekrangacha yetib bormaydi.
 *
 * ── Xavfsizlik kafolatlari ────────────────────────────────────────────────
 * • Ixtiyoriy. Foydalanuvchi yoqmasa bu servis umuman ishga tushmaydi va
 *   ilova xulqi bugungidek qoladi ([RestrictionService] mustaqil ishlaydi).
 * • `canRetrieveWindowContent="false"` — ekran MAZMUNI o'qilmaydi. Faqat
 *   qaysi ilova ochilgani (paket nomi) ko'riladi.
 * • Sozlamalar/launcher/klaviatura hech qachon bloklanmaydi ([BlockPolicy]).
 * • `*` (hammasini blokla) rejimida HOME BOSILMAYDI — cheksiz sikl xavfi
 *   sababli; u holda faqat overlay ishlaydi (qarang: [BlockPolicy.decide]).
 */
class BlockAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "BlockA11y"

        /**
         * Bitta paket uchun HOME bosishlar orasidagi eng kichik oraliq.
         * Ilova yopilayotganda bir nechta window hodisasi kelishi mumkin —
         * ularning har biriga HOME bosilsa foydalanuvchi qurilmani boshqara
         * olmay qoladi.
         */
        private const val COOLDOWN_MS = 900L

        /** Servis tizimda ulanganmi (Dart tomon "ishlayaptimi" deb so'raydi). */
        @Volatile
        var isConnected: Boolean = false
            private set
    }

    private var lastPkg: String? = null
    private var lastActionAt = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        isConnected = true
        Log.d(TAG, "Accessibility servis ulandi")
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        isConnected = false
        Log.d(TAG, "Accessibility servis uzildi")
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        isConnected = false
        super.onDestroy()
    }

    override fun onInterrupt() {
        // Talab qilinadi, lekin bizga kerak emas.
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val e = event ?: return
        if (e.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val pkg = e.packageName?.toString() ?: return
        if (pkg.isBlank() || pkg == packageName) return

        // Faqat HAQIQIY ekran (Activity) — dialog/toast/notification panel
        // uchun HOME bosmaymiz (aks holda bildirishnoma shadesi ochilganda
        // ham chiqarib yuborardik).
        if (!isActivityWindow(e)) return

        val verdict = try {
            BlockPolicy.decide(this, pkg)
        } catch (t: Throwable) {
            // Accessibility callback'da istisno tizim tomonidan servisni
            // o'chirishga olib kelishi mumkin — hech qachon tashqariga chiqmasin.
            Log.e(TAG, "decide xato", t)
            return
        }

        if (verdict == BlockPolicy.Verdict.ALLOW) return

        // Takror/sikl himoyasi.
        val now = SystemClock.elapsedRealtime()
        if (pkg == lastPkg && now - lastActionAt < COOLDOWN_MS) return
        lastPkg = pkg
        lastActionAt = now

        try {
            // 1) Bolani ilovadan DARHOL chiqaramiz (asosiy ekranga).
            //    Faqat to'liq blokda — vaqt limitida overlay yetarli, chunki
            //    bola "qo'shimcha vaqt so'rash" tugmasini bosishi kerak.
            if (verdict == BlockPolicy.Verdict.BLOCK_HARD) {
                performGlobalAction(GLOBAL_ACTION_HOME)
            }

            // 2) Sababini tushuntiruvchi overlay'ni mavjud servis ko'rsatadi
            //    (yagona overlay egasi — ikki joydan qo'shilsa poyga bo'lardi).
            RestrictionService.onForegroundFromAccessibility(this, pkg)

            Log.d(TAG, "Bloklandi: $pkg ($verdict)")
        } catch (t: Throwable) {
            Log.e(TAG, "blok amali xato", t)
        }
    }

    /**
     * Hodisa haqiqiy Activity oynasidanmi.
     *
     * `TYPE_WINDOW_STATE_CHANGED` dialog, menyu va bildirishnoma panelida ham
     * keladi. `className` bo'yicha `getActivityInfo` muvaffaqiyatli bo'lsa —
     * bu Activity. Aniqlab bo'lmasa `true` qaytaramiz (bloklashni o'tkazib
     * yuborgandan ko'ra ehtiyot bo'lgan ma'qul), chunki ko'p ilovalar
     * className'ni umuman bermaydi.
     */
    private fun isActivityWindow(e: AccessibilityEvent): Boolean {
        val cls = e.className?.toString() ?: return true
        val pkg = e.packageName?.toString() ?: return true
        return try {
            packageManager.getActivityInfo(ComponentName(pkg, cls), 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        } catch (_: Exception) {
            true
        }
    }
}
