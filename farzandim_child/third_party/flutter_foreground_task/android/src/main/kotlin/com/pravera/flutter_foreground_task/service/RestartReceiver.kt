package com.pravera.flutter_foreground_task.service

// PARVOZ PATCH (4): fon start hech qachon jarayonni yiqitmaydi — farzandim_child/
// third_party/flutter_foreground_task/PARVOZ_PATCHES.md
import android.app.ActivityManager
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import com.pravera.flutter_foreground_task.RequestCode
import com.pravera.flutter_foreground_task.models.ForegroundServiceAction
import com.pravera.flutter_foreground_task.models.ForegroundServiceStatus
import com.pravera.flutter_foreground_task.utils.PluginUtils

/**
 * The receiver that receives restart alarm event.
 *
 * @author Dev-hwang
 * @version 1.0
 */
class RestartReceiver : BroadcastReceiver() {
	companion object {
		private val TAG = RestartReceiver::class.java.simpleName

		fun setRestartAlarm(context: Context, millis: Int) {
			// PARVOZ PATCH (4): onDestroy/onTaskRemoved ichidan chaqiriladi — alarm
			// xatosi (masalan aniq-alarm ruxsati orada olib qo'yilsa) crash bermasin.
			try {
				val triggerTime = System.currentTimeMillis() + millis

				val intent = Intent(context, RestartReceiver::class.java)
				var flags = PendingIntent.FLAG_UPDATE_CURRENT
				if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
					flags = flags or PendingIntent.FLAG_MUTABLE
				}
				val operation = PendingIntent.getBroadcast(
					context, RequestCode.SET_RESTART_SERVICE_ALARM, intent, flags)

				val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
				if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
					PluginUtils.canScheduleExactAlarms(context)) {
					val info = AlarmManager.AlarmClockInfo(triggerTime, operation)
					alarmManager.setAlarmClock(info, operation)
				} else {
					alarmManager.set(AlarmManager.RTC_WAKEUP, triggerTime, operation)
				}
			} catch (e: Exception) {
				Log.e(TAG, "setRestartAlarm failed", e)
			}
		}

		fun cancelRestartAlarm(context: Context) {
			// PARVOZ PATCH (4): bekor qilish xatosi servis to'xtashini buzmasin.
			try {
				val intent = Intent(context, RestartReceiver::class.java)
				var flags = PendingIntent.FLAG_CANCEL_CURRENT
				if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
					flags = flags or PendingIntent.FLAG_MUTABLE
				}
				val operation = PendingIntent.getBroadcast(
					context, RequestCode.SET_RESTART_SERVICE_ALARM, intent, flags)

				val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
				alarmManager.cancel(operation)
			} catch (e: Exception) {
				Log.e(TAG, "cancelRestartAlarm failed", e)
			}
		}
	}

	override fun onReceive(context: Context?, intent: Intent?) {
		if (context == null) return

		// PARVOZ PATCH (4): restart alarm fonda keladi — Android 12+ da
		// startForegroundService ForegroundServiceStartNotAllowedException tashlashi
		// mumkin. Har qanday xato faqat log qilinadi, jarayon yiqilmaydi.
		try {
			restartServiceIfNeeded(context)
		} catch (e: Exception) {
			Log.e(TAG, "onReceive failed", e)
		}
	}

	private fun restartServiceIfNeeded(context: Context) {
		val serviceStatus = ForegroundServiceStatus.getData(context)
		if (serviceStatus.isCorrectlyStopped()) {
			return
		}

		val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
		val isRunningService = manager.getRunningServices(Integer.MAX_VALUE)
			.any { it.service.className == ForegroundService::class.java.name }
		if (isRunningService) {
			return
		}

		val isIgnoringBatteryOptimizations = PluginUtils.isIgnoringBatteryOptimizations(context)
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !isIgnoringBatteryOptimizations) {
			Log.w(TAG, "Turn off battery optimization to restart service in the background.")
		}

		val nIntent = Intent(context, ForegroundService::class.java)
		ForegroundServiceStatus.setData(context, ForegroundServiceAction.RESTART)
		try {
			ContextCompat.startForegroundService(context, nIntent)
		} catch (e: Exception) {
			Log.w(TAG, "Could not restart the foreground service in the background", e)
		}
	}
}
