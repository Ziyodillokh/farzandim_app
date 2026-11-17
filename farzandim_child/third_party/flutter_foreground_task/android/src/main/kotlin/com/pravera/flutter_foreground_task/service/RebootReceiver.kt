package com.pravera.flutter_foreground_task.service

// PARVOZ PATCH (4): fon start hech qachon jarayonni yiqitmaydi — farzandim_child/
// third_party/flutter_foreground_task/PARVOZ_PATCHES.md
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat
import com.pravera.flutter_foreground_task.models.ForegroundServiceAction
import com.pravera.flutter_foreground_task.models.ForegroundServiceStatus
import com.pravera.flutter_foreground_task.models.ForegroundTaskOptions
import com.pravera.flutter_foreground_task.utils.ForegroundServiceUtils

/**
 * The receiver that receives the BOOT_COMPLETED and MY_PACKAGE_REPLACED intent.
 *
 * @author Dev-hwang
 * @version 1.0
 */
class RebootReceiver : BroadcastReceiver() {
    companion object {
        private val TAG = RebootReceiver::class.java.simpleName
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        // PARVOZ PATCH (4): prefs/JSON o'qish yoki start xatosi boot/update paytida
        // jarayonni (RestrictionService ham shu jarayonda) yiqitmasin.
        try {
            handleIntent(context, intent)
        } catch (e: Exception) {
            Log.e(TAG, "onReceive(${intent.action}) failed", e)
        }
    }

    private fun handleIntent(context: Context, intent: Intent) {
        // Ignore autoRunOnBoot option when android:stopWithTask is set to true.
        if (ForegroundServiceUtils.isSetStopWithTaskFlag(context)) {
            return
        }

        // Ignore autoRunOnBoot option when service is stopped by developer.
        val serviceStatus = ForegroundServiceStatus.getData(context)
        if (serviceStatus.isCorrectlyStopped()) {
            return
        }

        val options = ForegroundTaskOptions.getData(context)

        // Check whether to start the service at boot intent.
        if ((intent.action == Intent.ACTION_BOOT_COMPLETED ||
                intent.action == "android.intent.action.QUICKBOOT_POWERON") && options.autoRunOnBoot) {
            return startForegroundService(context)
        }

        // Check whether to start the service on my package replaced intent.
        if (intent.action == Intent.ACTION_MY_PACKAGE_REPLACED && options.autoRunOnMyPackageReplaced) {
            return startForegroundService(context)
        }
    }

    private fun startForegroundService(context: Context) {
        // Create an intent for calling the service and store the action to be executed
        val nIntent = Intent(context, ForegroundService::class.java)
        ForegroundServiceStatus.setData(context, ForegroundServiceAction.REBOOT)
        // PARVOZ PATCH (4): Android 12+ fon start cheklovi
        // (ForegroundServiceStartNotAllowedException) va boshqa xatolar — faqat log.
        try {
            ContextCompat.startForegroundService(context, nIntent)
        } catch (e: Exception) {
            Log.w(TAG, "Could not start the foreground service from the reboot receiver", e)
        }
    }
}
