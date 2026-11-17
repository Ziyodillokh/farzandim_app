package com.farzandim.farzandim_child

/** Prefs'dan o'qish interfeysi — testda Map bilan almashtiriladi. */
interface PrefsReader {
    fun string(key: String): String?
    fun bool(key: String): Boolean?
    fun long(key: String): Long?
}

/** Maktab (School Mode) bloki — dars vaqti. */
data class SchoolRule(
    val packages: Set<String>,
    val categories: Set<String>,
    /** Ruxsat etilgan ilovalar NOMI (kichik harf, bo'shliqlar yig'ilgan). */
    val allowed: Set<String>,
    /** Overlay matni uchun "HH:MM". */
    val untilLabel: String,
    /** Tugash lahzasi (epoch ms); 0 — noma'lum (eski Dart). */
    val untilMs: Long,
)

/**
 * Dart yozgan cheklovlarning bir lahzalik, o'zgarmas nusxasi
 * (Native ↔ Dart shartnomasi, "Atomic enforcement snapshot").
 *
 * Dart o'zgargan kalitlarni yozib, ENG OXIRIDA `restriction.snapshot_version`
 * ni oshiradi. Native kalitlarni faqat versiya o'zgarganda (va servis
 * startida) qayta o'qiydi — bir lahzada yarim yozilgan holat ko'rinmaydi
 * (fn-nonatomic-restriction-prefs) va har tick'da qayta parse qilinmaydi
 * (bat-native-per-tick-reparse). Eski Dart versiyani yozmaydi — unda har
 * qanday cheklov kaliti o'zgarishida qayta o'qiladi (bugungi xulq).
 *
 * Vaqt qoidalari (fn-native-frozen-prefs, kill-native-enforcement-depends-
 * on-dart): Dart o'lib qolsa ham '*' / dars bloki abadiy qolmasin:
 *  - `valid_until_ms > 0` va hozir > valid_until + 120 s → snapshot eskirgan:
 *    `base_blocked_packages` (to'liq bloklar + "hammasini blokla") qo'llanadi,
 *    maktab bloki e'tiborsiz;
 *  - hozir >= `school_until_ms` → maktab bloki e'tiborsiz.
 *
 * Barcha vaqtlar — ishonchli vaqt ([TrustedClock]).
 */
