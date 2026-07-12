package com.farzandim.farzandim_child

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

/**
 * "O'chirishni taqiqlash" uchun Device Admin receiver.
 *
 * Bu receiver faol admin bo'lganda Android ilovani o'chirishga (uninstall)
 * ruxsat bermaydi — Sozlamalar > Ilovalar > Farzandim'da "O'chirish" tugmasi
 * o'chadi. O'chirish uchun avval admin'ni deaktivatsiya qilish kerak; bola
 * buni qilmoqchi bo'lsa `onDisableRequested` ogohlantirish ko'rsatadi.
 *
 * Admin ota-ona `blockUninstall` toggle'iga qarab yoqiladi/o'chiriladi
 * (UninstallProtectionService orqali).
 */
class FarzandimDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        // Bola admin'ni o'chirmoqchi bo'lganda ko'rsatiladigan ogohlantirish.
        return "Farzandim himoyasi yoqilgan. Ilovani o'chirish uchun avval " +
            "ota-onangizdan ruxsat so'rang."
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        // Bola himoyani (Device Admin) O'CHIRDI. SharedPreferences'ga bayroq
        // qo'yamiz — Dart o'qib ota-onaga "himoya o'chirildi" push yuboradi
        // (Play-mos: shunchaki xabar berish). Receiver o'zi tarmoqqa chiqmaydi.
        try {
            context.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE,
            ).edit()
                .putBoolean("flutter.uninstall_guard.deactivated", true)
                .apply()
        } catch (_: Exception) {
        }
    }
}
