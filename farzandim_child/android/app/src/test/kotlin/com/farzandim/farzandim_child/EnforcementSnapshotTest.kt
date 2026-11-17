package com.farzandim.farzandim_child

import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_BASE_BLOCKED
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_BLOCKED
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_BLOCK_UNKNOWN
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_CHILD_ID
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_CLOCK_OFFSET_MS
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_GRANTS
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_LIMITS
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_SCHOOL_ALLOWED
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_SCHOOL_CATEGORIES
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_SCHOOL_PACKAGES
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_SCHOOL_UNTIL
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_SCHOOL_UNTIL_MS
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_VALID_UNTIL_MS
import com.farzandim.farzandim_child.EnforcementSnapshot.Companion.KEY_VERSION
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class EnforcementSnapshotTest {

    private fun snapshot(vararg pairs: Pair<String, Any?>) =
        EnforcementSnapshot.read(MapPrefs(mapOf(KEY_CHILD_ID to "child-1", *pairs)))

    @Test
    fun readsEveryContractKey() {
        val snap = snapshot(
            KEY_VERSION to 7L,
            KEY_BLOCKED to "*,com.a, com.b ,",
            KEY_BASE_BLOCKED to "com.a",
            KEY_LIMITS to "com.youtube:15,com.tiktok:30",
            KEY_BLOCK_UNKNOWN to true,
            KEY_SCHOOL_PACKAGES to "com.game",
            KEY_SCHOOL_CATEGORIES to "GAME,SOCIAL",
            KEY_SCHOOL_ALLOWED to "kundalik\nmaktab",
            KEY_SCHOOL_UNTIL to "13:00",
            KEY_SCHOOL_UNTIL_MS to 5_000L,
            KEY_VALID_UNTIL_MS to 4_000L,
            KEY_GRANTS to "com.tiktok:9000",
            KEY_CLOCK_OFFSET_MS to -1_500L,
        )

        assertTrue(snap.paired)
        assertEquals(7L, snap.version)
        assertEquals(setOf("*", "com.a", "com.b"), snap.blocked)
        assertEquals(setOf("com.a"), snap.baseBlocked)
        assertEquals(mapOf("com.youtube" to 15, "com.tiktok" to 30), snap.limits)
        assertTrue(snap.blockUnknown)
        val school = snap.school!!
        assertEquals(setOf("com.game"), school.packages)
        assertEquals(setOf("GAME", "SOCIAL"), school.categories)
        assertEquals(setOf("kundalik", "maktab"), school.allowed)
        assertEquals("13:00", school.untilLabel)
        assertEquals(5_000L, school.untilMs)
        assertEquals(4_000L, snap.validUntilMs)
        assertEquals(mapOf("com.tiktok" to 9_000L), snap.grants)
        assertEquals(-1_500L, snap.clockOffsetMs)
    }

    @Test
    fun oldDartWithoutNewKeysBehavesLikeBefore() {
        val snap = snapshot(KEY_BLOCKED to "*", KEY_SCHOOL_UNTIL to "13:00")

        assertNull(snap.version)
        assertNull(snap.baseBlocked)
        assertEquals(0L, snap.validUntilMs)
        assertNull(snap.clockOffsetMs)
        // Vaqt chegarasi yo'q — hech qachon eskirmaydi, maktab bloki amalda.
        assertEquals(setOf("*"), snap.effectiveBlocked(Long.MAX_VALUE / 2))
        assertNotNull(snap.activeSchool(Long.MAX_VALUE / 2))
    }

    @Test
    fun missingChildIdMeansNotPaired() {
        val snap = EnforcementSnapshot.read(MapPrefs(emptyMap()))

        assertFalse(snap.paired)
        assertTrue(snap.hasNoRules(0L))
    }

    @Test
    fun malformedLimitAndGrantEntriesAreSkipped() {
        assertEquals(
            mapOf("a" to 10, "d" to 7),
            EnforcementSnapshot.parseLimits("a:10,b,c:x,:5, d : 7"),
        )
        assertEquals(
            mapOf("a" to 1_700_000_000_000L),
            EnforcementSnapshot.parseGrants("a:1700000000000,b:,c:1:2"),
        )
    }

    @Test
    fun staleSnapshotFallsBackToBaseBlockedPackages() {
        val snap = snapshot(
            KEY_BLOCKED to "*,com.full,com.routine",
            KEY_BASE_BLOCKED to "com.full",
            KEY_VALID_UNTIL_MS to 1_000L,
        )

        assertFalse(snap.isStale(1_000L + EnforcementSnapshot.STALE_GRACE_MS))
        assertEquals(setOf("*", "com.full", "com.routine"), snap.effectiveBlocked(1_000L))
        assertTrue(snap.isStale(1_000L + EnforcementSnapshot.STALE_GRACE_MS + 1))
        assertEquals(setOf("com.full"), snap.effectiveBlocked(1_000L + EnforcementSnapshot.STALE_GRACE_MS + 1))
    }

    @Test
    fun staleSnapshotWithoutBaseKeyKeepsBlockedPackages() {
        val snap = snapshot(KEY_BLOCKED to "com.full", KEY_VALID_UNTIL_MS to 1_000L)

        assertEquals(setOf("com.full"), snap.effectiveBlocked(10_000_000L))
    }

    @Test
    fun schoolBlockEndsAtSchoolUntilMs() {
        val snap = snapshot(
            KEY_SCHOOL_PACKAGES to "com.game",
            KEY_SCHOOL_UNTIL to "13:00",
            KEY_SCHOOL_UNTIL_MS to 5_000L,
        )

        assertNotNull(snap.activeSchool(4_999L))
        assertNull(snap.activeSchool(5_000L))
    }

    @Test
    fun schoolPackagesLeaveTheBlockedListWhenTheLessonEnds() {
        val snap = snapshot(
            KEY_BLOCKED to "com.lesson,com.both,com.parent",
            KEY_BASE_BLOCKED to "com.both,com.parent",
            KEY_SCHOOL_PACKAGES to "com.lesson,com.both",
            KEY_SCHOOL_UNTIL to "13:00",
            KEY_SCHOOL_UNTIL_MS to 5_000L,
            KEY_VALID_UNTIL_MS to 5_000L,
        )

        assertEquals(setOf("com.lesson", "com.both", "com.parent"), snap.effectiveBlocked(4_000L))
        // Dars tugadi, Dart hali qayta yozmagan: ota-ona bloklaganlari qoladi.
        assertEquals(setOf("com.both", "com.parent"), snap.effectiveBlocked(5_000L))
    }

    @Test
    fun staleSnapshotIgnoresTheSchoolBlock() {
        val snap = snapshot(
            KEY_SCHOOL_PACKAGES to "com.game",
            KEY_SCHOOL_UNTIL to "13:00",
            KEY_VALID_UNTIL_MS to 1_000L,
        )

        assertNull(snap.activeSchool(1_000L + EnforcementSnapshot.STALE_GRACE_MS + 1))
    }

    @Test
    fun grantIsValidUntilItsExpiry() {
        val snap = snapshot(KEY_GRANTS to "com.tiktok:5000")

        assertTrue(snap.hasGrant("com.tiktok", 4_999L))
        assertFalse(snap.hasGrant("com.tiktok", 5_000L))
        assertFalse(snap.hasGrant("com.other", 0L))
    }

    @Test
    fun hasNoRulesOnlyWhenNothingIsEnforced() {
        assertTrue(snapshot().hasNoRules(0L))
        assertFalse(snapshot(KEY_LIMITS to "com.a:10").hasNoRules(0L))
        assertFalse(snapshot(KEY_BLOCK_UNKNOWN to true).hasNoRules(0L))
        assertFalse(snapshot(KEY_BLOCKED to "*").hasNoRules(0L))
        // Faqat ota-ona ruxsati — cheklov emas.
        assertTrue(snapshot(KEY_GRANTS to "com.a:99999").hasNoRules(0L))
    }

    @Test
    fun reloadTriggersFollowTheVersionContract() {
        assertTrue(EnforcementSnapshot.isReloadTrigger(null, hasVersion = true))
        assertTrue(EnforcementSnapshot.isReloadTrigger(KEY_VERSION, hasVersion = true))
        assertTrue(EnforcementSnapshot.isReloadTrigger(KEY_CHILD_ID, hasVersion = true))
        assertTrue(EnforcementSnapshot.isReloadTrigger(KEY_CLOCK_OFFSET_MS, hasVersion = true))
        // Yangi Dart: alohida kalitlar versiya yozilguncha e'tiborsiz (atomarlik).
        assertFalse(EnforcementSnapshot.isReloadTrigger(KEY_BLOCKED, hasVersion = true))
        // Eski Dart: har qanday cheklov kaliti.
        assertTrue(EnforcementSnapshot.isReloadTrigger(KEY_BLOCKED, hasVersion = false))
        assertFalse(EnforcementSnapshot.isReloadTrigger("flutter.restriction.i18n.ok", hasVersion = false))
        assertFalse(EnforcementSnapshot.isReloadTrigger("flutter.restriction.plan_cache", hasVersion = false))
    }
}
