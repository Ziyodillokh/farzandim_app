package com.farzandim.farzandim_child

import android.app.ApplicationExitInfo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ExitReasonPolicyTest {
    private fun record(timestamp: Long, reason: Int) =
        ExitRecord(
            timestamp = timestamp,
            reason = reason,
            importance = 125,
            status = 0,
            description = "test",
        )

    @Test
    fun `newSince keeps only records after the last reported time oldest first`() {
        val records = listOf(
            record(300, ApplicationExitInfo.REASON_ANR),
            record(100, ApplicationExitInfo.REASON_CRASH),
            record(200, ApplicationExitInfo.REASON_LOW_MEMORY),
        )

        val fresh = ExitReasonPolicy.newSince(records, lastReportedAt = 100)

        assertEquals(listOf(200L, 300L), fresh.map { it.timestamp })
    }

    @Test
    fun `newSince returns nothing when everything was already reported`() {
        val records = listOf(record(100, ApplicationExitInfo.REASON_CRASH))

        assertTrue(ExitReasonPolicy.newSince(records, lastReportedAt = 100).isEmpty())
    }

    @Test
    fun `crashes anr kills and user stops are recorded as non fatal`() {
        val recorded = listOf(
            ApplicationExitInfo.REASON_CRASH,
            ApplicationExitInfo.REASON_CRASH_NATIVE,
            ApplicationExitInfo.REASON_ANR,
            ApplicationExitInfo.REASON_USER_REQUESTED,
            ApplicationExitInfo.REASON_USER_STOPPED,
            ApplicationExitInfo.REASON_OTHER,
            ApplicationExitInfo.REASON_SIGNALED,
            ApplicationExitInfo.REASON_LOW_MEMORY,
            ApplicationExitInfo.REASON_PERMISSION_CHANGE,
            ApplicationExitInfo.REASON_FREEZER,
            ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE,
        )
        for (reason in recorded) {
            assertTrue("reason=$reason", ExitReasonPolicy.shouldRecordNonFatal(reason))
        }
    }

    @Test
    fun `normal exits and package updates are not recorded`() {
        val ignored = listOf(
            ApplicationExitInfo.REASON_UNKNOWN,
            ApplicationExitInfo.REASON_EXIT_SELF,
            ApplicationExitInfo.REASON_DEPENDENCY_DIED,
            ApplicationExitInfo.REASON_PACKAGE_UPDATED,
            ApplicationExitInfo.REASON_PACKAGE_STATE_CHANGE,
        )
        for (reason in ignored) {
            assertFalse("reason=$reason", ExitReasonPolicy.shouldRecordNonFatal(reason))
        }
    }

    @Test
    fun `non fatal candidates are filtered and newest first`() {
        val fresh = listOf(
            record(100, ApplicationExitInfo.REASON_LOW_MEMORY),
            record(200, ApplicationExitInfo.REASON_EXIT_SELF),
            record(300, ApplicationExitInfo.REASON_CRASH),
        )

        val candidates = ExitReasonPolicy.nonFatalCandidates(fresh)

        assertEquals(listOf(300L, 100L), candidates.map { it.timestamp })
    }

    @Test
    fun `reason names are readable and unknown codes fall back`() {
        assertEquals("ANR", ExitReasonPolicy.reasonName(ApplicationExitInfo.REASON_ANR))
        assertEquals("USER_STOPPED", ExitReasonPolicy.reasonName(ApplicationExitInfo.REASON_USER_STOPPED))
        assertEquals("FREEZER", ExitReasonPolicy.reasonName(ApplicationExitInfo.REASON_FREEZER))
        assertEquals("REASON_99", ExitReasonPolicy.reasonName(99))
    }

    @Test
    fun `describe trims long system descriptions`() {
        val long = record(1, ApplicationExitInfo.REASON_OTHER).copy(description = "x".repeat(1000))

        val text = ExitReasonPolicy.describe(long)

        assertTrue(text.startsWith("Process exit OTHER"))
        assertTrue(text.length < 400)
    }

    @Test
    fun `daily budget resets on a new day and caps the same day`() {
        assertEquals(0, NonFatalBudget.usedToday(savedDay = 10, savedCount = 7, today = 11))
        assertEquals(7, NonFatalBudget.usedToday(savedDay = 11, savedCount = 7, today = 11))
        assertTrue(NonFatalBudget.allows(usedToday = NonFatalBudget.MAX_PER_DAY - 1))
        assertFalse(NonFatalBudget.allows(usedToday = NonFatalBudget.MAX_PER_DAY))
    }
}
