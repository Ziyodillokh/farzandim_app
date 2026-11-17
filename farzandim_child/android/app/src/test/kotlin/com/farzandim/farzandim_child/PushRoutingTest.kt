package com.farzandim.farzandim_child

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PushRoutingTest {
    @Test
    fun `restrictions sync and unlock decision trigger a restrictions sync`() {
        assertEquals("parvoz:restrictions_sync", PushRouting.triggerFor("restrictions_sync"))
        assertEquals("parvoz:restrictions_sync", PushRouting.triggerFor("unlock_decision"))
    }

    @Test
    fun `location wake triggers a location wake`() {
        assertEquals("parvoz:location_wake", PushRouting.triggerFor("location_wake"))
    }

    @Test
    fun `ring and other types are not forwarded to the task`() {
        assertNull(PushRouting.triggerFor("ring"))
        assertNull(PushRouting.triggerFor("voice_message"))
        assertNull(PushRouting.triggerFor(null))
    }

    @Test
    fun `task types reach flutter only while the ui is visible`() {
        assertTrue(PushRouting.passToFlutter("restrictions_sync", isUiVisible = true))
        assertFalse(PushRouting.passToFlutter("restrictions_sync", isUiVisible = false))
        assertFalse(PushRouting.passToFlutter("unlock_decision", isUiVisible = false))
        assertFalse(PushRouting.passToFlutter("location_wake", isUiVisible = false))
    }

    @Test
    fun `other types always reach flutter as before`() {
        assertTrue(PushRouting.passToFlutter("voice_message", isUiVisible = false))
        assertTrue(PushRouting.passToFlutter(null, isUiVisible = false))
    }
}