data class EnforcementSnapshot(
    /** `childId` bor — qurilma juftlangan. */
    val paired: Boolean,
    /** null — eski Dart (snapshot_version yozmaydi). */
    val version: Long?,
    val blocked: Set<String>,
    /** null — kalit yo'q (eski Dart). */
    val baseBlocked: Set<String>?,
    /** paket → daqiqa. */
    val limits: Map<String, Int>,
    val blockUnknown: Boolean,
    val school: SchoolRule?,
    /** 0 — vaqt chegarasi yo'q. */
    val validUntilMs: Long,
    /** paket → ruxsat tugash lahzasi (epoch ms). */
    val grants: Map<String, Long>,
    /** null — noma'lum. */
    val clockOffsetMs: Long?,
) {

    companion object {
        const val WILDCARD = "*"
        const val STALE_GRACE_MS = 120_000L

        // Kalitlar — Dart prefiksisiz yozadi, shared_preferences "flutter."
        // qo'shadi.
        const val KEY_CHILD_ID = "flutter.childId"
        const val KEY_VERSION = "flutter.restriction.snapshot_version"
        const val KEY_BLOCKED = "flutter.restriction.blocked_packages"
        const val KEY_BASE_BLOCKED = "flutter.restriction.base_blocked_packages"
        const val KEY_LIMITS = "flutter.restriction.limits"
        const val KEY_BLOCK_UNKNOWN = "flutter.restriction.block_unknown_sources"
        const val KEY_SCHOOL_PACKAGES = "flutter.restriction.school_packages"
        const val KEY_SCHOOL_CATEGORIES = "flutter.restriction.school_categories"
        const val KEY_SCHOOL_ALLOWED = "flutter.restriction.school_allowed"
        const val KEY_SCHOOL_UNTIL = "flutter.restriction.school_until"
        const val KEY_SCHOOL_UNTIL_MS = "flutter.restriction.school_until_ms"
        const val KEY_VALID_UNTIL_MS = "flutter.restriction.valid_until_ms"
        const val KEY_GRANTS = "flutter.restriction.grants"
        const val KEY_CLOCK_OFFSET_MS = "flutter.restriction.clock_offset_ms"

        /** Eski Dart rejimida (versiyasiz) shu kalitlardan biri o'zgarsa qayta o'qiladi. */
        private val ENFORCEMENT_KEYS = setOf(
            KEY_BLOCKED, KEY_BASE_BLOCKED, KEY_LIMITS, KEY_BLOCK_UNKNOWN,
            KEY_SCHOOL_PACKAGES, KEY_SCHOOL_CATEGORIES, KEY_SCHOOL_ALLOWED,
            KEY_SCHOOL_UNTIL, KEY_SCHOOL_UNTIL_MS, KEY_VALID_UNTIL_MS, KEY_GRANTS,
        )

        /**
         * Prefs o'zgarishi snapshot'ni qayta o'qitishi kerakmi.
         * `key == null` — prefs.clear() (Android 11+).
         * Versiya, juftlash va soat farqi — har doim (Dart soat farqini
         * versiyasiz yozishi mumkin). Qolgan cheklov kalitlari — faqat eski
         * (versiyasiz) Dart bilan.
         */
        fun isReloadTrigger(key: String?, hasVersion: Boolean): Boolean {
            if (key == null) return true
            if (key == KEY_VERSION || key == KEY_CHILD_ID || key == KEY_CLOCK_OFFSET_MS) return true
            return !hasVersion && key in ENFORCEMENT_KEYS
        }

        fun read(prefs: PrefsReader): EnforcementSnapshot {
            val untilLabel = prefs.string(KEY_SCHOOL_UNTIL)?.trim().orEmpty()
            val school = if (untilLabel.isEmpty()) {
                null
            } else {
                SchoolRule(
                    packages = parseList(prefs.string(KEY_SCHOOL_PACKAGES), ','),
                    categories = parseList(prefs.string(KEY_SCHOOL_CATEGORIES), ','),
                    allowed = parseList(prefs.string(KEY_SCHOOL_ALLOWED), '\n'),
                    untilLabel = untilLabel,
                    untilMs = prefs.long(KEY_SCHOOL_UNTIL_MS) ?: 0L,
                )
            }
            return EnforcementSnapshot(
                paired = !prefs.string(KEY_CHILD_ID).isNullOrBlank(),
                version = prefs.long(KEY_VERSION),
                blocked = parseList(prefs.string(KEY_BLOCKED), ','),
                baseBlocked = prefs.string(KEY_BASE_BLOCKED)?.let { parseList(it, ',') },
                limits = parseLimits(prefs.string(KEY_LIMITS)),
                blockUnknown = prefs.bool(KEY_BLOCK_UNKNOWN) ?: false,
                school = school,
                validUntilMs = prefs.long(KEY_VALID_UNTIL_MS) ?: 0L,
                grants = parseGrants(prefs.string(KEY_GRANTS)),
                clockOffsetMs = prefs.long(KEY_CLOCK_OFFSET_MS),
            )
        }

        fun parseList(raw: String?, separator: Char): Set<String> {
            if (raw.isNullOrBlank()) return emptySet()
            return raw.split(separator).mapNotNull { it.trim().ifBlank { null } }.toSet()
        }

        /** "com.youtube:15,com.instagram:30" → {com.youtube=15, com.instagram=30}. */
        fun parseLimits(raw: String?): Map<String, Int> =
            parsePairs(raw) { it.toIntOrNull() }

        /** "pkg:tugashEpochMs,..." → paket → tugash lahzasi. */
        fun parseGrants(raw: String?): Map<String, Long> =
            parsePairs(raw) { it.toLongOrNull() }

        private fun <T> parsePairs(raw: String?, parse: (String) -> T?): Map<String, T> {
            if (raw.isNullOrBlank()) return emptyMap()
            val out = HashMap<String, T>()
            for (entry in raw.split(',')) {
                val parts = entry.split(':')
                if (parts.size != 2) continue
                val pkg = parts[0].trim()
                val value = parse(parts[1].trim()) ?: continue
                if (pkg.isNotEmpty()) out[pkg] = value
            }
            return out
        }
    }

    fun isStale(now: Long): Boolean = validUntilMs > 0L && now > validUntilMs + STALE_GRACE_MS

    /** Hozir amaldagi maktab bloki (yo'q / tugagan / snapshot eskirgan — null). */
    fun activeSchool(now: Long): SchoolRule? {
        val rule = school ?: return null
        if (isStale(now)) return null
        if (rule.untilMs > 0L && now >= rule.untilMs) return null
        return rule
    }

    /**
     * Hozir amaldagi to'liq bloklar ('*' bo'lishi mumkin).
     * Dart maktab paketlarini ham `blocked_packages`ga qo'shadi — maktab bloki
     * tugagach ular olib tashlanadi (ota-ona to'liq bloklaganlari qoladi).
     */
    fun effectiveBlocked(now: Long): Set<String> {
        if (isStale(now)) return baseBlocked ?: blocked
        val rule = school ?: return blocked
        if (activeSchool(now) != null || rule.packages.isEmpty()) return blocked
        val keep = baseBlocked.orEmpty()
        return blocked.filterTo(HashSet()) { it !in rule.packages || it in keep }
    }

    /** Ota-ona tasdiqlagan ruxsat hali amaldami. */
    fun hasGrant(pkg: String, now: Long): Boolean = (grants[pkg] ?: 0L) > now

    /** Hech qanday cheklov yo'q — overlay kerak emas, faqat o'yin aniqlash. */
    fun hasNoRules(now: Long): Boolean =
        limits.isEmpty() && !blockUnknown && activeSchool(now) == null &&
            effectiveBlocked(now).isEmpty()
}
