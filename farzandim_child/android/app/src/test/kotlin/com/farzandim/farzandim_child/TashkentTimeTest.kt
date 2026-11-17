package com.farzandim.farzandim_child

import java.time.Instant
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Test

class TashkentTimeTest {

    private val tashkent = ZoneId.of("Asia/Tashkent")

    @Test
    fun startOfDayMatchesTheAsiaTashkentZone() {
        var t = Instant.parse("2026-11-12T00:00:00Z").toEpochMilli()
        val end = Instant.parse("2026-11-16T00:00:00Z").toEpochMilli()
        while (t < end) {
            val expected = Instant.ofEpochMilli(t).atZone(tashkent).toLocalDate()
                .atStartOfDay(tashkent).toInstant().toEpochMilli()
            assertEquals("t=$t", expected, TashkentDay.startOfDay(t))
            t += 37 * 60 * 1000L
        }
    }

    @Test
    fun dayIndexChangesExactlyAtTashkentMidnight() {
        // 2026-11-14 00:00 Toshkent = 2026-11-13 19:00 UTC.
        val midnight = Instant.parse("2026-11-13T19:00:00Z").toEpochMilli()

        assertEquals(TashkentDay.dayIndex(midnight - 1) + 1, TashkentDay.dayIndex(midnight))
        assertEquals(midnight, TashkentDay.startOfDay(midnight))
        assertEquals(midnight, TashkentDay.startOfDay(midnight + TashkentDay.DAY_MS - 1))
    }

    @Test
    fun clockWithoutOffsetUsesDeviceTime() {
        val clock = TrustedClock()
        clock.updateOffset(null, wallNow = 1_000, elapsedNow = 10)

        assertEquals(5_000L, clock.now(wallNow = 5_000, elapsedNow = 4_010))
    }

    @Test
    fun clockAppliesTheServerOffset() {
        val clock = TrustedClock()
        clock.updateOffset(-3_000, wallNow = 1_000_000, elapsedNow = 10_000)

        assertEquals(1_002_000L - 3_000L, clock.now(wallNow = 1_002_000, elapsedNow = 12_000))
    }

    @Test
    fun manualClockJumpAfterAnchoringIsIgnored() {
        val day = TashkentDay.DAY_MS
        val clock = TrustedClock()
        clock.updateOffset(1_000, wallNow = 1_000_000, elapsedNow = 10_000)

        // Bola soatni 1 kun oldinga surdi (internet o'chiq — Dart offsetni
        // yangilay olmaydi): ishonchli vaqt elapsedRealtime bo'yicha yuradi.
        assertEquals(1_006_000L, clock.now(wallNow = 1_005_000 + day, elapsedNow = 15_000))
    }

    @Test
    fun smallDriftFollowsTheFormula() {
        val clock = TrustedClock()
        clock.updateOffset(1_000, wallNow = 1_000_000, elapsedNow = 10_000)

        assertEquals(1_006_030L, clock.now(wallNow = 1_005_030, elapsedNow = 15_000))
    }

    @Test
    fun newOffsetReanchors() {
        val day = TashkentDay.DAY_MS
        val clock = TrustedClock()
        clock.updateOffset(0, wallNow = 1_000_000, elapsedNow = 10_000)
        // Dart serverdan yangi farqni bildi (soat 1 kun oldinda).
        clock.updateOffset(-day, wallNow = 1_005_000 + day, elapsedNow = 15_000)

        assertEquals(1_007_000L, clock.now(wallNow = 1_007_000 + day, elapsedNow = 17_000))
    }

    @Test
    fun trustedInstantConvertsBackToDeviceTime() {
        assertEquals(7_000L, TrustedClock.toWall(trustedMs = 10_000, trustedNow = 20_000, wallNow = 17_000))
    }
}
