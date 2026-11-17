package com.farzandim.farzandim_child

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import com.google.firebase.crashlytics.FirebaseCrashlytics

/**
 * ExitReasonReporter — oldingi jarayon QANDAY tugaganini Crashlytics'ga yozadi
 * (kill-native-crashlytics-blind).
 *
 * "Ba'zan ishlamay qoladi" shikoyatlarining sababi odatda crash EMAS: LMK,
 * MIUI/Tecno tozalovchisi, Task Manager "Stop", ruxsat o'zgarishi, freezer.
 * Bular Crashlytics'ga umuman tushmasdi. Android 11+ (API 30)
 * `getHistoricalProcessExitReasons` har birini sabab + vaqt bilan saqlaydi.
 *
 * Har jarayon boshida BIR MARTA (ParvozApplication), fon oqimida:
 *  - eng so'nggi chiqish → custom key'lar (shu sessiyadagi har crash/non-fatal
 *    bilan birga ko'rinadi);
 *  - oxirgi yozilgandan keyingi YANGI chiqishlar → kunlik limit bilan non-fatal.
 * Hammasi himoyalangan — hech qachon tashlamaydi.
 */
internal object ExitReasonReporter {
    private const val TAG = "ExitReasonReporter"
    private const val PREFS = "parvoz_native"
    private const val KEY_LAST_REPORTED_AT = "exit.last_reported_at"
    private const val MAX_RECORDS = 5

    fun reportAsync(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        val app = ctx.applicationContext
        try {
            Thread({ reportSafely(app) }, "parvoz-exit-reasons").apply {
                isDaemon = true
                priority = Thread.MIN_PRIORITY
            }.start()
        } catch (t: Throwable) {
            Log.w(TAG, "exit-reasons oqimi boshlanmadi", t)
        }
    }

    private fun reportSafely(ctx: Context) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) report(ctx)
        } catch (t: Throwable) {
            Log.w(TAG, "exit reason o'qishda xato", t)
        }
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun report(ctx: Context) {
        val am = ctx.getSystemService(ActivityManager::class.java) ?: return
        val records = am.getHistoricalProcessExitReasons(ctx.packageName, 0, MAX_RECORDS)
            .map { it.toRecord() }
        val latest = records.maxByOrNull { it.timestamp } ?: return
        setLastExitKeys(latest)

        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val fresh = ExitReasonPolicy.newSince(records, prefs.getLong(KEY_LAST_REPORTED_AT, 0L))
        if (fresh.isEmpty()) return

        var recorded = 0
        for (record in ExitReasonPolicy.nonFatalCandidates(fresh)) {
            // Kunlik limit tugasa qolganlari yozilmaydi (eng yangilari birinchi).
            if (!NativeCrashlytics.recordNonFatal(ctx, ProcessExitReport(record))) break
            recorded++
        }
        prefs.edit().putLong(KEY_LAST_REPORTED_AT, fresh.last().timestamp).apply()
        Log.i(TAG, "Exit reasons: ${fresh.size} yangi, $recorded non-fatal")
    }

    private fun setLastExitKeys(latest: ExitRecord) {
        try {
            FirebaseCrashlytics.getInstance().apply {
                setCustomKey("last_exit_reason", ExitReasonPolicy.reasonName(latest.reason))
                setCustomKey(
                    "last_exit_description",
                    latest.description.orEmpty().take(ExitReasonPolicy.MAX_DESCRIPTION),
                )
                setCustomKey("last_exit_at", latest.timestamp)
                setCustomKey("last_exit_importance", latest.importance)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "Crashlytics custom key yozilmadi", t)
        }
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun ApplicationExitInfo.toRecord(): ExitRecord =
        ExitRecord(
            timestamp = timestamp,
            reason = reason,
            importance = importance,
            status = status,
            description = description,
        )
}

/** ApplicationExitInfo'ning kerakli qismi (pure — JVM testda tekshiriladi). */
internal data class ExitRecord(
    val timestamp: Long,
    val reason: Int,
    val importance: Int,
    val status: Int,
    val description: String?,
)

/** Qaysi chiqishlar yangi va qaysilari non-fatal sifatida yoziladi (pure). */
internal object ExitReasonPolicy {
    const val MAX_DESCRIPTION = 300

    // Crash, native crash, ANR, "Majburiy to'xtatish"/Task Manager "Stop",
    // OEM/tizim kill, LMK, ruxsat o'zgarishi, freezer / ortiqcha resurs.
    // EXIT_SELF, DEPENDENCY_DIED, PACKAGE_UPDATED va h.k. — normal holat.
    private val NON_FATAL_REASONS = setOf(
        ApplicationExitInfo.REASON_CRASH,
        ApplicationExitInfo.REASON_CRASH_NATIVE,
        ApplicationExitInfo.REASON_ANR,
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE,
        ApplicationExitInfo.REASON_USER_REQUESTED,
        ApplicationExitInfo.REASON_USER_STOPPED,
        ApplicationExitInfo.REASON_SIGNALED,
        ApplicationExitInfo.REASON_OTHER,
        ApplicationExitInfo.REASON_LOW_MEMORY,
        ApplicationExitInfo.REASON_PERMISSION_CHANGE,
        ApplicationExitInfo.REASON_FREEZER,
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE,
    )

