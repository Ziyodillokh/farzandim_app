package com.farzandim.farzandim_child

/** UsageEvents hodisasini qabul qiluvchi (Android'siz — JVM testlanadi). */
interface UsageEventSink {
    fun onEvent(type: Int, pkg: String?, cls: String?, timeMs: Long)
}

/** Yopilgan foreground sessiya haqida xabar. */
fun interface SessionListener {
    fun onSessionClosed(pkg: String, startMs: Long, endMs: Long)
}

/**
 * `android.app.usage.UsageEvents.Event` konstantalari (ommaviy, barqaror API).
 * Bu yerda nusxalangan — sof Kotlin sinflar Android'ga bog'lanmasin.
 */
object UsageEventTypes {
    /** API 28 da MOVE_TO_FOREGROUND — qiymati bir xil. */
    const val ACTIVITY_RESUMED = 1

    /** API 28 da MOVE_TO_BACKGROUND — qiymati bir xil. */
    const val ACTIVITY_PAUSED = 2
    const val SCREEN_INTERACTIVE = 15
    const val SCREEN_NON_INTERACTIVE = 16
    const val KEYGUARD_SHOWN = 17
    const val KEYGUARD_HIDDEN = 18
    const val ACTIVITY_STOPPED = 23
    const val DEVICE_SHUTDOWN = 26
    const val DEVICE_STARTUP = 27
}

/**
 * Yagona foreground sessiya holat mashinasi — limit (RestrictionService) va
 * ota-ona hisoboti (UsageStatsPlugin) BIR XIL hisoblasin
 * (fn-usage-stopped-event-undercount).
 *
 * Qoidalar:
 *  - Bir vaqtda faqat BITTA ilova foreground. Boshqa paketning
 *    ACTIVITY_RESUMED'i oldingisining sessiyasini yopadi ("21 soat" orphan
 *    RESUMED xatosi qaytmasin).
 *  - Paket ichida resume bo'lgan activity klasslari to'plami yuritiladi.
 *    Sessiya to'plam bo'sh bo'lmaguncha ochiq. PAUSED shu klassni olib
 *    tashlaydi.
 *  - ACTIVITY_STOPPED odatda e'tiborsiz: Android 10+ da ilova ichidagi o'tish
 *    PAUSED(A) → RESUMED(B) → STOPPED(A) ketma-ketligida keladi — avvalgi kod
 *    STOPPED(A) bilan B sessiyasini yopib, splash'li ilovalarda vaqtni
 *    yo'qotardi. STOPPED faqat shu klass uchun PAUSED umuman yozilmagan
 *    bo'lsa (ba'zi OEM) pauza o'rnida ishlatiladi; bir klassning yangi nusxasi
 *    (PAUSED(A#1) → RESUMED(A#2) → STOPPED(A#1)) sessiyani yopmaydi.
 *  - SCREEN_NON_INTERACTIVE / KEYGUARD_SHOWN / DEVICE_SHUTDOWN — sessiya
 *    yopiladi, foreground yo'q. Keyingi haqiqiy RESUMED kutiladi.
 *  - DEVICE_STARTUP (shutdown yozilmagan bo'lsa) — o'chiq vaqt hisoblanmaydi:
 *    sessiya oxirgi ma'lum hodisada yopiladi.
 */
