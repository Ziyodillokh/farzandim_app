package com.farzandim.farzandim_child

import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Flutter firebase_messaging xizmatini kengaytiradi. "ring" (Baland ovoz)
 * buyrug'ini NATIVE darajada ushlaydi — shu sabab ilova fonda yoki BUTUNLAY
 * YOPIQ bo'lsa ham qurilma jiringlay oladi (Dart background isolate'ga bog'liq
 * emas). Boshqa barcha xabarlar super()'ga uzatiladi — voice/photo/video
 * push'lari oldingidek Flutter (Dart) tomonidan ko'rsatiladi.
 *
 * 1.0.20: `restrictions_sync` / `unlock_decision` / `location_wake` data
 * push'lari NATIVE ravishda ishlab turgan FGS Dart isolate'ga uzatiladi
 * (ForegroundService.sendData, bosh oqimda). Ilgari ular fonda alohida headless
 * FCM engine'ni uyg'otardi, Android'da `restrictions_sync` esa umuman e'tiborsiz
 * qolardi (bloklar keyingi poll'gacha kechikardi). FGS ishlamasa — uni qayta
 * yoqadi (high-priority FCM oynasida fon start ruxsat etilgan).
 *
 * Eslatma: firebase_messaging 15.2.10 da `super.onMessageReceived` bo'sh
 * (Dart'ga yetkazishni FlutterFirebaseMessagingReceiver qiladi); bu uch tur
 * uchun super faqat ilova ko'rinib turganda chaqiriladi — kontrakt shunday.
 *
 * Manifestda plugin'ning standart FlutterFirebaseMessagingService olib
 * tashlanadi (tools:node="remove") va shu xizmat MESSAGING_EVENT bilan
 * ro'yxatdan o'tadi.
 */
class FarzandimMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val data = remoteMessage.data
        val type = data["type"]
        if (type == "ring") {
            handleRing(data)
            return // native ushladi — Flutter'ga uzatilmaydi
        }
        // "listen_request" (jonli eshitish) 2026-11-11 dan qabul qilinmaydi —
        // funksiya olib tashlandi; eski push kelsa oddiy xabar sifatida o'tadi.
        val trigger = PushRouting.triggerFor(type)
        if (trigger != null) {
            ParvozTaskBridge.deliverFromBackground(applicationContext, trigger, "fcm:$type")
        }
        if (PushRouting.passToFlutter(type, MainActivity.isVisible)) {
            super.onMessageReceived(remoteMessage)
        }
    }

    private fun handleRing(data: Map<String, String>) {
        // start*Service() fon/doze holatida ForegroundServiceStartNotAllowed
        // (A12+) yoki IllegalStateException (A8-11) tashlashi mumkin — bu
        // messaging jarayonini crash qilardi ("ilova ishdan chiqdi"). try/catch
        // himoyalaydi (ruxsat berilganda xulq o'zgarmaydi, faqat crashni to'sadi).
        try {
            if (data["action"] == "stop") {
                RingService.stop(applicationContext)
            } else {
                val duration = data["durationMs"]?.toLongOrNull() ?: 30_000L
                RingService.start(applicationContext, duration)
            }
        } catch (e: Exception) {
            Log.w("FarzandimMessaging", "Ring start/stop failed", e)
        }
    }
}

/** Data push turi → FGS trigger (pure — JVM testda tekshiriladi). */
internal object PushRouting {
    /** Kontrakt: native → FGS Dart isolate (ChildBackgroundTaskHandler.onReceiveData). */
    const val RESTRICTIONS_SYNC = "parvoz:restrictions_sync"
    const val LOCATION_WAKE = "parvoz:location_wake"

    fun triggerFor(type: String?): String? =
        when (type) {
            "restrictions_sync", "unlock_decision" -> RESTRICTIONS_SYNC
            "location_wake" -> LOCATION_WAKE
            else -> null
        }

    /**
     * Flutter (Dart) handler'iga uzatilsinmi: FGS'ga ketadigan turlar faqat UI
     * ko'rinib turganda (foreground Dart handler'lari ishlasin, fonda headless
     * engine yaratilmasin); qolgan turlar — har doim (oldingi xulq).
     */
    fun passToFlutter(type: String?, isUiVisible: Boolean): Boolean =
        triggerFor(type) == null || isUiVisible
}
