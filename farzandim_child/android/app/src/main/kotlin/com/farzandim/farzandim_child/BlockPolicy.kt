package com.farzandim.farzandim_child

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.util.Log
import android.view.inputmethod.InputMethodManager

/**
 * Bloklash QARORINI beruvchi umumiy, HOLATSIZ yordamchi.
 *
 * Nega alohida `object`: [RestrictionService] oddiy `Service` va butun holati
 * `private` — yangi [BlockAccessibilityService] undan hech narsani meros ola
 * olmaydi. Prefs kalitlari bu yerga KO'CHIRILDI emas, NUSXALANDI: shu tufayli
 * bu fayl qo'shilishi mavjud servisga umuman tegmaydi (regressiya xavfi nol).
 *
 * ⚠️ MUHIM CHEKLOVLAR (accessibility callback ILOVA BOSH OQIMIDA ishlaydi):
 *   - Bu yerdan `getTodayUsageMs()` kabi OG'IR ish CHAQIRILMAYDI — u yarim
 *     tundan beri har bir usage hodisasini aylanib chiqadi va butun tizim
 *     UI'sini qotirib qo'yadi. Limit holati [limitExceeded] orqali O(1) o'qiladi
 *     (uni [RestrictionService] o'zining 1s poll'ida yangilaydi).
 *   - O'yin aniqlash (APK ZIP skani) bu yerda YO'Q — u bir marta ANR keltirib
 *     chiqargan va ataylab alohida oqimga chiqarilgan.
 */
object BlockPolicy {

    private const val TAG = "BlockPolicy"

    // ── Prefs (Dart RestrictionsSyncService yozadi) ────────────────────────
    // Dart tomonda kalitlar prefiksisiz yoziladi; shared_preferences plugini
    // saqlashda "flutter." qo'shadi — shuning uchun native shu ko'rinishda
    // o'qiydi (RestrictionService bilan bir xil).
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_BLOCKED = "flutter.restriction.blocked_packages"
    private const val KEY_LIMITS = "flutter.restriction.limits"

    /** Jadval/"hammasini blokla" holati — har qanday foreground bloklanadi. */
    const val WILDCARD = "*"

    /**
     * Kunlik vaqti tugagan paketlar. [RestrictionService] o'zining poll'ida
     * yozadi, accessibility yo'li faqat O(1) o'qiydi (hisoblamaydi).
     */
    @Volatile
    var limitExceeded: Set<String> = emptySet()

    // Tizim paketlari keshi — har hodisada PackageManager so'ramaslik uchun.
    @Volatile private var allowCache: Set<String>? = null
    @Volatile private var allowCacheAt = 0L
    private const val ALLOW_TTL_MS = 5 * 60 * 1000L

    /** Qaror natijasi. */
    enum class Verdict {
        /** Ruxsat — hech narsa qilinmaydi. */
        ALLOW,

        /** To'liq blok (ota-ona/jadval) — overlay + HOME. */
        BLOCK_HARD,

