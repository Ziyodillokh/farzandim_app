package com.farzandim.farzandim_child

import android.content.Context
import android.content.pm.ApplicationInfo
import android.util.Log

/**
 * Paket haqidagi keshlangan ma'lumot: o'rnatish manbasi, maktab toifasi,
 * ilova nomi. Faqat poll oqimidan ishlatiladi.
 */
internal class AppInfoLookup(ctx: Context) {

    companion object {
        private const val TAG = "AppInfoLookup"

        /**
         * Ruxsat etilgan o'rnatuvchilar (rasmiy do'konlar) — bulardan
         * o'rnatilgan ilovalar "notanish manba" sifatida bloklanmaydi.
         * Faqat paket nomi aniq tasdiqlangan do'konlar.
         */
        val ALLOWED_INSTALLERS: Set<String> = setOf(
            "com.android.vending", // Google Play
            "com.google.android.feedback", // Play (ba'zi qurilmalar)
            "com.sec.android.app.samsungapps", // Samsung Galaxy Store
            "com.huawei.appmarket", // Huawei AppGallery
            "com.hihonor.appmarket", // Honor App Market (Huawei'dan ajralgach)
            "com.amazon.venezia", // Amazon Appstore
            "com.xiaomi.market", // Xiaomi GetApps (Xitoy / eski MIUI)
            "com.xiaomi.mipicks", // Xiaomi GetApps (global)
            "com.heytap.market", // OPPO / realme / OnePlus App Market (ColorOS 7+)
            "com.oppo.market", // OPPO App Market (eski ColorOS)
            "com.bbk.appstore", // vivo V-Appstore
            "com.vivo.appstore", // vivo (eski ro'yxatdan — zararsiz qoldirildi)
        )

        private val WHITESPACE = Regex("\\s+")
    }

    private val pm = ctx.packageManager
    private val unknownSourceCache = HashMap<String, Boolean>()
    private val categoryCache = HashMap<String, String>()
    private val labelKeyCache = HashMap<String, String>()
    private val labelCache = HashMap<String, String>()

    /**
     * Ilova "notanish manba"danmi (Play/rasmiy do'kon emas)?
     *  - Tizim/oldindan o'rnatilgan ilovalar → yo'q.
     *  - Rasmiy do'kondan ([ALLOWED_INSTALLERS]) → yo'q.
     *  - Aks holda (sideload APK / null) → ha.
     * Aniqlay olmasak — bloklamaymiz (false-positive xavfi) va keshlamaymiz.
     */
    fun isUnknownSource(pkg: String): Boolean {
        unknownSourceCache[pkg]?.let { return it }
        return try {
            val ai = pm.getApplicationInfo(pkg, 0)
            val isSystem = (ai.flags and
                (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP)) != 0
            val unknown = if (isSystem) {
                false
            } else {
                val installer = installerOf(pkg)
                installer == null || installer !in ALLOWED_INSTALLERS
            }
            Log.d(TAG, "install-source: $pkg unknown=$unknown")
            unknownSourceCache[pkg] = unknown
            unknown
        } catch (e: Exception) {
            Log.w(TAG, "install-source aniqlanmadi: $pkg — ${e.message}")
            false
        }
    }

    private fun installerOf(pkg: String): String? =
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            pm.getInstallSourceInfo(pkg).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            pm.getInstallerPackageName(pkg)
        }

    /**
     * Server toifasi bilan bir xil ("GAME" / "SOCIAL" / "VIDEO") yoki null.
     * Tizim ilovalari — null. O'yin: manifest kategoriyasi, FLAG_IS_GAME yoki
     * o'yin engine'i ([knownGame] — fon oqimida hisoblanadi; hali noma'lum
     * (null) bo'lsa natija keshlanmaydi, keyingi tick'da qayta tekshiriladi).
     */
    fun schoolCategoryOf(pkg: String, knownGame: Boolean?): String? {
        categoryCache[pkg]?.let { return it.ifEmpty { null } }
        val category = try {
            val ai = pm.getApplicationInfo(pkg, 0)
            @Suppress("DEPRECATION")
            val gameFlag = (ai.flags and ApplicationInfo.FLAG_IS_GAME) != 0
            when {
                (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0 -> ""
                knownGame == true || gameFlag ||
                    ai.category == ApplicationInfo.CATEGORY_GAME -> "GAME"
                ai.category == ApplicationInfo.CATEGORY_SOCIAL -> "SOCIAL"
                ai.category == ApplicationInfo.CATEGORY_VIDEO -> "VIDEO"
                else -> ""
            }
        } catch (e: Exception) {
            ""
        }
        if (category.isNotEmpty() || knownGame != null) categoryCache[pkg] = category
        return category.ifEmpty { null }
    }

    /** Ilova nomi solishtirish uchun (kichik harf, bo'shliqlar yig'ilgan). */
    fun labelKey(pkg: String): String {
        labelKeyCache[pkg]?.let { return it }
        val name = label(pkg)
        // Nom topilmadi (vaqtinchalik xato) — "" keshlanmaydi: aks holda maktab
        // nomi bo'yicha ruxsat etgan ilova servis umri davomida bloklanib qolardi.
        if (name == pkg) return ""
        val key = name.trim().lowercase().replace(WHITESPACE, " ")
        labelKeyCache[pkg] = key
        return key
    }

    /** Foydalanuvchiga ko'rinadigan nom (topilmasa — paket nomi). */
    fun label(pkg: String): String {
        labelCache[pkg]?.let { return it }
        return try {
            val name = pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
            labelCache[pkg] = name
            name
        } catch (e: Exception) {
            pkg
        }
    }
}