class ActivitySessionMachine(
    private val listener: SessionListener? = null,
) : UsageEventSink {

    companion object {
        const val NO_SESSION = -1L
    }

    /** Oxirgi RESUMED paketi (ekran o'chgach — null). */
    var currentPackage: String? = null
        private set

    /** Ochiq sessiya boshlanishi yoki [NO_SESSION]. */
    var sessionStart: Long = NO_SESSION
        private set

    val isSessionOpen: Boolean get() = sessionStart != NO_SESSION

    private val resumed = HashSet<String>()
    private val pausedPending = HashMap<String, Int>()
    private var lastEventAt = Long.MIN_VALUE

    override fun onEvent(type: Int, pkg: String?, cls: String?, timeMs: Long) {
        val previousAt = lastEventAt
        if (timeMs > lastEventAt) lastEventAt = timeMs
        val klass = cls.orEmpty()
        when (type) {
            UsageEventTypes.ACTIVITY_RESUMED -> if (pkg != null) onResumed(pkg, klass, timeMs)
            UsageEventTypes.ACTIVITY_PAUSED -> onPaused(pkg, klass, timeMs)
            UsageEventTypes.ACTIVITY_STOPPED -> onStopped(pkg, klass, timeMs)
            UsageEventTypes.SCREEN_NON_INTERACTIVE,
            UsageEventTypes.KEYGUARD_SHOWN,
            UsageEventTypes.DEVICE_SHUTDOWN,
            -> clear(timeMs)
            UsageEventTypes.DEVICE_STARTUP -> {
                val closeAt = if (previousAt == Long.MIN_VALUE) timeMs else minOf(previousAt, timeMs)
                clear(closeAt)
            }
            // SCREEN_INTERACTIVE / KEYGUARD_HIDDEN: sessiya ochilmaydi —
            // keyingi haqiqiy ACTIVITY_RESUMED kutiladi.
        }
    }

    private fun onResumed(pkg: String, cls: String, timeMs: Long) {
        if (pkg != currentPackage) {
            closeSession(timeMs)
            currentPackage = pkg
            resumed.clear()
            pausedPending.clear()
        }
        resumed.add(cls)
        if (sessionStart == NO_SESSION) sessionStart = timeMs
    }

    private fun onPaused(pkg: String?, cls: String, timeMs: Long) {
        if (pkg == null || pkg != currentPackage) return
        if (!resumed.remove(cls)) return
        pausedPending[cls] = (pausedPending[cls] ?: 0) + 1
        if (resumed.isEmpty()) closeSession(timeMs)
    }

    private fun onStopped(pkg: String?, cls: String, timeMs: Long) {
        if (pkg == null || pkg != currentPackage) return
        val pending = pausedPending[cls] ?: 0
        if (pending > 0) {
            // Oddiy oqim: PAUSED allaqachon hisobga olingan.
            if (pending == 1) pausedPending.remove(cls) else pausedPending[cls] = pending - 1
            return
        }
        // PAUSED yozilmagan (OEM) — STOPPED pauza o'rnida.
        if (resumed.remove(cls) && resumed.isEmpty()) closeSession(timeMs)
    }

    /** Ekran o'chdi / qulf / o'chirish — hech qaysi ilova foreground emas. */
    fun clear(timeMs: Long) {
        closeSession(timeMs)
        currentPackage = null
        resumed.clear()
        pausedPending.clear()
    }

    /** Ochiq sessiyani [timeMs] da yopadi (foreground paketi saqlanadi). */
    fun closeSession(timeMs: Long) {
        val pkg = currentPackage
        val start = sessionStart
        sessionStart = NO_SESSION
        if (pkg != null && start != NO_SESSION && timeMs > start) {
            listener?.onSessionClosed(pkg, start, timeMs)
        }
    }
}

/**
 * Paketlar bo'yicha EKRANDA faol foreground vaqtini yig'adi.
 *
 * [windowStart] — hisob oynasi boshi (masalan Toshkent 00:00). Hodisalar
 * undan OLDINROQ (masalan 1 soat) so'raladi: yarim tundan oldin ochilib
 * davom etayotgan sessiya ham to'g'ri hisoblansin — vaqt [windowStart]
 * bo'yicha kesiladi.
 */
class UsageAccumulator(private val windowStart: Long) : UsageEventSink, SessionListener {

    private val machine = ActivitySessionMachine(this)
    private val totalsMs = HashMap<String, Long>()
    private val lastUsedMs = HashMap<String, Long>()

    override fun onEvent(type: Int, pkg: String?, cls: String?, timeMs: Long) {
        machine.onEvent(type, pkg, cls, timeMs)
    }

    override fun onSessionClosed(pkg: String, startMs: Long, endMs: Long) {
        val from = maxOf(startMs, windowStart)
        if (endMs <= from) return
        totalsMs[pkg] = (totalsMs[pkg] ?: 0L) + (endMs - from)
        lastUsedMs[pkg] = endMs
    }

    /** Hali ochiq sessiyani [nowMs] gacha hisoblab, natijani qaytaradi. */
    fun finish(nowMs: Long): Map<String, Long> {
        machine.closeSession(nowMs)
        return totalsMs
    }

    /** Yopilgan sessiyalar yig'indisi (ochiq sessiya — [finish] dan keyin). */
    val totals: Map<String, Long> get() = totalsMs

    fun totalMs(pkg: String): Long = totalsMs[pkg] ?: 0L

    fun lastUsed(pkg: String): Long? = lastUsedMs[pkg]
}
