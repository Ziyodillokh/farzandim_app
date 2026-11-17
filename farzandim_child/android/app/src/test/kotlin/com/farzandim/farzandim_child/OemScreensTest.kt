package com.farzandim.farzandim_child

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OemScreensTest {
    @Test
    fun `xiaomi redmi and poco map to xiaomi family`() {
        assertEquals(OemFamily.XIAOMI, OemScreens.familyOf("Xiaomi", "Xiaomi"))
        assertEquals(OemFamily.XIAOMI, OemScreens.familyOf("Xiaomi", "Redmi"))
        assertEquals(OemFamily.XIAOMI, OemScreens.familyOf("Xiaomi", "POCO"))
    }

    @Test
    fun `honor brand wins over huawei manufacturer`() {
        assertEquals(OemFamily.HONOR, OemScreens.familyOf("HUAWEI", "HONOR"))
        assertEquals(OemFamily.HONOR, OemScreens.familyOf("HONOR", "HONOR"))
        assertEquals(OemFamily.HUAWEI, OemScreens.familyOf("HUAWEI", "HUAWEI"))
    }

    @Test
    fun `transsion brands are detected from long manufacturer names`() {
        assertEquals(OemFamily.TRANSSION, OemScreens.familyOf("TECNO MOBILE LIMITED", "TECNO"))
        assertEquals(OemFamily.TRANSSION, OemScreens.familyOf("INFINIX MOBILITY LIMITED", "Infinix"))
        assertEquals(OemFamily.TRANSSION, OemScreens.familyOf("ITEL", "itel"))
    }

    @Test
    fun `token matching does not confuse intel with itel`() {
        assertEquals(OemFamily.OTHER, OemScreens.familyOf("Intel", "intel"))
    }

    @Test
    fun `oppo realme and oneplus share the coloros family`() {
        assertEquals(OemFamily.OPPO, OemScreens.familyOf("OPPO", "OPPO"))
        assertEquals(OemFamily.OPPO, OemScreens.familyOf("realme", "realme"))
        assertEquals(OemFamily.OPPO, OemScreens.familyOf("OnePlus", "OnePlus"))
    }

    @Test
    fun `vivo iqoo samsung and nokia are detected`() {
        assertEquals(OemFamily.VIVO, OemScreens.familyOf("vivo", "iQOO"))
        assertEquals(OemFamily.SAMSUNG, OemScreens.familyOf("samsung", "samsung"))
        assertEquals(OemFamily.NOKIA, OemScreens.familyOf("HMD Global", "Nokia"))
    }

    @Test
    fun `unknown or missing vendor has no screens`() {
        assertEquals(OemFamily.OTHER, OemScreens.familyOf("Google", "google"))
        assertEquals(OemFamily.OTHER, OemScreens.familyOf(null, null))
        assertTrue(OemScreens.autostart(OemFamily.OTHER).isEmpty())
        assertTrue(OemScreens.battery(OemFamily.OTHER).isEmpty())
    }

    @Test
    fun `xiaomi autostart opens the miui autostart manager first`() {
        val first = OemScreens.autostart(OemFamily.XIAOMI).first()
        assertEquals("com.miui.securitycenter", first.packageName)
        assertEquals("com.miui.permcenter.autostart.AutoStartManagementActivity", first.className)
    }

    @Test
    fun `xiaomi battery screen passes package extras`() {
        val screen = OemScreens.battery(OemFamily.XIAOMI).first()
        assertEquals("com.miui.powerkeeper", screen.packageName)
        assertTrue(screen.passPackage)
    }

    @Test
    fun `honor tries the new honor manager before legacy huawei screens`() {
        val screens = OemScreens.autostart(OemFamily.HONOR)
        assertEquals("com.hihonor.systemmanager", screens.first().packageName)
        assertTrue(screens.drop(1).all { it.packageName == "com.huawei.systemmanager" })
    }

    @Test
    fun `coloros list covers both coloros and oplus safecenter`() {
        val packages = OemScreens.autostart(OemFamily.OPPO).map { it.packageName }.toSet()
        assertTrue("com.coloros.safecenter" in packages)
        assertTrue("com.oplus.safecenter" in packages)
    }

    @Test
    fun `transsion autostart uses phone master`() {
        val first = OemScreens.autostart(OemFamily.TRANSSION).first()
        assertEquals("com.transsion.phonemaster", first.packageName)
        assertEquals("com.cyin.himgr.autostart.AutoStartActivity", first.className)
    }

    @Test
    fun `samsung has battery screens but no autostart screen`() {
        assertTrue(OemScreens.autostart(OemFamily.SAMSUNG).isEmpty())
        assertFalse(OemScreens.battery(OemFamily.SAMSUNG).isEmpty())
    }

    @Test
    fun `every candidate is a fully qualified component`() {
        val all = OemFamily.values().flatMap {
            OemScreens.autostart(it) + OemScreens.battery(it)
        }
        assertFalse(all.isEmpty())
        for (screen in all) {
            assertTrue(screen.packageName, screen.packageName.count { it == '.' } >= 2)
            assertTrue(screen.className, screen.className.count { it == '.' } >= 2)
        }
    }

    @Test
    fun `only the miui powerkeeper screen needs package extras`() {
        val withExtras = OemFamily.values()
            .flatMap { OemScreens.autostart(it) + OemScreens.battery(it) }
            .filter { it.passPackage }
            .map { it.packageName }
            .toSet()
        assertEquals(setOf("com.miui.powerkeeper"), withExtras)
    }
}
