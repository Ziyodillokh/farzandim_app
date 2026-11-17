package com.farzandim.farzandim_child

/**
 * Foreground ilova uchun bloklash QARORI — sof funksiya (JVM testlanadi).
 *
 * Tartib (shartnoma):
 *  1. Doim ruxsat: o'zimiz, Sozlamalar, launcher, klaviatura, tizim UI,
 *     telefon/qo'ng'iroq ilovalari ('*' ham bosh ekranni va qo'ng'iroqni
 *     yopmasin — fn-wildcard-blocks-calls).
 *  2. Maktab bloki (dars vaqti) — ota-ona ruxsati uni HECH QACHON ochmaydi.
 *  3. Ota-ona ruxsati (grant) — '*', jadval/to'liq blok, limit va notanish
 *     manba tekshiruvlaridan OLDIN (fn-grant-ineffective).
 *  4. '*' va to'liq bloklar.
 *  5. Kunlik limit.
 *  6. Notanish manba.
 */
object EnforcementRules {

    const val REASON_BLOCKED = "blocked"
    const val REASON_LIMIT = "limit"
    const val REASON_SCHOOL = "school"

    /** Notanish manba — overlay matni [REASON_BLOCKED] bilan bir xil. */
    const val REASON_UNKNOWN_SOURCE = "unknown"

    /** Qaror uchun kerakli (qimmatroq) ma'lumotlar — servis keshlar bilan beradi. */
    interface Lookup {
        fun isAlwaysAllowed(pkg: String): Boolean

        /** "GAME" / "SOCIAL" / "VIDEO" yoki null. */
        fun schoolCategoryOf(pkg: String): String?

        fun appLabelKey(pkg: String): String

        /** Limitga yetganmi (ogohlantirish ham shu yerda). */
        fun isLimitExceeded(pkg: String, limitMinutes: Int): Boolean

        fun isUnknownSource(pkg: String): Boolean
    }

    /** null [reason] — ruxsat. [wildcard] — faqat '*' tufayli bloklangan. */
    data class Verdict(val reason: String?, val wildcard: Boolean = false) {
        val isBlock: Boolean get() = reason != null
    }

    val ALLOW = Verdict(null)

    fun decide(pkg: String, snap: EnforcementSnapshot, now: Long, lookup: Lookup): Verdict {
        if (lookup.isAlwaysAllowed(pkg)) return ALLOW

        val school = snap.activeSchool(now)
        if (school != null) {
            if (pkg in school.packages) return Verdict(REASON_SCHOOL)
            // Server ro'yxatiga hali tushmagan ilova (masalan bugun
            // o'rnatilgan o'yin) — qurilma toifasi bo'yicha; maktab ruxsat
            // bergan ilova (nomi bo'yicha) o'tkaziladi.
            if (school.categories.isNotEmpty()) {
                val category = lookup.schoolCategoryOf(pkg)
                if (category != null && category in school.categories &&
                    lookup.appLabelKey(pkg) !in school.allowed
                ) {
                    return Verdict(REASON_SCHOOL)
                }
            }
        }

        if (snap.hasGrant(pkg, now)) return ALLOW

        val blocked = snap.effectiveBlocked(now)
        if (pkg in blocked) return Verdict(REASON_BLOCKED)
        if (EnforcementSnapshot.WILDCARD in blocked) return Verdict(REASON_BLOCKED, wildcard = true)

        val limitMinutes = snap.limits[pkg]
        if (limitMinutes != null && limitMinutes > 0 && lookup.isLimitExceeded(pkg, limitMinutes)) {
            return Verdict(REASON_LIMIT)
        }

        if (snap.blockUnknown && lookup.isUnknownSource(pkg)) return Verdict(REASON_UNKNOWN_SOURCE)

        return ALLOW
    }
}
