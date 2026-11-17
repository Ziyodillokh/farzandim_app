package com.farzandim.farzandim_child

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log

/**
 * OEM "avtomatik ishga tushish" va fon/batareya sozlamalari
 * (kill-native-no-oem-autostart).
 *
 * MIUI/HyperOS, Tecno/Infinix (HiOS/XOS), Honor/Huawei, ColorOS (Oppo/Realme/
 * OnePlus), Vivo va Samsung AOSP batareya ruxsatidan TASHQARI o'z taqiqini
 * qo'yadi: u o'chiq bo'lsa yopilgan Parvoz boot, alarm (watchdog) va FCM
 * orqali qayta tusha olmaydi — bloklash to'xtaydi, ota-ona "oflayn" ko'radi.
 * Tizim bu sozlama holatini aytmaydi; biz faqat to'g'ri ekranni ochamiz.
 *
 * Har nomzod avval resolve qilinadi (mavjud + exported), keyin try/catch bilan
 * ochiladi; hech biri ochilmasa — ilova ma'lumotlari ekrani (AOSP fallback).
 * Paket ko'rinishi: manifestda QUERY_ALL_PACKAGES bor.
 */
internal object OemBackgroundHelper {
    private const val TAG = "OemBackgroundHelper"
    private const val EXTRA_PACKAGE_NAME = "package_name"
    private const val EXTRA_PACKAGE_LABEL = "package_label"

    /** Dart `info` javobi (kanal: farzandim/oem_background). */
    fun info(ctx: Context): Map<String, Any> =
        mapOf(
            "manufacturer" to Build.MANUFACTURER.orEmpty(),
            "brand" to Build.BRAND.orEmpty(),
            "hasAutostartScreen" to hasAutostartScreen(ctx),
            "ignoringBatteryOptimizations" to isIgnoringBatteryOptimizations(ctx),
        )

    fun hasAutostartScreen(ctx: Context): Boolean =
        OemScreens.autostart(family()).any { canLaunch(ctx, buildIntent(ctx, it)) }

    /** @return true — vendor ekrani yoki fallback (ilova ma'lumotlari) ochildi. */
    fun openAutostart(activity: Activity): Boolean =
        openFirst(activity, OemScreens.autostart(family())) || openAppDetails(activity)

    /**
     * Vendor batareya/fon ekrani (MIUI "Cheklovsiz", Vivo "Yuqori fon sarfi",
     * Samsung batareya...). Bo'lmasa — AOSP "optimallashtirishni o'chirish"
     * dialogi (hali yoqilmagan bo'lsa), oxirida ilova ma'lumotlari ekrani.
     */
    @SuppressLint("BatteryLife")
    fun openBatterySettings(activity: Activity): Boolean {
        if (openFirst(activity, OemScreens.battery(family()))) return true
        if (!isIgnoringBatteryOptimizations(activity)) {
            val request = Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                packageUri(activity),
            )
            if (startIfResolvable(activity, request, "battery-request")) return true
        }
        return openAppDetails(activity)
    }

    fun isIgnoringBatteryOptimizations(ctx: Context): Boolean =
        try {
            val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.isIgnoringBatteryOptimizations(ctx.packageName)
        } catch (e: Exception) {
            false
        }

    private fun family(): OemFamily = OemScreens.familyOf(Build.MANUFACTURER, Build.BRAND)

    private fun openFirst(ctx: Context, screens: List<OemScreen>): Boolean {
        for (screen in screens) {
            val intent = buildIntent(ctx, screen)
            if (canLaunch(ctx, intent) && startSafely(ctx, intent, screen.className)) return true
        }
        return false
    }

    private fun buildIntent(ctx: Context, screen: OemScreen): Intent =
        Intent().apply {
            component = ComponentName(screen.packageName, screen.className)
            if (screen.passPackage) {
                putExtra(EXTRA_PACKAGE_NAME, ctx.packageName)
                putExtra(EXTRA_PACKAGE_LABEL, appLabel(ctx))
            }
        }

    /** Komponent mavjud, exported va (bo'lsa) ruxsati bizda bor. */
    private fun canLaunch(ctx: Context, intent: Intent): Boolean {
        return try {
            val info = intent.resolveActivityInfo(ctx.packageManager, 0) ?: return false
            val permission = info.permission
            info.exported &&
                (
                    permission == null ||
                        ctx.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
                    )
        } catch (e: Exception) {
            false
        }
    }

    private fun startIfResolvable(ctx: Context, intent: Intent, label: String): Boolean {
        val resolvable = try {
            intent.resolveActivity(ctx.packageManager) != null
        } catch (e: Exception) {
            false
        }
        return resolvable && startSafely(ctx, intent, label)
    }

    private fun openAppDetails(ctx: Context): Boolean =
        startSafely(
            ctx,
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri(ctx)),
            "app-details",
        )

    private fun startSafely(ctx: Context, intent: Intent, label: String): Boolean =
        try {
            if (ctx !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.w(TAG, "Ochilmadi: $label", e)
            false
        }

    private fun packageUri(ctx: Context): Uri = Uri.fromParts("package", ctx.packageName, null)

    private fun appLabel(ctx: Context): String =
        try {
            ctx.applicationInfo.loadLabel(ctx.packageManager).toString()
        } catch (e: Exception) {
            "Parvoz"
        }
}

