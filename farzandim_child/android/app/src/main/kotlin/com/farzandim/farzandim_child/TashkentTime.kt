package com.farzandim.farzandim_child

import kotlin.math.abs

/**
 * Toshkent kun chegarasi (Asia/Tashkent = UTC+5, 1992-yildan beri yozgi vaqt
 * YO'Q) — Android'siz sof hisob (JVM testlanadi, Calendar yaratmaydi).
 *
 * Backend va ota-ona ilovasi "bugun"ni shu chegara bo'yicha hisoblaydi;
 * limit (RestrictionService) va hisobot (UsageStatsPlugin) ham aynan shu
 * chegarani ishlatadi.
 */
object TashkentDay {
    const val UTC_OFFSET_MS = 5 * 60 * 60 * 1000L
    const val DAY_MS = 24 * 60 * 60 * 1000L

    /** Toshkent kun raqami (epoch kunlari) — kun almashganini solishtirish uchun. */
    fun dayIndex(epochMs: Long): Long = Math.floorDiv(epochMs + UTC_OFFSET_MS, DAY_MS)

    /** [epochMs] tegishli Toshkent kunining 00:00 lahzasi (epoch ms). */
    fun startOfDay(epochMs: Long): Long = dayIndex(epochMs) * DAY_MS - UTC_OFFSET_MS
}

/**
 * Ishonchli vaqt — bola qurilma soatini surib limit/oyna/ruxsatlarni
 * chetlab o'tmasin (fn-clock-bypass).
 *
 * Dart har API javobining `Date` sarlavhasidan farqni hisoblab
 * `restriction.clock_offset_ms` (server − qurilma) ga yozadi. Shartnoma:
 * `trustedNow = System.currentTimeMillis() + offset`.
 *
 * Qo'shimcha himoya: offset MA'LUM bo'lsa vaqt `elapsedRealtime`ga
 * langarlanadi. Servis ishlab turganida soat qo'lda surilsa (masalan
 * internet o'chirilgan holda) ishonchli vaqt baribir to'g'ri yuradi — Dart
 * yangi offset yozguncha. Kichik farq (< [DRIFT_TOLERANCE_MS]: NTP tuzatishi,
 * kristall og'ishi) langarni formulaga qayta tenglaydi. Offset noma'lum
 * (null) bo'lsa — oddiy qurilma soati (bugungi xulq).
 *
 * Bitta oqimdan ishlatiladi (poll oqimi) — sinxronizatsiya yo'q.
 */
class TrustedClock {

    companion object {
        const val DRIFT_TOLERANCE_MS = 60_000L

        /** Ishonchli lahzani qurilma soati (UsageEvents vaqt o'qi) ga o'tkazadi. */
        fun toWall(trustedMs: Long, trustedNow: Long, wallNow: Long): Long =
            trustedMs - (trustedNow - wallNow)
    }

    private var offsetMs: Long? = null
    private var anchorTrusted = 0L
    private var anchorElapsed = 0L

    /** Snapshot'dagi offset (null — noma'lum). O'zgargan bo'lsa qayta langarlanadi. */
    fun updateOffset(offset: Long?, wallNow: Long, elapsedNow: Long) {
        if (offset == offsetMs) return
        offsetMs = offset
        if (offset != null) {
            anchorTrusted = wallNow + offset
            anchorElapsed = elapsedNow
        }
    }

    /** Hozirgi ishonchli vaqt (epoch ms). */
    fun now(wallNow: Long, elapsedNow: Long): Long {
        val offset = offsetMs ?: return wallNow
        val formula = wallNow + offset
        val anchored = anchorTrusted + (elapsedNow - anchorElapsed)
        if (abs(anchored - formula) < DRIFT_TOLERANCE_MS) {
            // Soat sakramagan — formulaga qayta tenglaymiz (og'ish to'planmasin).
            anchorTrusted = formula
            anchorElapsed = elapsedNow
            return formula
        }
        // Qurilma soati langardan keyin sakragan — Dart yangi offset yozguncha
        // langar (elapsedRealtime) ustun.
        return anchored
    }
}
