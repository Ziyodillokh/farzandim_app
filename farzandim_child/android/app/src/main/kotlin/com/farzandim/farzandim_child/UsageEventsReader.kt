package com.farzandim.farzandim_child

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.SharedPreferences

/**
 * UsageStatsManager hodisalarini sof holat mashinalariga ([UsageAccumulator],
 * [ForegroundTracker]) uzatuvchi yupqa Android adapteri. RestrictionService
 * (limit) va UsageStatsPlugin (hisobot) bir xil yo'ldan o'tadi.
 */
internal object UsageEventsReader {

    /**
     * Yarim tundan oldin ochilgan sessiya ham hisoblansin — so'rov shuncha
     * oldinroq boshlanadi (22:30–01:30 kabi uzun sessiyaning yarim tundan
     * keyingi qismi yangi kun limitiga tushishi uchun 6 soat). To'liq hisob
     * kamdan-kam (sessiya boshida va ~5 daqiqada bir) — narxi sezilarli emas.
     */
    const val CARRY_OVER_MS = 6 * 60 * 60 * 1000L

    /** [beginMs, endMs) hodisalarini [sink]ga beradi. Xato tashqariga chiqadi. */
    fun feed(usm: UsageStatsManager, beginMs: Long, endMs: Long, sink: UsageEventSink) {
        if (endMs <= beginMs) return
        val events = usm.queryEvents(beginMs, endMs) ?: return
        val ev = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(ev)
            sink.onEvent(ev.eventType, ev.packageName, ev.className, ev.timeStamp)
        }
    }

    /**
     * [windowStartMs] dan [nowMs] gacha har paketning foreground vaqti
     * (kun boshida ochiq sessiya ham — 1 soat oldindan so'raladi va kesiladi).
     */
    fun accumulate(usm: UsageStatsManager, windowStartMs: Long, nowMs: Long): UsageAccumulator {
        val acc = UsageAccumulator(windowStartMs)
        feed(usm, windowStartMs - CARRY_OVER_MS, nowMs, acc)
        acc.finish(nowMs)
        return acc
    }

    /**
     * Toshkent bugungi kun boshi QURILMA soatida (UsageEvents vaqt o'qi).
     * Kun ishonchli vaqt (`clock_offset_ms`) bo'yicha aniqlanadi — soat
     * surilsa ham limit nolga tushmaydi (fn-clock-bypass).
     */
    fun todayStartWall(trustedNow: Long, wallNow: Long): Long =
        TrustedClock.toWall(TashkentDay.startOfDay(trustedNow), trustedNow, wallNow)

    /** Dart yozgan soat farqi (ms) — yo'q bo'lsa 0. */
    fun clockOffsetMs(flutterPrefs: SharedPreferences): Long =
        try {
            SharedPrefsReader(flutterPrefs).long(EnforcementSnapshot.KEY_CLOCK_OFFSET_MS) ?: 0L
        } catch (e: Exception) {
            0L
        }
}
