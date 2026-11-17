package com.farzandim.farzandim_child

/**
 * Bola overlay'ni tugma bilan yopdi ("OK" yoki "Ruxsat so'rash") — shu paket
 * uchun overlay qisqa vaqt qayta chizilmaydi (sof Kotlin, JVM testlanadi).
 *
 * Sabab: tugma bosilgach HOME yoki Parvoz ochiladi, lekin poll keyingi
 * RESUMED hodisasini ko'rguncha (~1 s, Parvoz sovuq startida ko'proq)
 * foreground hali bloklangan ilova bo'lib turadi. Qulfsiz keyingi tick
 * overlay'ni HOME yoki unlock modalining ustiga qayta qo'yardi (miltillash).
 * Qulf foreground boshqa paketga o'tsa yoki [HOLD_MS] tugasa yechiladi —
 * HOME ochilmay qolsa (MIUI) overlay qaytadi, ilova hali bloklangan.
 *
 * Main oqim yozadi, poll oqimi o'qiydi.
 */
internal class DismissLatch(private val now: () -> Long) {

    companion object {
        const val HOLD_MS = 2_500L
    }

    @Volatile private var pkg: String? = null
    @Volatile private var until = 0L

    /** Tugma bosildi — [dismissedPkg] uchun qulf. */
    fun dismissed(dismissedPkg: String) {
        until = now() + HOLD_MS
        pkg = dismissedPkg
    }

    /** true — [foreground] hali yopilgan paket va muddat tugamagan: overlay qo'yilmasin. */
    fun holds(foreground: String?): Boolean {
        val held = pkg ?: return false
        if (foreground != held || now() >= until) {
            pkg = null
            return false
        }
        return true
    }
}