        /** Kunlik vaqt tugagan — overlay (HOME emas, matn boshqacha). */
        BLOCK_LIMIT,
    }

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** Bloklangan paketlar to'plami (`*` ham shu yerda bo'lishi mumkin). */
    fun blockedPackages(ctx: Context): Set<String> {
        return try {
            val raw = prefs(ctx).getString(KEY_BLOCKED, null) ?: return emptySet()
            raw.split(',')
                .mapNotNull { it.trim().ifBlank { null } }
                .toSet()
        } catch (e: Exception) {
            Log.w(TAG, "blockedPackages o'qishda xato: ${e.message}")
            emptySet()
        }
    }

    /** "pkg:daqiqa,pkg:daqiqa" → Map. */
    fun limits(ctx: Context): Map<String, Int> {
        return try {
            val raw = prefs(ctx).getString(KEY_LIMITS, null) ?: return emptyMap()
            if (raw.isBlank()) return emptyMap()
            raw.split(',').mapNotNull { entry ->
                val parts = entry.split(':')
                if (parts.size != 2) return@mapNotNull null
                val pkg = parts[0].trim()
                val min = parts[1].trim().toIntOrNull()
                if (pkg.isBlank() || min == null) null else pkg to min
            }.toMap()
        } catch (e: Exception) {
            Log.w(TAG, "limits o'qishda xato: ${e.message}")
            emptyMap()
        }
    }

    /**
     * HECH QACHON bloklanmaydigan paketlar: o'zimiz, launcher(lar), tizim UI,
     * faol klaviatura, Sozlamalar va o'rnatuvchi.
     *
     * Sozlamalar (`com.android.settings`) ataylab ochiq qoldirilgan: aks holda
     * bola (VA OTA-ONA) qurilmani tiklay olmaydigan holatga tushib qolishi
     * mumkin — bu qo'llab-quvvatlash uchun tuzatib bo'lmas "g'isht".
     */
    fun alwaysAllow(ctx: Context): Set<String> {
        val now = System.currentTimeMillis()
        allowCache?.let { if (now - allowCacheAt < ALLOW_TTL_MS) return it }

        val out = HashSet<String>()
        out += ctx.packageName
        out += "com.android.systemui"
        out += "com.android.settings"

        val pm = ctx.packageManager
        try {
            // Barcha launcher'lar (bir nechta bo'lishi mumkin).
            val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            pm.queryIntentActivities(home, PackageManager.MATCH_DEFAULT_ONLY)
                .forEach { out += it.activityInfo.packageName }
            pm.resolveActivity(home, PackageManager.MATCH_DEFAULT_ONLY)
                ?.activityInfo?.packageName?.let { out += it }
        } catch (e: Exception) {
            Log.w(TAG, "launcher aniqlanmadi: ${e.message}")
        }

        try {
            // Faol klaviatura — bloklansa matn kirita olmay qoladi.
            val imm = ctx.getSystemService(Context.INPUT_METHOD_SERVICE)
                as? InputMethodManager
            imm?.enabledInputMethodList?.forEach { out += it.packageName }
        } catch (e: Exception) {
            Log.w(TAG, "IME aniqlanmadi: ${e.message}")
        }

        try {
            // Paket o'rnatuvchi (Play) — yangilanish/o'rnatish oqimi buzilmasin.
            val installer = Intent(Intent.ACTION_INSTALL_PACKAGE)
            pm.queryIntentActivities(installer, 0)
                .forEach { out += it.activityInfo.packageName }
        } catch (e: Exception) {
            Log.w(TAG, "installer aniqlanmadi: ${e.message}")
        }

        allowCache = out
        allowCacheAt = now
        return out
    }

    /**
     * Paket uchun qaror. Bu yerda FAQAT arzon o'qishlar bor — accessibility
     * callback'idan chaqirish xavfsiz.
     *
     * ⚠️ `*` (wildcard) bu yerda QASDDAN [Verdict.ALLOW] beradi. Sababi:
     * wildcard "har qanday foreground bloklansin" degani; agar accessibility
     * yo'li unga HOME bossa — HOME launcher'ni ochadi → launcher yangi
     * window-state hodisasi beradi → yana bloklanadi → CHEKSIZ HOME sikli,
     * qurilma umuman ishlatib bo'lmas holga keladi (va o'chirish taqiqlangani
     * uchun tiklab ham bo'lmaydi). Wildcard rejimida faqat overlay ishlaydi —
     * ya'ni bugungi xulq o'zgarmaydi.
     */
    fun decide(ctx: Context, pkg: String): Verdict {
        if (pkg.isBlank()) return Verdict.ALLOW
        if (pkg in alwaysAllow(ctx)) return Verdict.ALLOW

        val blocked = blockedPackages(ctx)
        if (pkg in blocked) return Verdict.BLOCK_HARD
        if (pkg in limitExceeded) return Verdict.BLOCK_LIMIT

        return Verdict.ALLOW
    }
}
