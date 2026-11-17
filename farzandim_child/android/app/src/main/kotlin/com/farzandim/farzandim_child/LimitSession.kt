package com.farzandim.farzandim_child

/**
 * Kunlik limit uchun foydalanishni EKSTRAPOLYATSIYA qiladi (Android'siz —
 * JVM testlanadi).
 *
 * Avval limitli ilova ochiq turganda HAR SONIYADA kun boshidan barcha
 * hodisalar qayta so'ralardi (main thread'da, limit overlay ko'rinib
 * turganda ham) — bat-native-limit-fullday-query / perf-usage-full-day-scan.
 * Endi:
 *  - limitli ilovaga kirilganda BITTA to'liq hisob (poll oqimida);
 *  - keyin taxmin = asos + (elapsedRealtime − asos vaqti) — ilova shu vaqt
 *    davomida foreground (foreground almashsa / ekran o'chsa sessiya
 *    [reset] qilinadi);
 *  - qayta hisob: eng ko'pi har 5 daqiqada yoki taxmin limitga 2 s qolganda
 *    (bloklashdan oldin tasdiqlash — kechikish ~1 s bo'lib qoladi);
 *  - limit oshgan (overlay ko'rinib turgan) holatda so'rov YO'Q — paket,
 *    limit yoki kun o'zgarmaguncha.
 *
 * Faqat poll oqimidan ishlatiladi.
 */
class LimitSession {

    companion object {
        const val REBASE_INTERVAL_MS = 5 * 60 * 1000L
        const val CONFIRM_MARGIN_MS = 2_000L
    }

    private var pkg: String? = null
    private var limitMs = 0L
    private var day = Long.MIN_VALUE
    private var baseUsageMs = 0L
    private var baseAtElapsed = 0L

    var exceeded = false
        private set

    fun reset() {
        pkg = null
        exceeded = false
    }

    /**
     * Joriy taxminiy bugungi foydalanish (ms) yoki null — to'liq hisob kerak
     * (yangi paket/limit/kun, 5 daqiqa o'tdi yoki limitga 2 s qoldi).
     */
    fun estimate(pkg: String, limitMs: Long, day: Long, nowElapsed: Long): Long? {
        if (pkg != this.pkg || limitMs != this.limitMs || day != this.day) return null
        if (exceeded) return baseUsageMs
        val since = nowElapsed - baseAtElapsed
        if (since < 0L || since >= REBASE_INTERVAL_MS) return null
        val estimated = baseUsageMs + since
        return if (estimated >= limitMs - CONFIRM_MARGIN_MS) null else estimated
    }

    /** To'liq hisob natijasi bilan yangi asos. */
    fun rebase(pkg: String, limitMs: Long, day: Long, usageMs: Long, nowElapsed: Long) {
        this.pkg = pkg
        this.limitMs = limitMs
        this.day = day
        baseUsageMs = usageMs
        baseAtElapsed = nowElapsed
        exceeded = usageMs >= limitMs
    }
}

/**
 * "Vaqting tugayapti" ogohlantirishi qoidalari (fn-minor-enforcement-edges):
 * limitga min(10 daqiqa, limit/2) qolganda, HAQIQIY qolgan daqiqa bilan.
 * (Avval 10 daqiqalik yoki undan kichik limitda ilova ochilishi bilan "~10
 * daqiqa qoldi" chiqardi.)
 */
object LimitWarningRules {
    const val MAX_WARNING_MS = 10 * 60 * 1000L
    private const val MINUTE_MS = 60_000L

    fun thresholdMs(limitMs: Long): Long = minOf(MAX_WARNING_MS, limitMs / 2)

    /** Qolgan daqiqalar (yuqoriga yaxlitlangan, kamida 1). */
    fun remainingMinutes(remainingMs: Long): Long =
        maxOf(1L, (remainingMs + MINUTE_MS - 1) / MINUTE_MS)

    /**
     * Tarjima shabloniga ilova nomi va daqiqani qo'yadi. Yangi tarjimada
     * `{min}` bo'ladi; eski (keshlangan) tarjimalarda "~10" literal — undagi
     * birinchi "10" haqiqiy daqiqaga almashtiriladi (nom qo'yilishidan OLDIN,
     * nomdagi raqamlar buzilmasin).
     */
    fun formatBody(template: String, label: String, minutes: Long): String {
        val withMinutes = when {
            template.contains("{min}") -> template.replace("{min}", minutes.toString())
            minutes == 10L -> template
            else -> template.replaceFirst("10", minutes.toString())
        }
        return withMinutes.replace("{label}", label)
    }
}
