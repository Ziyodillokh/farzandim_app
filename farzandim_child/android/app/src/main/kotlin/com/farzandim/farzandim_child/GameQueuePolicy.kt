package com.farzandim.farzandim_child

/** `game.pending` navbatidagi yozuv: paket, navbatga qo'yilgan vaqt va asl JSON. */
data class QueuedGame<T>(val pkg: String, val ts: Long, val payload: T)

/**
 * O'yin navbati qoidalari — sof Kotlin (JVM testlanadi). JSON qismi:
 * [GameDetector].
 */
object GameQueuePolicy {

    /**
     * Yangi yozuvni qo'shadi: shu paketning dedup oynasidagi eski yozuvi
     * olib tashlanadi, navbat oxirgi [cap] tagacha qisqartiriladi (cheksiz
     * o'smasin).
     */
    fun <T> append(
        existing: List<QueuedGame<T>>,
        added: QueuedGame<T>,
        dedupMs: Long,
        cap: Int,
    ): List<QueuedGame<T>> {
        val kept = existing.filterNot { it.pkg == added.pkg && added.ts - it.ts < dedupMs }
        val all = kept + added
        return if (all.size > cap) all.subList(all.size - cap, all.size) else all
    }
}
