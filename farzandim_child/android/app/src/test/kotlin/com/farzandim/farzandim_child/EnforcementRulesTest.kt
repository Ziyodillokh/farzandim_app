package com.farzandim.farzandim_child

import com.farzandim.farzandim_child.EnforcementRules.REASON_BLOCKED
import com.farzandim.farzandim_child.EnforcementRules.REASON_LIMIT
import com.farzandim.farzandim_child.EnforcementRules.REASON_SCHOOL
import com.farzandim.farzandim_child.EnforcementRules.REASON_UNKNOWN_SOURCE
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_BASE_BLOCKED
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_BLOCKED
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_BLOCK_UNKNOWN
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_CHILD_ID
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_GRANTS
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_LIMITS
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_SCHOOL_ALLOWED
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_SCHOOL_CATEGORIES
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_SCHOOL_PACKAGES
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_SCHOOL_UNTIL
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_SCHOOL_UNTIL_MS
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_VALID_UNTIL_MS
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EnforcementRulesTest {

    private val now = 1_000_000L
    private val game = "com.example.game"

    private class FakeLookup(
        val alwaysAllowed: Set<String> = setOf("com.launcher", "com.android.phone"),
        val categories: Map<String, String> = emptyMap(),
        val labels: Map<String, String> = emptyMap(),
        val exceeded: Set<String> = emptySet(),
        val unknownSources: Set<String> = emptySet(),
    ) : EnforcementRules.Lookup {
        var limitChecks = 0

        override fun isAlwaysAllowed(pkg: String) = pkg in alwaysAllowed
        override fun schoolCategoryOf(pkg: String) = categories[pkg]
        override fun appLabelKey(pkg: String) = labels[pkg].orEmpty()
        override fun isLimitExceeded(pkg: String, limitMinutes: Int): Boolean {
            limitChecks++
            return pkg in exceeded
        }
        override fun isUnknownSource(pkg: String) = pkg in unknownSources
    }

    private fun snapshot(vararg pairs: Pair<String, Any?>) =
        EnforcementSnapshot.read(MapPrefs(mapOf(KEY_CHILD_ID to "child-1", *pairs)))

    private fun decide(pkg: String, snap: EnforcementSnapshot, lookup: FakeLookup = FakeLookup()) =
        EnforcementRules.decide(pkg, snap, now, lookup)

    private val lesson = arrayOf<Pair<String, Any?>>(
        KEY_SCHOOL_PACKAGES to game,
        KEY_SCHOOL_CATEGORIES to "GAME",
        KEY_SCHOOL_ALLOWED to "kundalik",
        KEY_SCHOOL_UNTIL to "13:00",
        KEY_SCHOOL_UNTIL_MS to now + 60_000,
    )

    @Test
    fun wildcardBlocksOrdinaryAppsButNeverEssentials() {
        val snap = snapshot(KEY_BLOCKED to "*")

        assertEquals(EnforcementRules.Verdict(REASON_BLOCKED, wildcard = true), decide(game, snap))
        assertEquals(EnforcementRules.ALLOW, decide("com.launcher", snap))
        assertEquals(EnforcementRules.ALLOW, decide("com.android.phone", snap))
    }

    @Test
    fun explicitBlockIsNotReportedAsWildcard() {
        val snap = snapshot(KEY_BLOCKED to "*,$game")

        assertEquals(EnforcementRules.Verdict(REASON_BLOCKED, wildcard = false), decide(game, snap))
    }

    @Test
    fun grantOpensWildcardFullBlockLimitAndUnknownSource() {
        val snap = snapshot(
            KEY_BLOCKED to "*,$game",
            KEY_LIMITS to "$game:10",
            KEY_BLOCK_UNKNOWN to true,
            KEY_GRANTS to "$game:${now + 60_000}",
        )
        val lookup = FakeLookup(exceeded = setOf(game), unknownSources = setOf(game))

        assertEquals(EnforcementRules.ALLOW, decide(game, snap, lookup))
        assertEquals(0, lookup.limitChecks)
    }

    @Test
    fun expiredGrantNoLongerOpens() {
        val snap = snapshot(KEY_BLOCKED to game, KEY_GRANTS to "$game:$now")

        assertEquals(REASON_BLOCKED, decide(game, snap).reason)
    }

    @Test
    fun schoolBlockWinsOverAParentGrant() {
        val snap = snapshot(*lesson, KEY_BLOCKED to game, KEY_GRANTS to "$game:${now + 60_000}")

        assertEquals(REASON_SCHOOL, decide(game, snap).reason)
    }

    @Test
    fun schoolCategoryBlocksUnlistedGamesButNotAllowedApps() {
        val snap = snapshot(*lesson)
        val lookup = FakeLookup(
            categories = mapOf("com.new.game" to "GAME", "com.diary" to "GAME"),
            labels = mapOf("com.diary" to "kundalik"),
        )

        assertEquals(REASON_SCHOOL, decide("com.new.game", snap, lookup).reason)
        assertEquals(EnforcementRules.ALLOW, decide("com.diary", snap, lookup))
    }

    @Test
    fun endedLessonFallsThroughToNormalRules() {
        val snap = snapshot(
            KEY_SCHOOL_PACKAGES to game,
            KEY_SCHOOL_UNTIL to "13:00",
            KEY_SCHOOL_UNTIL_MS to now - 1,
            // Dart maktab paketlarini blocked'ga ham qo'shadi.
            KEY_BLOCKED to game,
            KEY_BASE_BLOCKED to "",
        )

        assertEquals(EnforcementRules.ALLOW, decide(game, snap))
    }

    @Test
    fun staleSnapshotDropsTheWindowWildcardButKeepsFullBlocks() {
        val snap = snapshot(
            KEY_BLOCKED to "*,com.full",
            KEY_BASE_BLOCKED to "com.full",
            KEY_VALID_UNTIL_MS to now - EnforcementSnapshot.STALE_GRACE_MS - 1,
        )

        assertEquals(EnforcementRules.ALLOW, decide(game, snap))
        assertEquals(REASON_BLOCKED, decide("com.full", snap).reason)
    }

    @Test
    fun limitIsCheckedOnlyForPositiveLimits() {
        val lookup = FakeLookup(exceeded = setOf(game))

        assertEquals(REASON_LIMIT, decide(game, snapshot(KEY_LIMITS to "$game:30"), lookup).reason)
        assertEquals(EnforcementRules.ALLOW, decide(game, snapshot(KEY_LIMITS to "$game:0"), lookup))
        assertEquals(EnforcementRules.ALLOW, decide("com.other", snapshot(KEY_LIMITS to "com.other:30"), lookup))
    }

    @Test
    fun unknownSourceIsBlockedOnlyWhenEnabled() {
        val lookup = FakeLookup(unknownSources = setOf(game))

        assertEquals(REASON_UNKNOWN_SOURCE, decide(game, snapshot(KEY_BLOCK_UNKNOWN to true), lookup).reason)
        assertEquals(EnforcementRules.ALLOW, decide(game, snapshot(KEY_BLOCK_UNKNOWN to false), lookup))
    }

    @Test
    fun verdictReportsBlockState() {
        assertTrue(EnforcementRules.Verdict(REASON_BLOCKED).isBlock)
        assertFalse(EnforcementRules.ALLOW.isBlock)
    }
}
