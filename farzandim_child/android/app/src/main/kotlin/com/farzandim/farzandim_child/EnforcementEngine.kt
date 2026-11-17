package com.farzandim.farzandim_child

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.util.Log

/** [EnforcementEngine] → RestrictionService (poll oqimidan chaqiriladi). */
internal interface EnforcementHost {
    /** Kerakli overlay holati (null — yopilsin). Main oqimga uzatiladi. */
    fun requestOverlay(request: OverlayRequest?)

    /** Qurilma juftlanmagan (childId yo'q) — servis to'xtashi kerak. */
    fun onUnpaired()
}

/**
 * Bloklash sikli — FAQAT "parvoz-restriction-poll" oqimida ishlaydi
 * (kill-native-main-thread-polling): UsageStats so'rovlari, prefs va
 * PackageManager main oqimni (Flutter platform oqimi bilan umumiy)
 * bloklamaydi. Overlay esa [EnforcementHost.requestOverlay] orqali main
 * oqimda chiziladi.
 *
 * Har tick:
 *  1. snapshot (faqat versiya o'zgarganda qayta o'qiladi) va ishonchli vaqt;
 *  2. foreground — inkremental so'rov ([ForegroundTracker]);
 *  3. qaror ([EnforcementRules]) — limit ekstrapolyatsiya bilan
 *     ([LimitSession]), qo'ng'iroq paytida overlay yo'q ([TelephonyRules]);
 *  4. ruxsat etilgan yo'lda o'yin aniqlash ([GameDetector]).
 */
