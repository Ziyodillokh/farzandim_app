package com.farzandim.farzandim_child

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeStoreCodecTest {

    @Test
    fun gameEntryRoundTrips() {
        val entry = GameCacheEntry(versionCode = 1_234_567_890_123L, isGame = true)

        assertEquals(entry, NativeStoreCodec.decodeGame(NativeStoreCodec.encodeGame(entry)))
        assertEquals(
            GameCacheEntry(5L, false),
            NativeStoreCodec.decodeGame(NativeStoreCodec.encodeGame(GameCacheEntry(5L, false))),
        )
    }

    @Test
    fun malformedGameEntriesAreRejected() {
        assertNull(NativeStoreCodec.decodeGame(null))
        assertNull(NativeStoreCodec.decodeGame(""))
        assertNull(NativeStoreCodec.decodeGame("12"))
        assertNull(NativeStoreCodec.decodeGame(":1"))
        assertNull(NativeStoreCodec.decodeGame("x:1"))
        assertNull(NativeStoreCodec.decodeGame("12:2"))
    }

    @Test
    fun warnedKeysAreOnePerDayAndOlderDaysAreStale() {
        assertEquals("limit_warned.20406", NativeStoreCodec.warnedKey(20_406L))
        assertEquals("com.youtube:30", NativeStoreCodec.warnedEntry("com.youtube", 30))
        assertTrue(NativeStoreCodec.isStaleWarnedKey("limit_warned.20405", today = 20_406L))
        assertFalse(NativeStoreCodec.isStaleWarnedKey("limit_warned.20406", today = 20_406L))
        assertFalse(NativeStoreCodec.isStaleWarnedKey("game.com.youtube", today = 20_406L))
    }
}

class GameQueuePolicyTest {

    private val dedup = 5 * 60 * 1000L

    @Test
    fun recentEntryOfTheSamePackageIsReplaced() {
        val existing = listOf(
            QueuedGame("com.a", 1_000L, "a1"),
            QueuedGame("com.b", 2_000L, "b1"),
        )

        val out = GameQueuePolicy.append(existing, QueuedGame("com.a", 3_000L, "a2"), dedup, cap = 50)

        assertEquals(listOf("b1", "a2"), out.map { it.payload })
    }

    @Test
    fun oldEntryOfTheSamePackageIsKept() {
        val existing = listOf(QueuedGame("com.a", 1_000L, "a1"))

        val out = GameQueuePolicy.append(existing, QueuedGame("com.a", 1_000L + dedup, "a2"), dedup, cap = 50)

        assertEquals(listOf("a1", "a2"), out.map { it.payload })
    }

    @Test
    fun queueIsCappedToTheNewestEntries() {
        val existing = (1..5).map { QueuedGame("com.p$it", it * 1_000_000L, "p$it") }

        val out = GameQueuePolicy.append(existing, QueuedGame("com.new", 9_000_000L, "new"), dedup, cap = 3)

        assertEquals(listOf("p4", "p5", "new"), out.map { it.payload })
    }
}

class UnlockWatchTest {

    private val own = "com.farzandim.growth"

    @Test
    fun noFallbackWhenParvozOpens() {
        val watch = UnlockWatch()
        watch.started("com.game", nowElapsed = 0L)

        assertNull(watch.check(own, own, nowElapsed = 1_000L))
        assertNull(watch.check("com.game", own, nowElapsed = 5_000L))
    }

    @Test
    fun fallbackOnceWhenParvozDoesNotOpenInTime() {
        val watch = UnlockWatch()
        watch.started("com.game", nowElapsed = 0L)

        assertNull(watch.check("com.game", own, nowElapsed = 1_000L))
        assertEquals("com.game", watch.check("com.game", own, nowElapsed = UnlockWatch.OPEN_TIMEOUT_MS))
        assertNull(watch.check("com.game", own, nowElapsed = UnlockWatch.OPEN_TIMEOUT_MS + 1_000L))
    }

    @Test
    fun staleRequestIsDroppedSilently() {
        val watch = UnlockWatch()
        watch.started("com.game", nowElapsed = 0L)

        assertNull(watch.check("com.game", own, nowElapsed = UnlockWatch.EXPIRY_MS + 1))
        assertNull(watch.check("com.game", own, nowElapsed = UnlockWatch.EXPIRY_MS + 2))
    }
}
