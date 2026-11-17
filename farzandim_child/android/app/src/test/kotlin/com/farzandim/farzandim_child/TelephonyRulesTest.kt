package com.farzandim.farzandim_child

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TelephonyRulesTest {

    @Test
    fun allowSetContainsDialersAndKnownCallPackages() {
        val set = TelephonyRules.allowSet(
            defaultDialer = "com.truecaller",
            systemDialer = "com.samsung.android.dialer",
            systemDialHandlers = listOf("com.samsung.android.dialer", "com.android.contacts", " "),
        )

        assertTrue(set.containsAll(TelephonyRules.KNOWN_PACKAGES))
        assertTrue("com.truecaller" in set)
        assertTrue("com.samsung.android.dialer" in set)
        assertTrue("com.android.contacts" in set)
        assertFalse(" " in set)
    }

    @Test
    fun missingDialersAreIgnored() {
        val set = TelephonyRules.allowSet(null, "", emptyList())

        assertEquals(TelephonyRules.KNOWN_PACKAGES, set)
    }

    @Test
    fun cellularCallAlwaysSuppressesTheOverlay() {
        assertTrue(TelephonyRules.suppressOverlay(TelephonyRules.MODE_RINGTONE))
        assertTrue(TelephonyRules.suppressOverlay(TelephonyRules.MODE_IN_CALL))
        assertTrue(TelephonyRules.suppressOverlay(TelephonyRules.MODE_CALL_SCREENING))
        assertTrue(TelephonyRules.suppressOverlay(TelephonyRules.MODE_CALL_REDIRECT))
    }

    @Test
    fun voipNeverLiftsBlocksForOtherApps() {
        // Audio rejimi butun qurilmaniki: Telegram/Discord ovozli chati yoki
        // brauzer WebRTC'si yoqsa ham dars/uyqu bloki boshqa ilovalarda qoladi.
        assertFalse(TelephonyRules.suppressOverlay(TelephonyRules.MODE_IN_COMMUNICATION))
        assertFalse(TelephonyRules.suppressOverlay(TelephonyRules.MODE_COMMUNICATION_REDIRECT))
    }

    @Test
    fun normalModeNeverSuppresses() {
        assertFalse(TelephonyRules.suppressOverlay(TelephonyRules.MODE_NORMAL))
        assertFalse(TelephonyRules.suppressOverlay(-2 /* MODE_INVALID */))
    }
}