/** OEM oilasi — sozlama ekranlari shu bo'yicha tanlanadi. */
internal enum class OemFamily {
    XIAOMI, HONOR, HUAWEI, OPPO, VIVO, TRANSSION, SAMSUNG, ASUS, LETV, NOKIA, OTHER,
}

/**
 * Vendor sozlama ekrani. Pure (ComponentName faqat ochishda quriladi) — JVM
 * testda Android'siz tekshiriladi.
 * @param passPackage MIUI powerkeeper `package_name`/`package_label` extra'larini kutadi.
 */
internal data class OemScreen(
    val packageName: String,
    val className: String,
    val passPackage: Boolean = false,
)

/** Ishlab chiqaruvchi → tartiblangan nomzod ekranlar jadvali (pure). */
internal object OemScreens {
    private val NON_ALNUM = Regex("[^a-z0-9]+")

    // Tartib muhim: HONOR HUAWEI'dan oldin (eski Honor: manufacturer=HUAWEI,
    // brand=HONOR — Honor ro'yxati eski Huawei ekranlarini ham o'z ichiga oladi).
    private val FAMILY_TOKENS: List<Pair<OemFamily, Set<String>>> = listOf(
        OemFamily.XIAOMI to setOf("xiaomi", "redmi", "poco"),
        OemFamily.HONOR to setOf("honor"),
        OemFamily.HUAWEI to setOf("huawei"),
        OemFamily.OPPO to setOf("oppo", "realme", "oneplus"),
        OemFamily.VIVO to setOf("vivo", "iqoo"),
        OemFamily.TRANSSION to setOf("tecno", "infinix", "itel", "transsion"),
        OemFamily.SAMSUNG to setOf("samsung"),
        OemFamily.ASUS to setOf("asus"),
        OemFamily.LETV to setOf("letv", "leeco", "lemobile"),
        OemFamily.NOKIA to setOf("nokia", "hmd"),
    )

    private val HUAWEI_STARTUP = listOf(
        // EMUI 9+ / HarmonyOS — "Ilovalarni ishga tushirish".
        OemScreen(
            "com.huawei.systemmanager",
            "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
        ),
        // EMUI 8.
        OemScreen(
            "com.huawei.systemmanager",
            "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity",
        ),
        // EMUI 5 va eski — "Himoyalangan ilovalar".
        OemScreen(
            "com.huawei.systemmanager",
            "com.huawei.systemmanager.optimize.process.ProtectActivity",
        ),
    )

    fun familyOf(manufacturer: String?, brand: String?): OemFamily {
        val tokens = tokensOf(manufacturer) + tokensOf(brand)
        return FAMILY_TOKENS.firstOrNull { (_, names) -> names.any { it in tokens } }?.first
            ?: OemFamily.OTHER
    }

