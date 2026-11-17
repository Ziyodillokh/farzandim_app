package com.farzandim.farzandim_child

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ForegroundTrackerTest {

    private val hour = 60 * 60 * 1000L
    private val game = "com.example.game"
    private val video = "com.example.video"

    @Test
    fun seedWindowIsThreeHoursAndIgnoresTheDayStart() {
        val tracker = ForegroundTracker()
        assertTrue(tracker.needsSeed)

        assertEquals(7 * hour, tracker.windowStart(nowWall = 10 * hour, dayStartWall = 0L))
        // 00:30 dagi qayta start: kun boshi (00:00) bilan qirqilmaydi.
        assertEquals(-150 * 60 * 1000L, tracker.windowStart(nowWall = 30 * 60 * 1000L, dayStartWall = 0L))
    }

    @Test
    fun appOpenedBeforeMidnightIsFoundAfterARestartPastMidnight() {
        val tracker = ForegroundTracker()
        val midnight = 24 * hour
        tracker.resumed(game, "Unity", midnight - 30 * 60 * 1000L) // 23:30
        tracker.commit(midnight + 30 * 60 * 1000L) // 00:30 dagi seed

        assertEquals(game, tracker.foreground)
    }

    @Test
    fun emptySeedTriggersOneWideLookupThenNormalWindows() {
        val tracker = ForegroundTracker()
        tracker.commit(20 * hour) // seed hech narsa topmadi

        assertEquals(20 * hour + 1_000 - 12 * hour, tracker.windowStart(nowWall = 20 * hour + 1_000, dayStartWall = 0L))
        tracker.resumed(game, "Unity", 10 * hour)
        tracker.commit(20 * hour + 1_000)

        assertEquals(game, tracker.foreground)
        assertEquals(20 * hour - 1_000, tracker.windowStart(nowWall = 20 * hour + 2_000, dayStartWall = 0L))
    }

    @Test
    fun incrementalWindowOverlapsTwoSecondsAndIsCappedAtThreeHours() {
        val tracker = ForegroundTracker()
        tracker.commit(1_000_000L) // seed (bo'sh) — keyingisi bir martalik keng qidiruv
        tracker.commit(1_000_000L) // keng qidiruv ham o'tdi — endi oddiy oynalar
        assertFalse(tracker.needsSeed)

        assertEquals(998_000L, tracker.windowStart(nowWall = 1_001_000L, dayStartWall = 0L))
        assertEquals(5 * hour - 3 * hour, tracker.windowStart(nowWall = 5 * hour, dayStartWall = 0L))
    }

    @Test
    fun seedFindsAnAppThatHasBeenInFrontForHours() {
        // Servis o'yin o'rtasida qayta ishga tushdi — oxirgi 60 s da RESUMED yo'q.
        val tracker = ForegroundTracker()
        tracker.resumed(video, "X", 1 * hour)
        tracker.paused(video, "X", 2 * hour)
        tracker.resumed(game, "Unity", 2 * hour + 100)
        tracker.stopped(video, "X", 2 * hour + 600)
        tracker.commit(4 * hour)

        assertEquals(game, tracker.foreground)
    }

    @Test
    fun lastResumedPackageStaysForegroundAcrossInAppTransitions() {
        val tracker = ForegroundTracker()
        tracker.resumed(game, "A", 1_000)
        tracker.paused(game, "A", 2_000)
        // B hali RESUMED bo'lmagan oraliq — overlay miltillamasin.
        assertEquals(game, tracker.foreground)

        tracker.resumed(video, "X", 2_100)
        assertEquals(video, tracker.foreground)
    }

    @Test
    fun screenEventsClearTheForeground() {
        val tracker = ForegroundTracker()
        tracker.resumed(game, "A", 1_000)
        tracker.screenOff(2_000)

        assertNull(tracker.foreground)
    }

    @Test
    fun screenOffBroadcastClearsForegroundAndRestartsWindowFromThatMoment() {
        val tracker = ForegroundTracker()
        tracker.resumed(game, "A", 900)
        tracker.commit(1_000)

        tracker.onScreenOff(5_000)

        assertNull(tracker.foreground)
        assertEquals(5_000L, tracker.lastQueryEnd)
        assertEquals(3_000L, tracker.windowStart(nowWall = 60_000, dayStartWall = 0L))
    }

    @Test
    fun screenOffBeforeTheFirstSeedKeepsTheSeedPending() {
        val tracker = ForegroundTracker()
        tracker.onScreenOff(5_000)

        assertTrue(tracker.needsSeed)
    }

    @Test
    fun replayingTheOverlapDoesNotChangeTheResult() {
        val once = ForegroundTracker()
        once.resumed(game, "A", 1_000)
        once.paused(game, "A", 1_500)
        once.resumed(video, "X", 1_600)
        once.stopped(game, "A", 1_900)

        val replayed = ForegroundTracker()
        replayed.resumed(game, "A", 1_000)
        replayed.paused(game, "A", 1_500)
        replayed.commit(1_700)
        // Keyingi oyna [1 700 − 2 000, ...] — 1 500 dan keyingilar qayta keladi.
        replayed.paused(game, "A", 1_500)
        replayed.resumed(video, "X", 1_600)
        replayed.stopped(game, "A", 1_900)

        assertEquals(once.foreground, replayed.foreground)
        assertEquals(video, replayed.foreground)
    }
}