    /** Oxirgi yozilgan vaqtdan KEYINGI chiqishlar, eskisidan yangisiga. */
    fun newSince(records: List<ExitRecord>, lastReportedAt: Long): List<ExitRecord> =
        records.filter { it.timestamp > lastReportedAt }.sortedBy { it.timestamp }

    fun shouldRecordNonFatal(reason: Int): Boolean = reason in NON_FATAL_REASONS

    /** Non-fatal nomzodlari — eng yangisi birinchi (limit tugasa eskisi tushadi). */
    fun nonFatalCandidates(fresh: List<ExitRecord>): List<ExitRecord> =
        fresh.filter { shouldRecordNonFatal(it.reason) }.sortedByDescending { it.timestamp }

    fun reasonName(reason: Int): String =
        when (reason) {
            ApplicationExitInfo.REASON_UNKNOWN -> "UNKNOWN"
            ApplicationExitInfo.REASON_EXIT_SELF -> "EXIT_SELF"
            ApplicationExitInfo.REASON_SIGNALED -> "SIGNALED"
            ApplicationExitInfo.REASON_LOW_MEMORY -> "LOW_MEMORY"
            ApplicationExitInfo.REASON_CRASH -> "CRASH"
            ApplicationExitInfo.REASON_CRASH_NATIVE -> "CRASH_NATIVE"
            ApplicationExitInfo.REASON_ANR -> "ANR"
            ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "INITIALIZATION_FAILURE"
            ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "PERMISSION_CHANGE"
            ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "EXCESSIVE_RESOURCE_USAGE"
            ApplicationExitInfo.REASON_USER_REQUESTED -> "USER_REQUESTED"
            ApplicationExitInfo.REASON_USER_STOPPED -> "USER_STOPPED"
            ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "DEPENDENCY_DIED"
            ApplicationExitInfo.REASON_OTHER -> "OTHER"
            ApplicationExitInfo.REASON_FREEZER -> "FREEZER"
            ApplicationExitInfo.REASON_PACKAGE_STATE_CHANGE -> "PACKAGE_STATE_CHANGE"
            ApplicationExitInfo.REASON_PACKAGE_UPDATED -> "PACKAGE_UPDATED"
            else -> "REASON_$reason"
        }

    fun describe(record: ExitRecord): String =
        "Process exit ${reasonName(record.reason)} importance=${record.importance} " +
            "status=${record.status} at=${record.timestamp} " +
            "desc=${record.description.orEmpty().take(MAX_DESCRIPTION)}"
}

/** Native non-fatal'lar uchun kunlik limit (pure) — fon wake'lar bo'roni Crashlytics'ni to'ldirmasin. */
internal object NonFatalBudget {
    const val MAX_PER_DAY = 20

    fun usedToday(savedDay: Long, savedCount: Int, today: Long): Int =
        if (savedDay == today) savedCount.coerceAtLeast(0) else 0

    fun allows(usedToday: Int, maxPerDay: Int = MAX_PER_DAY): Boolean = usedToday < maxPerDay
}

/**
 * Crashlytics'ga native non-fatal yozish (kunlik limit bilan). Hech qachon
 * tashlamaydi. Bir nechta oqimdan chaqiriladi (exit-reasons oqimi, bosh oqim).
 */
internal object NativeCrashlytics {
    private const val TAG = "NativeCrashlytics"
    private const val PREFS = "parvoz_native"
    private const val KEY_DAY = "nonfatal.day"
    private const val KEY_COUNT = "nonfatal.count"
    private const val DAY_MS = 24L * 60L * 60L * 1000L

    /** @return true — yozildi; false — limit tugagan yoki Crashlytics xatosi. */
    @Synchronized
    fun recordNonFatal(ctx: Context, error: Throwable, note: String? = null): Boolean =
        try {
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val today = System.currentTimeMillis() / DAY_MS
            val used = NonFatalBudget.usedToday(
                prefs.getLong(KEY_DAY, -1L),
                prefs.getInt(KEY_COUNT, 0),
                today,
            )
            if (NonFatalBudget.allows(used)) {
                val crashlytics = FirebaseCrashlytics.getInstance()
                if (note != null) crashlytics.log(note)
                crashlytics.recordException(error)
                prefs.edit().putLong(KEY_DAY, today).putInt(KEY_COUNT, used + 1).apply()
                true
            } else {
                false
            }
        } catch (t: Throwable) {
            Log.w(TAG, "non-fatal yozilmadi", t)
            false
        }
}

/**
 * Jarayon chiqishi uchun sun'iy non-fatal. Crashlytics issue'larni stack trace
 * bo'yicha guruhlaydi — har sabab ALOHIDA issue bo'lishi uchun bitta sun'iy
 * kadr qo'yiladi (aks holda hammasi bitta "report()" kadri ostida qolardi).
 */
internal class ProcessExitReport(record: ExitRecord) :
    Exception(ExitReasonPolicy.describe(record)) {
    init {
        setStackTrace(
            arrayOf(
                StackTraceElement(
                    "ParvozProcessExit",
                    ExitReasonPolicy.reasonName(record.reason),
                    "ApplicationExitInfo",
                    record.reason,
                ),
            ),
        )
    }
}
