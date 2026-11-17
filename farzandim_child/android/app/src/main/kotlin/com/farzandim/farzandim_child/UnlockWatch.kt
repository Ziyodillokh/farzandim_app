package com.farzandim.farzandim_child

/**
 * "Ruxsat so'rash" bosilgach Parvoz haqiqatan ochildimi — kuzatadi (sof
 * Kotlin, JVM testlanadi).
 *
 * MIUI/HyperOS "fonda oyna ochish" ruxsatisiz activity start'ni JIMGINA
 * bloklaydi (fn-overlay-buttons-miui-bg-start). Parvoz [OPEN_TIMEOUT_MS]
 * ichida foreground'ga chiqmasa — servis bosiladigan bildirishnoma
 * ko'rsatadi (bildirishnoma bosilishi har doim activity ocha oladi).
 *
 * Overlay tugmasi (main oqim) va poll oqimi ishlatadi — sinxronlangan.
 */
class UnlockWatch {

    companion object {
        const val OPEN_TIMEOUT_MS = 3_000L

        /** Juda eski so'rov (masalan ekran o'chib qolgan) — jim tashlanadi. */
        const val EXPIRY_MS = 15_000L
    }

    private var pkg: String? = null
    private var startedAt = 0L

    @Synchronized
    fun started(pkg: String, nowElapsed: Long) {
        this.pkg = pkg
        startedAt = nowElapsed
    }

    /** Parvoz o'z vaqtida ochilmadi — zaxira bildirishnoma uchun paket (bir marta). */
    @Synchronized
    fun check(foreground: String?, ownPackage: String, nowElapsed: Long): String? {
        val target = pkg ?: return null
        val since = nowElapsed - startedAt
        if (foreground == ownPackage || since > EXPIRY_MS || since < 0L) {
            pkg = null
            return null
        }
        if (since < OPEN_TIMEOUT_MS) return null
        pkg = null
        return target
    }
}
