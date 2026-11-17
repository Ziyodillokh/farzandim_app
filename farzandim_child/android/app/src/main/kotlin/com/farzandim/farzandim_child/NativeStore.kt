package com.farzandim.farzandim_child

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import java.util.concurrent.ConcurrentHashMap

/**
 * Native'ning o'z kichik prefs fayli ("parvoz_native").
 *
 * Nega alohida fayl (bat-native-prefs-fsync-churn, fn-limit-warned-keys-leak):
 * FlutterSharedPreferences'ni Dart har o'zgarishda TO'LIQ qayta yozadi va
 * reload() bilan butunlay o'qiydi. Avval native unga har kuni har limitli
 * ilova uchun yangi `limit_warned.*` kalit qo'shardi va hech qachon
 * o'chirmasdi — fayl cheksiz o'sardi.
 *
 * Saqlanadi:
 *  - o'yin aniqlash keshi (paket → versionCode + o'yinmi) — servis qayta
 *    ishga tushganda og'ir APK skani takrorlanmasin va birinchi ochilish
 *    o'tkazib yuborilmasin;
 *  - limit ogohlantirishlari — Toshkent kuni uchun BITTA kalit, eski kunlar
 *    o'chiriladi.
 */
internal class NativeStore(ctx: Context) {

    companion object {
        const val PREFS_NAME = "parvoz_native"
        private const val TAG = "NativeStore"
        private const val KEY_LEGACY_WARNED_CLEANED = "legacy_limit_warned_cleaned"
        private const val LEGACY_WARNED_PREFIX = "flutter.restriction.limit_warned."
    }

    private val prefs: SharedPreferences =
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val games = ConcurrentHashMap<String, GameCacheEntry>()

    @Volatile
    private var gamesLoaded = false

    private val warnedLock = Any()
    private var warnedDay = Long.MIN_VALUE
    private var warned: MutableSet<String> = HashSet()

    // ───────────────────────── O'yin keshi ─────────────────────────

    fun gameEntry(pkg: String): GameCacheEntry? {
        ensureGamesLoaded()
        return games[pkg]
    }

    fun putGame(pkg: String, entry: GameCacheEntry) {
        ensureGamesLoaded()
        if (games[pkg] == entry) return
        games[pkg] = entry
        prefs.edit().putString(NativeStoreCodec.gameKey(pkg), NativeStoreCodec.encodeGame(entry)).apply()
    }

    private fun ensureGamesLoaded() {
        if (gamesLoaded) return
        synchronized(games) {
            if (gamesLoaded) return
            try {
                for ((key, value) in prefs.all) {
                    if (!key.startsWith(NativeStoreCodec.GAME_PREFIX)) continue
                    val entry = NativeStoreCodec.decodeGame(value as? String) ?: continue
                    games.putIfAbsent(key.removePrefix(NativeStoreCodec.GAME_PREFIX), entry)
                }
            } catch (e: Exception) {
                Log.w(TAG, "o'yin keshi o'qilmadi: ${e.message}")
            }
            gamesLoaded = true
        }
    }

    // ───────────────────── Limit ogohlantirishlari ─────────────────────

    /**
     * Shu kun uchun (paket, limit) ogohlantirilmagan bo'lsa belgilaydi va
     * true qaytaradi; allaqachon ogohlantirilgan bo'lsa — false.
     */
    fun markLimitWarned(day: Long, pkg: String, limitMinutes: Int): Boolean =
        synchronized(warnedLock) {
            if (day != warnedDay) switchWarnedDay(day)
            val entry = NativeStoreCodec.warnedEntry(pkg, limitMinutes)
            if (!warned.add(entry)) return@synchronized false
            prefs.edit().putStringSet(NativeStoreCodec.warnedKey(day), HashSet(warned)).apply()
            true
        }

    private fun switchWarnedDay(day: Long) {
        warnedDay = day
        warned = try {
            HashSet(prefs.getStringSet(NativeStoreCodec.warnedKey(day), null) ?: emptySet())
        } catch (e: ClassCastException) {
            HashSet()
        }
        try {
            val stale = prefs.all.keys.filter { NativeStoreCodec.isStaleWarnedKey(it, day) }
            if (stale.isNotEmpty()) {
                val editor = prefs.edit()
                stale.forEach { editor.remove(it) }
                editor.apply()
            }
        } catch (e: Exception) {
            Log.w(TAG, "eski ogohlantirish kalitlari o'chirilmadi: ${e.message}")
        }
    }

    /**
     * Bir martalik tozalash: eski versiyalar FlutterSharedPreferences'ga
     * yozgan `flutter.restriction.limit_warned.*` kalitlari.
     */
    fun cleanupLegacyWarnedKeys(flutterPrefs: SharedPreferences) {
        if (prefs.getBoolean(KEY_LEGACY_WARNED_CLEANED, false)) return
        try {
            val old = flutterPrefs.all.keys.filter { it.startsWith(LEGACY_WARNED_PREFIX) }
            if (old.isNotEmpty()) {
                val editor = flutterPrefs.edit()
                old.forEach { editor.remove(it) }
                editor.apply()
                Log.d(TAG, "eski limit_warned kalitlari o'chirildi: ${old.size}")
            }
            prefs.edit().putBoolean(KEY_LEGACY_WARNED_CLEANED, true).apply()
        } catch (e: Exception) {
            Log.w(TAG, "eski limit_warned tozalanmadi: ${e.message}")
        }
    }
}
