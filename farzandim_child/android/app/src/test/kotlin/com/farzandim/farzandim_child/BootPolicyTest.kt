package com.farzandim.farzandim_child

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BootPolicyTest {
    @Test
    fun `boot and quickboot actions map to boot`() {
        assertEquals(
            BootPolicy.Trigger.BOOT,
            BootPolicy.triggerOf("android.intent.action.BOOT_COMPLETED"),
        )
        assertEquals(
            BootPolicy.Trigger.BOOT,
            BootPolicy.triggerOf("android.intent.action.QUICKBOOT_POWERON"),
        )
    }

    @Test
    fun `package replaced and watchdog actions are recognised`() {
        assertEquals(
            BootPolicy.Trigger.PACKAGE_REPLACED,
            BootPolicy.triggerOf("android.intent.action.MY_PACKAGE_REPLACED"),
        )
        assertEquals(
            BootPolicy.Trigger.WATCHDOG,
            BootPolicy.triggerOf(RestrictionService.ACTION_WATCHDOG),
        )
    }

    @Test
    fun `unknown and missing actions are ignored`() {
        assertEquals(BootPolicy.Trigger.IGNORED, BootPolicy.triggerOf(null))
        assertEquals(BootPolicy.Trigger.IGNORED, BootPolicy.triggerOf("android.intent.action.SCREEN_ON"))
    }

    @Test
    fun `plugin auto run covers boot only when enabled`() {
        assertTrue(BootPolicy.pluginAutoRunCovers(BootPolicy.Trigger.BOOT, true, false))
        assertFalse(BootPolicy.pluginAutoRunCovers(BootPolicy.Trigger.BOOT, false, true))
    }

    @Test
    fun `plugin auto run covers package replaced only when enabled`() {
        assertTrue(BootPolicy.pluginAutoRunCovers(BootPolicy.Trigger.PACKAGE_REPLACED, false, true))
        assertFalse(BootPolicy.pluginAutoRunCovers(BootPolicy.Trigger.PACKAGE_REPLACED, true, false))
    }

    @Test
    fun `plugin never covers the watchdog tick`() {
        assertFalse(BootPolicy.pluginAutoRunCovers(BootPolicy.Trigger.WATCHDOG, true, true))
        assertFalse(BootPolicy.pluginAutoRunCovers(BootPolicy.Trigger.IGNORED, true, true))
    }

    @Test
    fun `pairing requires a non blank child id`() {
        assertTrue(BootPolicy.isPairedValue("c-123"))
        assertFalse(BootPolicy.isPairedValue(null))
        assertFalse(BootPolicy.isPairedValue(""))
        assertFalse(BootPolicy.isPairedValue("   "))
    }

    @Test
    fun `tick message matches the dart contract`() {
        assertEquals("parvoz:tick", BootPolicy.TICK_MESSAGE)
    }
}
