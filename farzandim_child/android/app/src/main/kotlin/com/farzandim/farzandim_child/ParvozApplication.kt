package com.farzandim.farzandim_child

import android.app.Application
import android.content.Context
import android.util.Log
import com.pravera.flutter_foreground_task.FlutterForegroundTaskLifecycleListener
import com.pravera.flutter_foreground_task.FlutterForegroundTaskPlugin
import com.pravera.flutter_foreground_task.FlutterForegroundTaskStarter
import io.flutter.embedding.engine.FlutterEngine

/**
 * ParvozApplication — jarayon (process) boshlanganda BIR MARTA bajariladigan
 * native sozlashlar. Manifestda `<application android:name=".ParvozApplication">`.
 *
 *  1. flutter_foreground_task har task uchun YANGI FlutterEngine yaratadi va
 *     unga faqat GeneratedPluginRegistrant plaginlarini ulaydi. Ilovaning o'z
 *     [UsageStatsPlugin]'i ("farzandim/usage_stats") u yerda YO'Q edi → FGS
 *     isolate'da har chaqiruv MissingPluginException → heartbeat
 *     `usagePermission=false` (ota-onaga soxta "ruxsat o'chirildi" push'lari,
 *     maktab panelida NO_PERMISSION) va fon usage sync umuman ishlamasdi.
 *     Endi plagin har bir FGS engine'ga [TaskEngineHook] orqali ulanadi — u
 *     Dart callback'dan OLDIN chaqiriladi, boot/restart startlarini ham qamraydi.
 *  2. firebase_messaging'ning saqlangan fon callback handle'lari tozalanadi —
 *     Android'da headless FCM engine (alohida 4-engine) endi YARATILMAYDI.
 *     Data push'larni [FarzandimMessagingService] FGS isolate'ga uzatadi.
 *  3. Oldingi jarayon qanday tugagani (crash / ANR / OEM kill / "Stop") fon
 *     oqimida Crashlytics'ga yoziladi ([ExitReasonReporter]).
 *
 * Har bir qadam himoyalangan: bu yerdagi xato ilovani UMUMAN ochilmas qilardi.
 */
class ParvozApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Yordamchi (":xxx") jarayonlarda hech narsa qilinmaydi.
        if (!isMainProcess()) return
        registerTaskEngineHook()
        clearFcmBackgroundHandles()
        ExitReasonReporter.reportAsync(this)
    }

    private fun isMainProcess(): Boolean =
        try {
            Application.getProcessName() == packageName
        } catch (t: Throwable) {
            true
        }

    private fun registerTaskEngineHook() {
        try {
            FlutterForegroundTaskPlugin.addTaskLifecycleListener(TaskEngineHook)
        } catch (t: Throwable) {
            Log.e(TAG, "FGS engine hook ulanmadi", t)
        }
    }

    /**
     * 1.0.19 gacha Dart `FirebaseMessaging.onBackgroundMessage` Android'da ham
     * ro'yxatdan o'tkazilardi — plugin handle'larni o'z prefs'iga saqlaydi va
     * ular APK yangilangach ham qoladi. Handle bor ekan, fondagi HAR data push
     * (ring ham) uchun headless FlutterEngine yaratilib, jarayon umrigacha
     * yashardi. Endi Dart uni Android'da ro'yxatdan o'tkazmaydi (WS-C3), bu
     * yerda esa eski handle'lar har jarayon boshida tozalanadi.
     * Kalitlar: firebase_messaging 15.2.10 FlutterFirebaseMessagingBackgroundExecutor.
     */
    private fun clearFcmBackgroundHandles() {
        try {
            val prefs = getSharedPreferences(FCM_CALLBACK_PREFS, Context.MODE_PRIVATE)
            if (!prefs.contains(FCM_KEY_DISPATCHER) && !prefs.contains(FCM_KEY_USER)) return
            prefs.edit()
                .remove(FCM_KEY_DISPATCHER)
                .remove(FCM_KEY_USER)
                .apply()
            Log.i(TAG, "firebase_messaging fon handle'lari tozalandi (headless engine yo'q)")
        } catch (e: Exception) {
            Log.w(TAG, "FCM handle tozalashda xato", e)
        }
    }

    companion object {
        private const val TAG = "ParvozApplication"

        // firebase_messaging: FlutterFirebaseMessagingUtils.SHARED_PREFERENCES_KEY
        private const val FCM_CALLBACK_PREFS = "io.flutter.firebase.messaging.callback"
        private const val FCM_KEY_DISPATCHER = "callback_handle"
        private const val FCM_KEY_USER = "user_callback_handle"
    }
}

/**
 * FGS task engine'iga ilovaning o'z plaginlarini ulaydi. `onEngineCreate`
 * ForegroundTask.init ichida, Dart callback ishga tushishidan OLDIN chaqiriladi.
 * MainActivity o'z engine'iga [UsageStatsPlugin]'ni alohida ulaydi.
 */
private object TaskEngineHook : FlutterForegroundTaskLifecycleListener {
    private const val TAG = "TaskEngineHook"

    override fun onEngineCreate(flutterEngine: FlutterEngine?) {
        val engine = flutterEngine ?: return
        try {
            if (!engine.plugins.has(UsageStatsPlugin::class.java)) {
                engine.plugins.add(UsageStatsPlugin())
            }
        } catch (t: Throwable) {
            Log.e(TAG, "UsageStatsPlugin FGS engine'ga ulanmadi", t)
        }
    }

    override fun onTaskStart(starter: FlutterForegroundTaskStarter) = Unit

    override fun onTaskRepeatEvent() = Unit

    override fun onTaskDestroy() = Unit

    override fun onEngineWillDestroy() = Unit
}
