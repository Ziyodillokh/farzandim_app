package com.farzandim.farzandim_child

// Testlar uchun qisqa yozuv: UsageEvents oqimini o'qiladigan qilib beradi.

fun UsageEventSink.resumed(pkg: String, cls: String, t: Long) =
    onEvent(UsageEventTypes.ACTIVITY_RESUMED, pkg, cls, t)

fun UsageEventSink.paused(pkg: String, cls: String, t: Long) =
    onEvent(UsageEventTypes.ACTIVITY_PAUSED, pkg, cls, t)

fun UsageEventSink.stopped(pkg: String, cls: String, t: Long) =
    onEvent(UsageEventTypes.ACTIVITY_STOPPED, pkg, cls, t)

fun UsageEventSink.screenOff(t: Long) =
    onEvent(UsageEventTypes.SCREEN_NON_INTERACTIVE, null, null, t)

fun UsageEventSink.screenOn(t: Long) =
    onEvent(UsageEventTypes.SCREEN_INTERACTIVE, null, null, t)

fun UsageEventSink.keyguardShown(t: Long) =
    onEvent(UsageEventTypes.KEYGUARD_SHOWN, null, null, t)

fun UsageEventSink.keyguardHidden(t: Long) =
    onEvent(UsageEventTypes.KEYGUARD_HIDDEN, null, null, t)

/** Prefs o'rnida oddiy Map (Dart int → Long, bool → Boolean, string → String). */
class MapPrefs(private val values: Map<String, Any?>) : PrefsReader {
    override fun string(key: String): String? = values[key] as? String
    override fun bool(key: String): Boolean? = values[key] as? Boolean
    override fun long(key: String): Long? = (values[key] as? Number)?.toLong()
}
