package com.farzandim.farzandim_child

import android.content.Context
import android.content.pm.ApplicationInfo
import android.util.Log
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import org.json.JSONArray
import org.json.JSONObject

/**
 * O'yin aniqlash va ota-onaga "o'ynayapti" navbati (`flutter.game.pending`).
 *
 * MethodChannel FGS isolate'ga bog'liq bo'lmasin deb aniqlash NATIVE'da:
 * native navbatga JSON yozadi, Dart (FGS isolate) o'qib backend'ga yuboradi.
 *
 * fn-game-notice-spam-and-miss tuzatishlari:
 *  - navbatga FAQAT ruxsat etilgan yo'lda (barcha blok tekshiruvlaridan
 *    keyin) qo'shiladi — bloklangan o'yinni bosish "o'ynayapti" bermaydi
 *    (chaqiruvchi — [EnforcementEngine]);
 *  - birinchi ochilish yo'qolmaydi: kesh hali javob bermagan bo'lsa edge
 *    holati yangilanmaydi — kesh to'lgach shu sessiya "yangi" bo'lib qoladi;
 *  - kesh "parvoz_native"da saqlanadi (servis qayta ishga tushganda ham);
 *  - yozuvga `at` (ishonchli epoch ms) qo'shiladi — Dart eskirganlarini
 *    tashlaydi; navbatga qo'shish atomar (qulf ostida o'qish-yozish).
 *
 * [cachedIsGame] va [onAllowedForeground] — poll oqimidan. Og'ir aniqlash
 * (APK ZIP skani) alohida fon oqimida.
 */
