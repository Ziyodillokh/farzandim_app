package com.farzandim.farzandim_child

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (FlutterActivity emas) — Health Connect ruxsat
// so'rovi (`health` paketi) FragmentActivity talab qiladi. Qolgan hamma narsa
// bir xil ishlaydi (configureFlutterEngine / onNewIntent / startActivity).
class MainActivity : FlutterFragmentActivity() {
    private val unlockChannelName = "farzandim_child/unlock"
    private var unlockChannel: MethodChannel? = null

    // "O'chirishni taqiqlash" — Device Admin kanali.
    private val adminChannelName = "farzandim_child/device_admin"

    // Qurilma soati — boot (yoqilgan) vaqtini aniqlash uchun. Qadam sanagich
    // (StepCounterService) telefon BUGUN yoqilganini bilib, "yoqilgandan beri
    // jami" qadamni aynan "bugungi qadam" deb qabul qiladi (HONOR/Huawei — HC
    // yo'q qurilmalarda telefondagi son bilan mos kelishi uchun).
    private val clockChannelName = "farzandim_child/device_clock"

    // Bloklash overlay'idagi "Ruxsat so'rash" tugmasi RestrictionService
    // shu Activity'ni `unlock_request_package` extra bilan ochadi. Flutter
    // tayyor bo'lguncha shu yerda saqlanib turadi (consumePendingUnlock).
    private var pendingUnlockPackage: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(UsageStatsPlugin())
        flutterEngine.plugins.add(SimInfoPlugin())

        unlockChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            unlockChannelName,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumePendingUnlock" -> {
                        val pkg = pendingUnlockPackage
                        pendingUnlockPackage = null
                        result.success(pkg)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            adminChannelName,
        ).setMethodCallHandler { call, result ->
            val dpm =
                getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val admin = ComponentName(this, FarzandimDeviceAdminReceiver::class.java)
            when (call.method) {
                // Admin faolmi (o'chirish taqiqlanganmi)?
                "isActive" -> result.success(dpm.isAdminActive(admin))
                // Admin'ni yoqish — faol bo'lmasa sistema dialogini ochamiz
                // (foydalanuvchi tasdiqlashi shart). Faol bo'lsa true.
                "requestActivation" -> {
                    if (dpm.isAdminActive(admin)) {
                        result.success(true)
                    } else {
                        val intent = Intent(
                            DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN,
                        ).apply {
                            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, admin)
                            putExtra(
                                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                "Parvoz'ni o'chirishdan himoya qilish uchun " +
                                    "administrator huquqini yoqing.",
                            )
                        }
                        startActivity(intent)
                        // Foydalanuvchi tasdiqlashi kerak — hozircha false.
                        result.success(false)
                    }
                }
                // Admin'ni o'chirish (himoyani bekor qilish) — uninstall ochiladi.
                "removeAdmin" -> {
                    if (dpm.isAdminActive(admin)) {
                        dpm.removeActiveAdmin(admin)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Qurilma soati — uptime (boot'dan beri o'tgan ms). Dart tomonida
        // boot vaqti = DateTime.now() - uptime deb hisoblanadi.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            clockChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // Boot'dan beri o'tgan vaqt (ms). Deep-sleep'ni ham hisoblaydi
                // (uptimeMillis EMAS — elapsedRealtime).
                "elapsedRealtimeMs" -> result.success(SystemClock.elapsedRealtime())
                else -> result.notImplemented()
            }
        }

        // Cold start — Activity'ni ochgan intent'dagi extra'ni o'qiymiz.
        readUnlockExtra(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readUnlockExtra(intent)
        // Flutter allaqachon tirik — darhol xabar beramiz.
        pendingUnlockPackage?.let { pkg ->
            unlockChannel?.invokeMethod("onUnlockRequested", pkg)
            pendingUnlockPackage = null
        }
    }

    private fun readUnlockExtra(intent: Intent?) {
        val pkg = intent?.getStringExtra("unlock_request_package")
        if (!pkg.isNullOrEmpty()) {
            pendingUnlockPackage = pkg
        }
    }
}
