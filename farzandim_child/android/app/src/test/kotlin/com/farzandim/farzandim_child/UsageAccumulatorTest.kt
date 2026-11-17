package com.farzandim.farzandim_child

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

class UsageAccumulatorTest {

    private val game = "com.example.game"
    private val video = "com.example.video"
    private val launcher = "com.example.launcher"

    @Test
    fun splashToMainCountsTheWholeSession() {
        // Android 10+: PAUSED(Splash) → RESUMED(Main) → STOPPED(Splash).
        // Avval STOPPED(Splash) Main sessiyasini yopib, vaqt yo'qolardi.
        val acc = UsageAccumulator(windowStart = 0L)
        acc.resumed(game, "Splash", 1_000)
        acc.paused(game, "Splash", 3_000)
        acc.resumed(game, "Main", 3_100)
        acc.stopped(game, "Splash", 3_600)
        acc.paused(game, "Main", 603_100)
        acc.resumed(launcher, "Home", 603_150)
        acc.stopped(game, "Main", 603_600)

        val totals = acc.finish(700_000)

        assertEquals(2_000L + 600_000L, totals[game])
        assertEquals(700_000L - 603_150L, totals[launcher])
    }

    @Test
    fun navigationFromAToBAndBackInsideOneAppIsContinuous() {
        val acc = UsageAccumulator(windowStart = 0L)
        acc.resumed(game, "A", 1_000)
        acc.paused(game, "A", 2_000)
        acc.resumed(game, "B", 2_100)
        acc.stopped(game, "A", 2_500)
        acc.paused(game, "B", 5_000)
        acc.resumed(game, "A", 5_100)
        acc.stopped(game, "B", 5_400)
        acc.paused(game, "A", 9_000)

        acc.finish(20_000)

        assertEquals(1_000L + 2_900L + 3_900L, acc.totalMs(game))
    }

    @Test
    fun screenOffClosesTheSessionAndScreenOnWaitsForResume() {
        val acc = UsageAccumulator(windowStart = 0L)
        acc.resumed(game, "A", 1_000)
        acc.screenOff(5_000)
        acc.paused(game, "A", 5_050)
        acc.stopped(game, "A", 5_100)
        acc.keyguardShown(5_200)
        acc.screenOn(20_000)
        acc.keyguardHidden(22_000)
        acc.resumed(game, "A", 22_500)
        acc.paused(game, "A", 25_000)

        acc.finish(30_000)

        // Ekran o'chiq oraliq (5 000 – 22 500) hisoblanmaydi.
        assertEquals(4_000L + 2_500L, acc.totalMs(game))
    }

    @Test
    fun sessionOpenAtMidnightIsCarriedOverAndClipped() {
        val dayStart = 100_000L
        val acc = UsageAccumulator(windowStart = dayStart)
        // Butunlay kechagi sessiya — bugunga kirmaydi.
        acc.resumed(video, "Player", 10_000)
        acc.paused(video, "Player", 30_000)
        // Yarim tundan oldin ochilgan, keyin davom etgan sessiya.
        acc.resumed(game, "A", 40_000)
        acc.paused(game, "A", 160_000)

        val totals = acc.finish(200_000)

        assertEquals(60_000L, totals[game])
        assertNull(totals[video])
    }

    @Test
    fun twoPackagesInterleavedAreCountedSeparately() {
        val acc = UsageAccumulator(windowStart = 0L)
        acc.resumed(game, "A", 1_000)
        acc.paused(game, "A", 2_000)
        acc.resumed(video, "X", 2_050)
        acc.stopped(game, "A", 2_500)
        acc.paused(video, "X", 4_000)
        acc.resumed(game, "A", 4_050)
        acc.stopped(video, "X", 4_400)
        acc.paused(game, "A", 7_000)
        acc.resumed(video, "X", 7_050)
        acc.paused(video, "X", 8_000)

        acc.finish(9_000)

        assertEquals(1_000L + 2_950L, acc.totalMs(game))
        assertEquals(1_950L + 950L, acc.totalMs(video))
    }

    @Test
    fun resumeOfAnotherPackageClosesAnOrphanSession() {
        // PAUSED umuman kelmagan (OEM) — butun kun qo'shilib ketmasin.
        val acc = UsageAccumulator(windowStart = 0L)
        acc.resumed(game, "A", 1_000)
        acc.resumed(video, "X", 5_000)

        acc.finish(6_000)

        assertEquals(4_000L, acc.totalMs(game))
        assertEquals(1_000L, acc.totalMs(video))
    }

    @Test
    fun droppedPausedFallsBackToStopped() {
        val acc = UsageAccumulator(windowStart = 0L)
        acc.resumed(game, "A", 1_000)
        acc.stopped(game, "A", 4_000)

        acc.finish(10_000)

        assertEquals(3_000L, acc.totalMs(game))
    }

    @Test
    fun newInstanceOfTheSameActivityKeepsTheSessionOpen() {
        // PAUSED(A#1) → RESUMED(A#2) → STOPPED(A#1): A#2 hali ekranda.
        val acc = UsageAccumulator(windowStart = 0L)
        acc.resumed(game, "A", 1_000)
        acc.paused(game, "A", 2_000)
        acc.resumed(game, "A", 2_100)
        acc.stopped(game, "A", 2_600)
        acc.paused(game, "A", 9_000)

        acc.finish(10_000)

        assertEquals(1_000L + 6_900L, acc.totalMs(game))
    }

    @Test
    fun keyguardShownClosesTheSession() {
        val acc = UsageAccumulator(windowStart = 0L)
        acc.resumed(game, "A", 1_000)
        acc.keyguardShown(3_000)
        acc.resumed(game, "A", 4_000)

        acc.finish(5_000)

        assertEquals(2_000L + 1_000L, acc.totalMs(game))
    }

    @Test
    fun deviceStartupWithoutShutdownDoesNotCountPowerOffTime() {
        val acc = UsageAccumulator(windowStart = 0L)
        acc.resumed(game, "A", 1_000)
        acc.onEvent(12 /* NOTIFICATION_INTERRUPTION */, game, null, 3_000)
        acc.onEvent(UsageEventTypes.DEVICE_STARTUP, "android", null, 100_000)

        acc.finish(200_000)

        assertEquals(2_000L, acc.totalMs(game))
    }

    @Test
    fun openSessionIsCountedUntilNowAndLastUsedIsSessionEnd() {
        val acc = UsageAccumulator(windowStart = 0L)
        acc.resumed(game, "A", 1_000)
        acc.paused(game, "A", 2_000)
        acc.resumed(game, "A", 3_000)

        acc.finish(6_000)

        assertEquals(1_000L + 3_000L, acc.totalMs(game))
        assertEquals(6_000L, acc.lastUsed(game))
    }

    @Test
    fun machineTracksCurrentPackageAndSessionState() {
        val machine = ActivitySessionMachine()
        machine.resumed(game, "A", 1_000)
        machine.paused(game, "A", 2_000)

        // Pauzadan keyin ham oxirgi foreground paket — game (sessiya yopiq).
        assertEquals(game, machine.currentPackage)
        assertFalse(machine.isSessionOpen)

        machine.screenOff(3_000)
        assertNull(machine.currentPackage)
    }
}
