package com.farzandim.farzandim_child

/** O'yin aniqlash natijasi — ilova versiyasi bilan (yangilansa qayta hisoblanadi). */
data class GameCacheEntry(val versionCode: Long, val isGame: Boolean)

/**
 * "parvoz_native" prefs qiymatlari formati — sof Kotlin (JVM testlanadi).
 * Android qismi: [NativeStore].
 */
object NativeStoreCodec {
    const val GAME_PREFIX = "game."
    const val WARNED_PREFIX = "limit_warned."

    fun gameKey(pkg: String): String = GAME_PREFIX + pkg

    /** "versionCode:1" (o'yin) yoki "versionCode:0". */
    fun encodeGame(entry: GameCacheEntry): String =
        "${entry.versionCode}:${if (entry.isGame) 1 else 0}"

    fun decodeGame(raw: String?): GameCacheEntry? {
        if (raw.isNullOrBlank()) return null
        val i = raw.lastIndexOf(':')
        if (i <= 0) return null
        val version = raw.substring(0, i).toLongOrNull() ?: return null
        val isGame = when (raw.substring(i + 1)) {
            "1" -> true
            "0" -> false
            else -> return null
        }
        return GameCacheEntry(version, isGame)
    }

    /** Bitta Toshkent kuni uchun bitta kalit (to'plam: "paket:limit"). */
    fun warnedKey(day: Long): String = WARNED_PREFIX + day

    /** Limit grant bilan o'zgarsa yozuv o'zgaradi → yangi limitga yana ogohlantirish mumkin. */
    fun warnedEntry(pkg: String, limitMinutes: Int): String = "$pkg:$limitMinutes"

    /** Boshqa (eski) kunning ogohlantirish kaliti — o'chiriladi. */
    fun isStaleWarnedKey(key: String, today: Long): Boolean =
        key.startsWith(WARNED_PREFIX) && key != warnedKey(today)
}
