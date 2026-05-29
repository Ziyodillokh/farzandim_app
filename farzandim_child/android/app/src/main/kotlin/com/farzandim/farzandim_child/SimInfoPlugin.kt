package com.farzandim.farzandim_child

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * SIM kartadan telefon raqamini o'qish uchun Flutter ↔ Kotlin
 * platform channel plugin.
 *
 * **Channel:** `farzandim/sim_info`
 *
 * **Methodlar:**
 * - `getPhoneNumber` — SIM kartadagi telefon raqamini qaytaradi
 *   yoki `null` (permission yo'q yoki carrier raqamni yozmagan).
 *
 * **Permission:** `READ_PHONE_NUMBERS` (Android 8+) yoki
 * `READ_SMS` (eski Android). `READ_PHONE_STATE` ham eski yo'l.
 *
 * **Cheklov:** iOS ekvivalenti yo'q — Apple privacy. Android'da
 * ham 100% ishlamasligi mumkin (carrier SIM provisioning'iga bog'liq).
 * O'zbekiston operatorlari (Beeline, Ucell, Mobiuz, Humans) odatda
 * raqamni SIM'ga yozadi.
 */
class SimInfoPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    companion object {
        private const val TAG = "SimInfoPlugin"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "farzandim/sim_info")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPhoneNumber" -> result.success(getPhoneNumber())
            else -> result.notImplemented()
        }
    }

    /**
     * SIM kartadagi birinchi mavjud telefon raqamini qaytaradi.
     * Multi-SIM telefonda birinchi (default) SIM ishlatiladi.
     *
     * Qaytaradi:
     *  - String: muvaffaqiyatli (masalan, "+998901234567")
     *  - null: permission yo'q YOKI carrier raqamni yozmagan YOKI xato
     */
    private fun getPhoneNumber(): String? {
        // Permission tekshirish: Android API'ga qarab boshqacha.
        if (!hasPhonePermission()) {
            Log.w(TAG, "READ_PHONE_NUMBERS / READ_PHONE_STATE permission yo'q")
            return null
        }

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // Android 13+ — yangi SubscriptionManager API
                getPhoneNumberApi33()
            } else {
                // Android 8-12 — TelephonyManager.line1Number
                @Suppress("DEPRECATION")
                getPhoneNumberLegacy()
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException — permission rad etilgan", e)
            null
        } catch (e: Exception) {
            Log.e(TAG, "SIM raqamini olishda xato", e)
            null
        }
    }

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun getPhoneNumberApi33(): String? {
        val subscriptionManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE)
            as? SubscriptionManager ?: return null
        // getActiveSubscriptionInfoList eng aniq, lekin null bo'lishi mumkin
        val activeSubs = subscriptionManager.activeSubscriptionInfoList
            ?: return null
        if (activeSubs.isEmpty()) return null

        // Birinchi aktiv SIM raqamini olish.
        val subId = activeSubs[0].subscriptionId
        val phone = subscriptionManager.getPhoneNumber(subId)
        return phone.takeIf { it.isNotBlank() }
    }

    @Suppress("DEPRECATION")
    private fun getPhoneNumberLegacy(): String? {
        val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE)
            as? TelephonyManager ?: return null
        val phone = telephonyManager.line1Number
        return phone?.takeIf { it.isNotBlank() }
    }

    /**
     * Permission tekshiruvi.
     * - Android 13+ (API 33+): READ_PHONE_NUMBERS (kichik privilegiya)
     * - Android 8-12: READ_PHONE_NUMBERS YOKI READ_PHONE_STATE
     * - Eski: READ_PHONE_STATE
     */
    private fun hasPhonePermission(): Boolean {
        val phoneNumbers = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_PHONE_NUMBERS,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            false
        }
        val phoneState = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_PHONE_STATE,
        ) == PackageManager.PERMISSION_GRANTED
        return phoneNumbers || phoneState
    }
}
