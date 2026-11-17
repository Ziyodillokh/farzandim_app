package com.farzandim.farzandim_child

import android.content.SharedPreferences

/** [PrefsReader] — FlutterSharedPreferences ustida (Dart int'lari Long bo'lib saqlanadi). */
internal class SharedPrefsReader(private val prefs: SharedPreferences) : PrefsReader {

    override fun string(key: String): String? =
        try {
            prefs.getString(key, null)
        } catch (e: ClassCastException) {
            null
        }

    override fun bool(key: String): Boolean? =
        try {
            if (prefs.contains(key)) prefs.getBoolean(key, false) else null
        } catch (e: ClassCastException) {
            null
        }

    override fun long(key: String): Long? {
        if (!prefs.contains(key)) return null
        return try {
            prefs.getLong(key, 0L)
        } catch (e: ClassCastException) {
            try {
                prefs.getInt(key, 0).toLong()
            } catch (e2: ClassCastException) {
                try {
                    prefs.getString(key, null)?.trim()?.toLongOrNull()
                } catch (e3: ClassCastException) {
                    null
                }
            }
        }
    }
}

/**
 * Cheklovlar snapshot'ini keshlab beradi (bat-native-per-tick-reparse,
 * fn-nonatomic-restriction-prefs).
 *
 * Kalitlar FAQAT shunda qayta o'qiladi:
 *  - servis startida (birinchi [current]);
 *  - `restriction.snapshot_version`, `childId` yoki `clock_offset_ms`
 *    o'zgarganda (OnSharedPreferenceChangeListener — Dart yozuvlari shu
 *    jarayondagi o'sha prefs nusxasi orqali o'tadi, listener main oqimda);
 *  - zaxira: eng ko'pi har 5 s da versiya arzon solishtiriladi;
 *  - eski Dart (versiya yozmaydi): istalgan cheklov kaliti o'zgarganda.
 *
 * [current] — faqat poll oqimidan. [onChanged] — main oqimdan chaqiriladi.
 */
internal class SnapshotSource(
    private val prefs: SharedPreferences,
    private val onChanged: () -> Unit,
) {
    companion object {
        private const val VERSION_CHECK_INTERVAL_MS = 5_000L
    }

    private val reader = SharedPrefsReader(prefs)

    @Volatile
    private var dirty = true

    @Volatile
    private var cached: EnforcementSnapshot? = null

    private var lastVersionCheckAt = 0L
    private var registered = false

    // KUCHLI havola shart: SharedPreferencesImpl listener'larni WeakHashMap'da
    // saqlaydi — lambda maydonda turmasa GC uni jimgina o'chirib yuboradi.
    private val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        val hasVersion = cached?.version != null
        if (EnforcementSnapshot.isReloadTrigger(key, hasVersion)) {
            dirty = true
            onChanged()
        }
    }

    /** Main oqimdan. */
    fun register() {
        if (registered) return
        prefs.registerOnSharedPreferenceChangeListener(listener)
        registered = true
        dirty = true
    }

    /** Main oqimdan. */
    fun unregister() {
        if (!registered) return
        prefs.unregisterOnSharedPreferenceChangeListener(listener)
        registered = false
    }

    /** Joriy snapshot (poll oqimi). */
    fun current(nowElapsed: Long): EnforcementSnapshot {
        val snap = cached
        if (!dirty && snap != null && nowElapsed - lastVersionCheckAt >= VERSION_CHECK_INTERVAL_MS) {
            lastVersionCheckAt = nowElapsed
            if (reader.long(EnforcementSnapshot.KEY_VERSION) != snap.version) dirty = true
        }
        if (!dirty && snap != null) return snap
        // Avval bayroq tushiriladi: o'qish paytidagi yangi yozuv uni qayta
        // ko'taradi va keyingi tick yana o'qiydi.
        dirty = false
        lastVersionCheckAt = nowElapsed
        val fresh = EnforcementSnapshot.read(reader)
        cached = fresh
        return fresh
    }
}
