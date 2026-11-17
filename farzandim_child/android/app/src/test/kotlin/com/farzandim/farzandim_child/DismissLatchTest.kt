package com.farzandim.farzandim_child

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DismissLatchTest {

    private var clock = 0L
    private val latch = DismissLatch { clock }
    private val game = "com.example.game"

    @Test
    fun holdsTheDismissedPackageForAShortTime() {
        latch.dismissed(game)

        assertTrue(latch.holds(game))
        clock += DismissLatch.HOLD_MS - 1
        assertTrue(latch.holds(game))
        clock += 1
        assertFalse(latch.holds(game))
    }

    @Test
    fun foregroundChangeReleasesTheLatch() {
        latch.dismissed(game)

        assertFalse(latch.holds("com.android.launcher3"))
        // Qulf yechildi — o'yinga qaytilsa overlay darhol chiqadi.
        assertFalse(latch.holds(game))
    }

    @Test
    fun nothingIsHeldWithoutADismissal() {
        assertFalse(latch.holds(game))
        assertFalse(latch.holds(null))
    }
}