internal class EnforcementEngine(
    private val ctx: Context,
    private val host: EnforcementHost,
    private val snapshots: SnapshotSource,
    private val nativeStore: NativeStore,
    private val notifications: BlockNotifications,
    private val unlockWatch: UnlockWatch,
    private val dismissLatch: DismissLatch,
) {
    companion object {
        private const val TAG = "EnforcementEngine"
        private const val MINUTE_MS = 60_000L

        /** Limit so'rovi muvaffaqiyatsiz bo'lsa — keyingi urinishgacha. */
        private const val LIMIT_RETRY_MS = 30_000L

        /** a11y qiymati shu muddatdan eski bo'lsa e'tiborga olinmaydi. */
        private const val A11Y_FRESH_MS = 3_000L
    }

    private val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
    private val ownPackage = ctx.packageName
    private val tracker = ForegroundTracker()
    private val limitSession = LimitSession()
    private val clock = TrustedClock()
    private val appInfo = AppInfoLookup(ctx)
    private val games = GameDetector(ctx, nativeStore)

    private var lastForeground: String? = null
    private var limitRetryAt = 0L
    private var lastRequest: OverlayRequest? = null

    // Joriy tick qiymatlari (Lookup ichida ishlatiladi).
    private var tickWall = 0L
    private var tickElapsed = 0L
    private var tickDay = 0L
    private var tickDayStartWall = 0L

    /** Accessibility servisdan kelgan oxirgi foreground (yoqilmagan bo'lsa doim null). */
    @Volatile
    var a11yPkg: String? = null

    @Volatile
    var a11yAt = 0L

    /** Snapshot'da cheklov bormi — poll oralig'ini tanlash uchun (1 s / 3 s). */
    @Volatile
    var hasRules = true
        private set

    private val lookup = object : EnforcementRules.Lookup {
        override fun isAlwaysAllowed(pkg: String): Boolean =
            pkg == ownPackage || pkg in BlockPolicy.alwaysAllow(ctx)

        override fun schoolCategoryOf(pkg: String): String? =
            appInfo.schoolCategoryOf(pkg, games.cachedIsGame(pkg))

        override fun appLabelKey(pkg: String): String = appInfo.labelKey(pkg)

        override fun isLimitExceeded(pkg: String, limitMinutes: Int): Boolean =
            checkLimit(pkg, limitMinutes)

        override fun isUnknownSource(pkg: String): Boolean = appInfo.isUnknownSource(pkg)
    }

    /** Servis start (poll oqimi): bir martalik tozalash. */
    fun onStart(flutterPrefs: SharedPreferences) {
        nativeStore.cleanupLegacyWarnedKeys(flutterPrefs)
    }

    /** Ekran o'chdi (poll oqimi): foreground va limit sessiyasi tozalanadi. */
    fun onScreenOff(nowWall: Long) {
        tracker.onScreenOff(nowWall)
        limitSession.reset()
        lastForeground = null
    }

    fun shutdown() {
        games.shutdown()
    }

    fun tick() {
        val wall = System.currentTimeMillis()
        val elapsed = SystemClock.elapsedRealtime()
        val snap = snapshots.current(elapsed)
        if (!snap.paired) {
            host.onUnpaired()
            return
        }
        clock.updateOffset(snap.clockOffsetMs, wall, elapsed)
        val trusted = clock.now(wall, elapsed)
        tickWall = wall
        tickElapsed = elapsed
        tickDay = TashkentDay.dayIndex(trusted)
        tickDayStartWall = UsageEventsReader.todayStartWall(trusted, wall)

        val fg = detectForeground(wall)
        unlockWatch.check(fg, ownPackage, elapsed)?.let { pkg ->
            notifications.showUnlockFallback(pkg, appInfo.label(pkg))
        }
        if (fg != lastForeground) {
            lastForeground = fg
            limitSession.reset()
        }

        if (snap.hasNoRules(trusted)) {
            hasRules = false
            if (BlockPolicy.limitExceeded.isNotEmpty()) BlockPolicy.limitExceeded = emptySet()
            post(null)
            if (fg != null) games.onAllowedForeground(fg, trusted)
            return
        }
        hasRules = true
        // Foreground noma'lum (ekran yangi yondi va h.k.) — overlay holati o'zgarmaydi.
        if (fg == null) return

        val verdict = EnforcementRules.decide(fg, snap, trusted, lookup)
        val reason = verdict.reason
        if (reason == null) {
            if (fg in BlockPolicy.limitExceeded) BlockPolicy.limitExceeded = BlockPolicy.limitExceeded - fg
            post(null)
            games.onAllowedForeground(fg, trusted)
            return
        }
        // Qo'ng'iroq paytida (jiringlash/suhbat) blok overlay ko'rsatilmaydi.
        if (TelephonyRules.suppressOverlay(TelephonyGuard.audioMode(ctx))) {
            post(null)
            return
        }
        val schoolUntil = if (reason == EnforcementRules.REASON_SCHOOL) {
            snap.activeSchool(trusted)?.untilLabel.orEmpty()
        } else {
            ""
        }
        // Bola tugma bilan yopdi va HOME/Parvoz hali foreground'ga chiqmadi —
        // overlay ularning ustiga qayta qo'yilmasin (miltillash).
        if (dismissLatch.holds(fg)) return
        post(OverlayRequest(fg, reason, verdict.wildcard, schoolUntil))
    }

    /** Overlay so'rovini main oqimga uzatadi; allaqachon yopiq bo'lsa jim. */
    private fun post(request: OverlayRequest?) {
        if (request == null && lastRequest == null) return
        lastRequest = request
        host.requestOverlay(request)
    }

    private fun detectForeground(wall: Long): String? {
        val manager = usm
        if (manager != null) {
            try {
                UsageEventsReader.feed(manager, tracker.windowStart(wall, tickDayStartWall), wall, tracker)
                tracker.commit(wall)
            } catch (e: Exception) {
                logOnce("foreground", "foreground so'rovi xato", e)
            }
        }
        // Accessibility (yoqilgan bo'lsa) tizimdan DARHOL xabar beradi — ustun.
        val fresh = a11yPkg
        if (fresh != null && System.currentTimeMillis() - a11yAt <= A11Y_FRESH_MS) return fresh
        return tracker.foreground
    }

    /** Limit tekshiruvi: ekstrapolyatsiya, kerak bo'lganda bitta to'liq hisob. */
    private fun checkLimit(pkg: String, limitMinutes: Int): Boolean {
        val limitMs = limitMinutes * MINUTE_MS
        val usage = limitSession.estimate(pkg, limitMs, tickDay, tickElapsed) ?: run {
            // So'rov muvaffaqiyatsiz (yoki ochiq ilova uchun 0 — ishonchsiz): asos
            // yangilanmaydi, oldingi hukm saqlanadi va 30 s dan keyin qayta uriniladi
            // — aks holda limitdan oshgan ilova 5 daqiqa ochilib qolardi.
            if (tickElapsed < limitRetryAt) return pkg in BlockPolicy.limitExceeded
            val fresh = todayUsageMs(pkg)
            if (fresh == null) {
                limitRetryAt = tickElapsed + LIMIT_RETRY_MS
                return pkg in BlockPolicy.limitExceeded
            }
            limitRetryAt = 0L
            limitSession.rebase(pkg, limitMs, tickDay, fresh, tickElapsed)
            fresh
        }
        if (usage >= limitMs) {
            if (pkg !in BlockPolicy.limitExceeded) {
                Log.d(TAG, "Limit oshdi: $pkg ${usage / MINUTE_MS} min >= $limitMinutes min")
                // Accessibility yo'li uchun e'lon — u O(1) o'qiydi.
                BlockPolicy.limitExceeded = BlockPolicy.limitExceeded + pkg
            }
            return true
        }
        if (pkg in BlockPolicy.limitExceeded) BlockPolicy.limitExceeded = BlockPolicy.limitExceeded - pkg
        maybeWarn(pkg, limitMinutes, limitMs - usage)
        return false
    }

    /**
     * Bugun (Toshkent 00:00 dan) paketning ekrandagi vaqti — to'liq hisob.
     * null — hisoblab bo'lmadi: xato, yoki hozir ochiq ilova uchun 0 chiqdi
     * (ruxsat yo'q / tizim bo'sh qaytardi).
     */
    private fun todayUsageMs(pkg: String): Long? {
        val manager = usm ?: return null
        return try {
            val total = UsageEventsReader.accumulate(manager, tickDayStartWall, tickWall).totalMs(pkg)
            if (total > 0L) total else null
        } catch (e: Exception) {
            logOnce("usage", "bugungi usage hisoblanmadi", e)
            null
        }
    }

    /** Bir xil xato har soniyada stack trace bilan log'ni to'ldirmasin. */
    private val loggedErrors = HashSet<String>()

    private fun logOnce(key: String, message: String, e: Exception) {
        if (loggedErrors.add(key)) Log.e(TAG, message, e) else Log.w(TAG, "$message: ${e.message}")
    }

    /** Limitga min(10 daqiqa, limit/2) qolganda — kuniga bir marta (paket+limit). */
    private fun maybeWarn(pkg: String, limitMinutes: Int, remainingMs: Long) {
        if (remainingMs > LimitWarningRules.thresholdMs(limitMinutes * MINUTE_MS)) return
        if (!nativeStore.markLimitWarned(tickDay, pkg, limitMinutes)) return
        notifications.showLimitWarning(
            pkg,
            appInfo.label(pkg),
            LimitWarningRules.remainingMinutes(remainingMs),
        )
    }
}
