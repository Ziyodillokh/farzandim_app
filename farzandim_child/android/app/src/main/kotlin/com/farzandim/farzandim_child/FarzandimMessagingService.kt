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
            if (data["action"] == "stop") {
                RingService.stop(applicationContext)
            } else {
                val duration = data["durationMs"]?.toLongOrNull() ?: 30_000L
                RingService.start(applicationContext, duration)
            }
            return // native ushladi — Flutter'ga uzatilmaydi
        }
        super.onMessageReceived(remoteMessage)
    }
}