internal class GameDetector(
    private val ctx: Context,
    private val store: NativeStore,
) {
    companion object {
        private const val TAG = "GameDetector"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val KEY_QUEUE = "flutter.game.pending"

        /** Bir o'yin shu muddat ichida navbatga faqat bir marta. */
        const val DEDUP_MS = 5 * 60 * 1000L
        private const val QUEUE_CAP = 50

        /** Navbat kaliti uchun jarayon bo'yicha yagona qulf. */
        private val QUEUE_LOCK = Any()
    }

    private val pm = ctx.packageManager
    private val verdicts = ConcurrentHashMap<String, Boolean>()
    private val computing: MutableSet<String> = Collections.newSetFromMap(ConcurrentHashMap())
    private val executor: ExecutorService = Executors.newSingleThreadExecutor { r ->
        Thread(r, "parvoz-game-scan").apply { isDaemon = true }
    }

    // Poll oqimi holati.
    private val lastQueued = HashMap<String, Long>()
    private var lastForegroundForGame: String? = null

    /** Keshdan javob: true/false yoki null (hali noma'lum — fonda hisoblanmoqda). */
    fun cachedIsGame(pkg: String): Boolean? {
        verdicts[pkg]?.let { return it }
        val persisted = store.gameEntry(pkg)
        if (persisted != null) {
            verdicts[pkg] = persisted.isGame
            // Ilova yangilangan bo'lishi mumkin — versiyani fonda tekshiramiz.
            schedule(pkg, persisted)
            return persisted.isGame
        }
        schedule(pkg, null)
        return null
    }

    /**
     * Foreground ilova RUXSAT etilgan (bloklanmagan) bo'lsa chaqiriladi:
     * yangi ochilgan o'yin dedup oynasidan tashqarida bo'lsa navbatga.
     */
    fun onAllowedForeground(pkg: String, trustedNow: Long) {
        if (pkg == ctx.packageName) return
        // Noma'lum — edge holati O'ZGARMAYDI (birinchi ochilish yo'qolmasin).
        val isGame = cachedIsGame(pkg) ?: return
        val isNew = lastForegroundForGame != pkg
        lastForegroundForGame = pkg
        if (!isNew) return
        if (!isGame) {
            Log.d(TAG, "not-game: $pkg")
            return
        }
        val now = System.currentTimeMillis()
        if (now - (lastQueued[pkg] ?: 0L) < DEDUP_MS) return
        lastQueued[pkg] = now
        appendToQueue(pkg, now, trustedNow)
    }

    fun shutdown() {
        executor.shutdownNow()
    }

    private fun schedule(pkg: String, persisted: GameCacheEntry?) {
        if (!computing.add(pkg)) return
        try {
            executor.execute {
                try {
                    compute(pkg, persisted)
                } finally {
                    computing.remove(pkg)
                }
            }
        } catch (e: RejectedExecutionException) {
            computing.remove(pkg)
        }
    }

    /** Fon oqimi: versiya o'zgarmagan bo'lsa saqlangan javob qoladi. */
    private fun compute(pkg: String, persisted: GameCacheEntry?) {
        try {
            val info = pm.getPackageInfo(pkg, 0)
            val version = info.longVersionCode
            if (persisted != null && persisted.versionCode == version) return
            val ai = info.applicationInfo ?: pm.getApplicationInfo(pkg, 0)
            val isGame = isGame(ai)
            verdicts[pkg] = isGame
            store.putGame(pkg, GameCacheEntry(version, isGame))
        } catch (e: Exception) {
            // Paket topilmadi — o'yin emas (faqat xotirada; saqlanmaydi).
            if (persisted == null) verdicts[pkg] = false
        }
    }

    /**
     * Ilova O'YIN'mi — 3 signal (birortasi yetarli):
     *   1. CATEGORY_GAME — manifest `android:appCategory="game"`.
     *   2. FLAG_IS_GAME — eski `android:isGame` atributi.
     *   3. O'yin engine native lib'lari — ko'p o'yinlar (klon/kichik studiya)
     *      manifest'da kategoriya qo'ymaydi; deyarli barchasi Unity/Unreal/
     *      Cocos/Godot/libGDX'da — lib papkasida izi qoladi.
     */
    private fun isGame(ai: ApplicationInfo): Boolean {
        if (ai.category == ApplicationInfo.CATEGORY_GAME) return true
        @Suppress("DEPRECATION")
        if ((ai.flags and ApplicationInfo.FLAG_IS_GAME) != 0) return true
        return hasGameEngineLibs(ai)
    }

    private fun isEngineLibName(name: String): Boolean =
        name == "libunity.so" || // Unity (mono/IL2CPP'da ham bor)
            name == "libil2cpp.so" || // Unity IL2CPP
            name.startsWith("libUE") || // Unreal UE4 (libUE4.so)
            name == "libUnreal.so" || // Unreal UE5
            name.startsWith("libcocos") || // Cocos2d-x / Creator
            name.startsWith("libgodot") || // Godot
            name == "libgdx.so" // libGDX

    /**
     * O'yin engine native kutubxonalari bormi. 2 yo'l: (1) extractNativeLibs
     * =true — .so'lar diskda `nativeLibraryDir`da; (2) Play/AAB default — .so'lar
     * APK ichida (ko'pincha split_config.<abi>.apk), shuning uchun zip entry'lar
     * ham skan qilinadi (ZipFile faqat markaziy katalogni o'qiydi).
     */
    private fun hasGameEngineLibs(ai: ApplicationInfo): Boolean {
        try {
            val libs = ai.nativeLibraryDir?.let { java.io.File(it).list() }
            if (libs != null && libs.any(::isEngineLibName)) return true
        } catch (_: Exception) {
            // APK skaniga o'tamiz
        }
        val apks = ArrayList<String>()
        ai.sourceDir?.let { apks.add(it) }
        ai.splitSourceDirs?.let { apks.addAll(it) }
        for (path in apks) {
            try {
                java.util.zip.ZipFile(path).use { zip ->
                    val entries = zip.entries()
                    while (entries.hasMoreElements()) {
                        val name = entries.nextElement().name
                        if (name.startsWith("lib/") && isEngineLibName(name.substringAfterLast('/'))) {
                            return true
                        }
                    }
                }
            } catch (_: Exception) {
                // bu APK'ni tashlab keyingisiga o'tamiz
            }
        }
        return false
    }

    /** Navbatga atomar qo'shish (Dart FGS isolate o'qib backend'ga yuboradi). */
    private fun appendToQueue(pkg: String, wallNow: Long, trustedNow: Long) {
        val name = try {
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (e: Exception) {
            pkg
        }
        synchronized(QUEUE_LOCK) {
            try {
                val prefs = ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                val existing = parseQueue(prefs.getString(KEY_QUEUE, null))
                val added = JSONObject()
                    .put("pkg", pkg)
                    .put("name", name)
                    .put("ts", wallNow)
                    .put("at", trustedNow)
                val out = GameQueuePolicy.append(
                    existing,
                    QueuedGame(pkg, wallNow, added),
                    DEDUP_MS,
                    QUEUE_CAP,
                )
                val array = JSONArray()
                out.forEach { array.put(it.payload) }
                prefs.edit().putString(KEY_QUEUE, array.toString()).apply()
                Log.d(TAG, "Game queued: $pkg ($name)")
            } catch (e: Exception) {
                Log.e(TAG, "appendToQueue error", e)
            }
        }
    }

    private fun parseQueue(raw: String?): List<QueuedGame<JSONObject>> {
        if (raw.isNullOrBlank()) return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.optJSONObject(i) ?: return@mapNotNull null
                QueuedGame(o.optString("pkg"), o.optLong("ts"), o)
            }
        } catch (e: Exception) {
            // Buzilgan navbat — yangidan boshlaymiz (eski xulq: xato yutilardi).
            Log.w(TAG, "game.pending o'qilmadi: ${e.message}")
            emptyList()
        }
    }
}
