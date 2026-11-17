package com.farzandim.farzandim_child

/**
 * Hozirgi foreground ilovani INKREMENTAL aniqlaydi (Android'siz — JVM testlanadi).
 *
 * Avval har 1 s da oxirgi 60 s hodisalari qayta so'ralardi va servis qayta
 * ishga tushgach (OEM/LMK o'ldirgan, watchdog) "sticky" qiymat bo'sh edi —
 * bloklangan o'yinda o'tirgan bola ilovani almashtirmaguncha bloklanmasdi
 * (bat-native-restart-foreground-blind). Endi:
 *  - Holat noma'lum (servis start) — bir marta "seed": hozir − 3 soatdan
 *    hozirgacha hodisalar holat mashinasidan o'tkaziladi (Toshkent kun
 *    boshi bilan QIRQILMAYDI — foreground hisob emas: 23:30 dan beri
 *    o'yinda o'tirgan bola 00:30 dagi qayta startdan keyin ham topiladi).
 *    Seed hech narsa topmasa, keyingi tick bir marta 12 soatlik oynani
 *    o'qiydi (uzoq ochiq turgan ilova). Qayta ishga tushgandan ~1-2 s
 *    ichida blok tiklanadi.
 *  - Keyingi tick'lar faqat [oxirgi so'rov oxiri − 2 s, hozir] oynasini
 *    so'raydi (kech yozilgan hodisalar uchun 2 s ustma-ust). Holat mashinasi
 *    qayta o'ynashga chidamli: ustma-ust hodisalar natijani o'zgartirmaydi.
 *  - Ekran o'chsa foreground tozalanadi; keyingi so'rov o'sha lahzadan davom
 *    etadi (ekran yonganda oyna shu yerdan boshlanadi — 3 soatlik seed shart
 *    emas, natija bir xil).
 *
 * Foreground = oxirgi RESUMED paketi (ekran o'chguncha). Bu avvalgi "sticky"
 * xulq bilan bir xil: bir ilova ichidagi PAUSED(A) → RESUMED(B) oralig'ida
 * overlay miltillamaydi.
 */
class ForegroundTracker : UsageEventSink {

    companion object {
        const val SEED_LOOKBACK_MS = 3 * 60 * 60 * 1000L
        const val WIDE_SEED_LOOKBACK_MS = 12 * 60 * 60 * 1000L
        const val OVERLAP_MS = 2_000L
    }

    /** Birinchi seed foreground topmadi — keyingi so'rov bir marta keng oyna oladi. */
    private var wideSeedPending = false

    private val machine = ActivitySessionMachine()

    /** Oxirgi so'rov oxiri (qurilma soati, ms); 0 — holat noma'lum (seed kerak). */
    var lastQueryEnd: Long = 0L
        private set

    val foreground: String? get() = machine.currentPackage

    val needsSeed: Boolean get() = lastQueryEnd <= 0L

    /**
     * Keyingi so'rov oynasi boshi. [dayStartWall] (Toshkent 00:00) foreground
     * uchun ishlatilmaydi — faqat API mosligi uchun qoldirilgan.
     */
    @Suppress("UNUSED_PARAMETER")
    fun windowStart(nowWall: Long, dayStartWall: Long): Long =
        when {
            needsSeed -> nowWall - SEED_LOOKBACK_MS
            wideSeedPending -> nowWall - WIDE_SEED_LOOKBACK_MS
            else -> maxOf(lastQueryEnd - OVERLAP_MS, nowWall - SEED_LOOKBACK_MS)
        }

    override fun onEvent(type: Int, pkg: String?, cls: String?, timeMs: Long) {
        machine.onEvent(type, pkg, cls, timeMs)
    }

    /** So'rov muvaffaqiyatli o'qildi — keyingisi shu yerdan davom etadi. */
    fun commit(queryEndWall: Long) {
        val wasSeed = needsSeed
        lastQueryEnd = queryEndWall
        // Seed bo'sh chiqdi — bir marta kengroq qidiriladi; keng so'rovdan keyin yana oddiy oyna.
        wideSeedPending = wasSeed && machine.currentPackage == null
    }

    /** Ekran o'chdi: foreground yo'q, keyingi so'rov shu lahzadan. */
    fun onScreenOff(nowWall: Long) {
        machine.clear(nowWall)
        wideSeedPending = false
        if (!needsSeed) lastQueryEnd = nowWall
    }
}
