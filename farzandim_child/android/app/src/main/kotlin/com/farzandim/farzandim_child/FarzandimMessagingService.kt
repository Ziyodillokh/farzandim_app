package com.farzandim.farzandim_child

import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Flutter firebase_messaging xizmatini kengaytiradi. "ring" (Baland ovoz)
 * buyrug'ini NATIVE darajada ushlaydi — shu sabab ilova fonda yoki BUTUNLAY
 * YOPIQ bo'lsa ham qurilma jiringlay oladi (Dart background isolate'ga bog'liq
 * emas). Boshqa barcha xabarlar super()'ga uzatiladi — voice/photo/video
 * push'lari oldingidek Flutter (Dart) tomonidan ko'rsatiladi.
 *
 * Manifestda plugin'ning standart FlutterFirebaseMessagingService olib
 * tashlanadi (tools:node="remove") va shu xizmat MESSAGING_EVENT bilan
 * ro'yxatdan o'tadi.
 */
class FarzandimMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val data = remoteMessage.data
        if (data["type"] == "ring") {
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
                android.util.Log.w("FarzandimMessaging", "Ring start/stop failed", e)
            }
            return // native ushladi — Flutter'ga uzatilmaydi
        }
        if (data["type"] == "listen_request") {
            // "Ota-onangiz tinglamoqda" indikatorini DARHOL ko'rsatamiz (ilova
            // yopiq bo'lsa ham) va full-screen intent MainActivity'ni (Flutter)
            // oldinga chiqaradi — WebRTC + mikrofon FGS o'sha foreground
            // kontekstda ishga tushadi. ⚠️ Mikrofon FGS'ni BU YERDA
            // boshlamaymiz: Android 14+ da `microphone` tipini fondan ishga
            // tushirib bo'lmaydi.
            try {
                ListenService.notifyIndicator(applicationContext, data["sessionId"] ?: "")
            } catch (e: Exception) {
                android.util.Log.w("FarzandimMessaging", "listen indicator failed", e)
            }
            // super() ni chaqiramiz — ilova FOREGROUND bo'lsa Dart FCM
            // handleri ham darhol ishlab, ekranni ochib WebRTC'ni boshlaydi.
            super.onMessageReceived(remoteMessage)
            return
        }
        super.onMessageReceived(remoteMessage)
    }
}
