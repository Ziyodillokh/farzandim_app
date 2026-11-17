package com.farzandim.farzandim_child

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LimitSessionTest {

    private val minute = 60_000L
    private val pkg = "com.example.video"
    private val limit = 30 * minute
    private val day = 20_000L

    @Test
    fun enteringALimitedAppNeedsOneFullComputation() {
        val session = LimitSession()

        assertNull(session.estimate(pkg, limit, day, nowElapsed = 1_000))
    }

    @Test
    fun estimateExtrapolatesWithElapsedTime() {
        val session = LimitSession()
        session.rebase(pkg, limit, day, usageMs = 10 * minute, nowElapsed = 1_000)

        assertEquals(10 * minute + 60_000, session.estimate(pkg, limit, day, nowElapsed = 61_000))
        assertFalse(session.exceeded)
    }

    @Test
    fun rebaseIsRequiredAfterFiveMinutes() {
        val session = LimitSession()
        session.rebase(pkg, limit, day, usageMs = 0L, nowElapsed = 1_000)

        assertEquals(LimitSession.REBASE_INTERVAL_MS - 1, session.estimate(pkg, limit, day, 1_000 + LimitSession.REBASE_INTERVAL_MS - 1))
        assertNull(session.estimate(pkg, limit, day, 1_000 + LimitSession.REBASE_INTERVAL_MS))
    }

    @Test
    fun crossingIsConfirmedByAQueryTwoSecondsBeforeTheLimit() {
        val session = LimitSession()
        session.rebase(pkg, limit, day, usageMs = limit - 3_000, nowElapsed = 0L)

        assertEquals(limit - 2_500, session.estimate(pkg, limit, day, nowElapsed = 500))
        assertNull(session.estimate(pkg, limit, day, nowElapsed = 1_500))
    }

    @Test
    fun exceededLimitNeedsNoMoreQueries() {
        val session = LimitSession()
        session.rebase(pkg, limit, day, usageMs = limit + 1, nowElapsed = 0L)

        assertTrue(session.exceeded)
        assertEquals(limit + 1, session.estimate(pkg, limit, day, nowElapsed = 60 * minute))
    }

    @Test
    fun packageLimitOrDayChangeInvalidatesTheSession() {
        val session = LimitSession()
        session.rebase(pkg, limit, day, usageMs = limit + 1, nowElapsed = 0L)

        assertNull(session.estimate("com.other", limit, day, nowElapsed = 1_000))
        assertNull(session.estimate(pkg, limit + minute, day, nowElapsed = 1_000))
        assertNull(session.estimate(pkg, limit, day + 1, nowElapsed = 1_000))
    }

    @Test
    fun resetForgetsTheSession() {
        val session = LimitSession()
        session.rebase(pkg, limit, day, usageMs = limit + 1, nowElapsed = 0L)

        session.reset()

        assertFalse(session.exceeded)
        assertNull(session.estimate(pkg, limit, day, nowElapsed = 1_000))
    }
}

class LimitWarningRulesTest {

    private val minute = 60_000L

    @Test
    fun thresholdIsTheSmallerOfTenMinutesAndHalfTheLimit() {
        assertEquals(10 * minute, LimitWarningRules.thresholdMs(60 * minute))
        assertEquals(5 * minute, LimitWarningRules.thresholdMs(10 * minute))
        assertEquals(30_000L, LimitWarningRules.thresholdMs(1 * minute))
    }

    @Test
    fun remainingMinutesRoundUpAndAreAtLeastOne() {
        assertEquals(1L, LimitWarningRules.remainingMinutes(0L))
        assertEquals(1L, LimitWarningRules.remainingMinutes(minute))
        assertEquals(2L, LimitWarningRules.remainingMinutes(minute + 1))
        assertEquals(5L, LimitWarningRules.remainingMinutes(5 * minute - 1))
    }

    @Test
    fun minPlaceholderIsReplaced() {
        assertEquals(
            "YouTube: ~4 min",
            LimitWarningRules.formatBody("{label}: ~{min} min", "YouTube", 4),
        )
    }

    @Test
    fun legacyTranslationWithLiteralTenGetsTheRealMinutes() {
        val uz = "{label} uchun bugungi vaqtingga ~10 daqiqa qoldi."
        assertEquals(
            "YouTube uchun bugungi vaqtingga ~4 daqiqa qoldi.",
            LimitWarningRules.formatBody(uz, "YouTube", 4),
        )
        assertEquals(
            "YouTube uchun bugungi vaqtingga ~10 daqiqa qoldi.",
            LimitWarningRules.formatBody(uz, "YouTube", 10),
        )
    }

    @Test
    fun digitsInsideTheAppLabelAreNotTouched() {
        val en = "About 10 minutes left for {label} today."
        assertEquals(
            "About 3 minutes left for Top 10 Games today.",
            LimitWarningRules.formatBody(en, "Top 10 Games", 3),
        )
    }
}
