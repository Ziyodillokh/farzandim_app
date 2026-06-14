package com.farzandim.farzandim_child

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val unlockChannelName = "farzandim_child/unlock"
    private var unlockChannel: MethodChannel? = null

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