    /** "Avtomatik ishga tushish" ekranlari (birinchi ochilgani ishlatiladi). */
    fun autostart(family: OemFamily): List<OemScreen> =
        when (family) {
            OemFamily.XIAOMI -> listOf(
                OemScreen(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity",
                ),
            )
            OemFamily.HONOR -> listOf(
                OemScreen(
                    "com.hihonor.systemmanager",
                    "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                ),
            ) + HUAWEI_STARTUP
            OemFamily.HUAWEI -> HUAWEI_STARTUP
            OemFamily.OPPO -> listOf(
                OemScreen(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                ),
                OemScreen(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.startupapp.StartupAppListActivity",
                ),
                OemScreen(
                    "com.oplus.safecenter",
                    "com.oplus.safecenter.permission.startup.StartupAppListActivity",
                ),
                OemScreen(
                    "com.oplus.safecenter",
                    "com.oplus.safecenter.startupapp.StartupAppListActivity",
                ),
                OemScreen(
                    "com.oppo.safe",
                    "com.oppo.safe.permission.startup.StartupAppListActivity",
                ),
                OemScreen(
                    "com.oneplus.security",
                    "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
                ),
            )
            OemFamily.VIVO -> listOf(
                OemScreen(
                    "com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                ),
                OemScreen(
                    "com.iqoo.secure",
                    "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
                ),
                OemScreen(
                    "com.iqoo.secure",
                    "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
                ),
            )
            OemFamily.TRANSSION -> listOf(
                OemScreen(
                    "com.transsion.phonemaster",
                    "com.cyin.himgr.autostart.AutoStartActivity",
                ),
            )
            OemFamily.ASUS -> listOf(
                OemScreen(
                    "com.asus.mobilemanager",
                    "com.asus.mobilemanager.autostart.AutoStartActivity",
                ),
                OemScreen("com.asus.mobilemanager", "com.asus.mobilemanager.MainActivity"),
            )
            OemFamily.LETV -> listOf(
                OemScreen(
                    "com.letv.android.letvsafe",
                    "com.letv.android.letvsafe.AutobootManageActivity",
                ),
            )
            // Samsung/Nokia'da alohida avtostart ekrani yo'q (batareya ekrani bor).
            OemFamily.SAMSUNG, OemFamily.NOKIA, OemFamily.OTHER -> emptyList()
        }

    /** Batareya / fon faolligi ekranlari (birinchi ochilgani ishlatiladi). */
    fun battery(family: OemFamily): List<OemScreen> =
        when (family) {
            // MIUI "Batareya tejash → Cheklovsiz" — paket extra'lari bilan
            // to'g'ridan-to'g'ri shu ilova sahifasi ochiladi.
            OemFamily.XIAOMI -> listOf(
                OemScreen(
                    "com.miui.powerkeeper",
                    "com.miui.powerkeeper.ui.HiddenAppsConfigActivity",
                    passPackage = true,
                ),
            )
            OemFamily.HUAWEI, OemFamily.HONOR -> listOf(
                OemScreen(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.power.ui.HwPowerManagerActivity",
                ),
            )
            // Vivo "Yuqori fon quvvat sarfi".
            OemFamily.VIVO -> listOf(
                OemScreen(
                    "com.vivo.abe",
                    "com.vivo.applicationbehaviorengine.ui.ExcessivePowerManagerActivity",
                ),
                OemScreen("com.iqoo.powersaving", "com.iqoo.powersaving.PowerSavingManagerActivity"),
            )
            // Samsung "Qurilma parvarishi → Batareya" (uxlamaydigan ilovalar shu yerda).
            OemFamily.SAMSUNG -> listOf(
                OemScreen(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.battery.ui.BatteryActivity",
                ),
                OemScreen(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.ui.battery.BatteryActivity",
                ),
            )
            OemFamily.ASUS -> listOf(
                OemScreen(
                    "com.asus.mobilemanager",
                    "com.asus.mobilemanager.powersaver.PowerSaverSettings",
                ),
            )
            OemFamily.LETV -> listOf(
                OemScreen(
                    "com.letv.android.letvsafe",
                    "com.letv.android.letvsafe.BackgroundAppManageActivity",
                ),
            )
            OemFamily.NOKIA -> listOf(
                OemScreen(
                    "com.evenwell.powersaving.g3",
                    "com.evenwell.powersaving.g3.exception.PowerSaverExceptionActivity",
                ),
            )
            // ColorOS / HiOS: fon faolligi "Ilova ma'lumotlari → Batareya" ichida
            // (AOSP fallback aynan o'sha sahifani ochadi).
            OemFamily.OPPO, OemFamily.TRANSSION, OemFamily.OTHER -> emptyList()
        }

    private fun tokensOf(value: String?): Set<String> =
        value.orEmpty().lowercase().split(NON_ALNUM).filter { it.isNotEmpty() }.toSet()
}
