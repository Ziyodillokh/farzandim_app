package com.pravera.flutter_foreground_task.service

// PARVOZ PATCH: bu fayl yamalgan (1, 2, 3, 6) — farzandim_child/third_party/
// flutter_foreground_task/PARVOZ_PATCHES.md
import android.Manifest
import android.annotation.SuppressLint
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.net.wifi.WifiManager
import android.os.*
import android.text.Spannable
import android.text.SpannableString
import android.text.style.ForegroundColorSpan
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.pravera.flutter_foreground_task.FlutterForegroundTaskLifecycleListener
import com.pravera.flutter_foreground_task.RequestCode
import com.pravera.flutter_foreground_task.models.*
import com.pravera.flutter_foreground_task.utils.ForegroundServiceUtils
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import java.util.*

/**
 * A service class for implementing foreground service.
 *
 * @author Dev-hwang
 * @version 1.0
 */
class ForegroundService : Service() {
    companion object {
        private val TAG = ForegroundService::class.java.simpleName

        private const val ACTION_NOTIFICATION_PRESSED = "onNotificationPressed"
        private const val ACTION_NOTIFICATION_DISMISSED = "onNotificationDismissed"
        private const val ACTION_NOTIFICATION_BUTTON_PRESSED = "onNotificationButtonPressed"
        private const val ACTION_RECEIVE_DATA = "onReceiveData"
        private const val INTENT_DATA_NAME = "intentData"

        // PARVOZ PATCH (2): ServiceInfo.FOREGROUND_SERVICE_TYPE_NONE (API 29) qiymati;
        // konstanta API 34'da deprecated — faqat API 29-33 da ishlatiladi.
        private const val FGS_TYPE_NONE = 0

        private val _isRunningServiceState = MutableStateFlow(false)
        val isRunningServiceState = _isRunningServiceState.asStateFlow()

        private var task: ForegroundTask? = null
        private var taskLifecycleListeners = ForegroundTaskLifecycleListeners()

        fun addTaskLifecycleListener(listener: FlutterForegroundTaskLifecycleListener) {
            taskLifecycleListeners.addListener(listener)
        }

        fun removeTaskLifecycleListener(listener: FlutterForegroundTaskLifecycleListener) {
            taskLifecycleListeners.removeListener(listener)
        }

        fun handleNotificationContentIntent(intent: Intent?) {
            if (intent == null) return

            try {
                // Check if the given intent is a LaunchIntent.
                val isLaunchIntent = (intent.action == Intent.ACTION_MAIN) &&
                        intent.categories.contains(Intent.CATEGORY_LAUNCHER)
                if (!isLaunchIntent) {
                    // Log.d(TAG, "not LaunchIntent")
                    return
                }

                val data = intent.getStringExtra(INTENT_DATA_NAME)
                if (data == ACTION_NOTIFICATION_PRESSED) {
                    task?.invokeMethod(data, null)
                }
            } catch (e: Exception) {
                Log.e(TAG, e.message, e)
            }
        }

        // PARVOZ PATCH (6): MethodChannel faqat main thread'da ishlaydi.
        private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

        fun sendData(data: Any?) {
            // PARVOZ PATCH (6): boshqa thread'dan (masalan FCM onMessageReceived)
            // chaqirilsa main thread'ga uzatamiz; xato jarayonni yiqitmaydi.
            if (Looper.myLooper() == Looper.getMainLooper()) {
                deliverData(data)
            } else {
                mainHandler.post { deliverData(data) }
            }
        }

        private fun deliverData(data: Any?) {
            if (!isRunningServiceState.value) return
            try {
                task?.invokeMethod(ACTION_RECEIVE_DATA, data)
            } catch (e: Exception) {
                Log.e(TAG, "sendData failed", e)
            }
        }
    }

    private lateinit var foregroundServiceStatus: ForegroundServiceStatus
    private lateinit var foregroundTaskOptions: ForegroundTaskOptions
    private lateinit var foregroundTaskData: ForegroundTaskData
    private lateinit var notificationOptions: NotificationOptions
    private lateinit var notificationContent: NotificationContent
    private var prevForegroundTaskOptions: ForegroundTaskOptions? = null
    private var prevForegroundTaskData: ForegroundTaskData? = null
    private var prevNotificationOptions: NotificationOptions? = null
    private var prevNotificationContent: NotificationContent? = null

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    // PARVOZ PATCH (2, 3): shu instance startForeground'ni muvaffaqiyatli
    // chaqirganmi va start xatosidan keyin o'zini to'xtatganmi.
    private var isForegroundStarted = false
    private var isStoppedAfterStartFailure = false

    // A broadcast receiver that handles intents that occur in the foreground service.
    private var broadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null) return

            try {
                // This intent has not sent from the current package.
                val iPackageName = intent.`package`
                val cPackageName = packageName
                if (iPackageName != cPackageName) {
                    Log.d(TAG, "This intent has not sent from the current package. ($iPackageName != $cPackageName)")
                    return
                }

                val action = intent.action ?: return
                val data = intent.getStringExtra(INTENT_DATA_NAME)
                task?.invokeMethod(action, data)
            } catch (e: Exception) {
                Log.e(TAG, e.message, e)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        registerBroadcastReceiver()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        loadDataFromPreferences()

        var action = foregroundServiceStatus.action
        val isSetStopWithTaskFlag = ForegroundServiceUtils.isSetStopWithTaskFlag(this)

        if (action == ForegroundServiceAction.API_STOP) {
            RestartReceiver.cancelRestartAlarm(this)
            // PARVOZ PATCH (3): startForegroundService() bilan kelgan (intent != null),
            // hali foreground bo'lmagan instance stopSelf'dan OLDIN startForeground
            // chaqirishi shart — aks holda Android "did not then call
            // Service.startForeground()" bilan jarayonni yiqitadi.
            if (intent != null && !isForegroundStarted) {
                tryStartForeground(withLocation = false)
            }
            stopForegroundService()
            return START_NOT_STICKY
        }

        if (intent == null) {
            ForegroundServiceStatus.setData(this, ForegroundServiceAction.RESTART)
            foregroundServiceStatus = ForegroundServiceStatus.getData(this)
            action = foregroundServiceStatus.action
        }

        // PARVOZ PATCH (3): startForeground bo'lmasa Flutter task yaratilmaydi,
        // servis jarayonni yiqitmasdan o'zini to'xtatadi.
        when (action) {
            ForegroundServiceAction.API_START,
            ForegroundServiceAction.API_RESTART -> {
                if (!startForegroundService()) return stopAfterStartFailure(startId)
                createForegroundTask()
            }
            ForegroundServiceAction.API_UPDATE -> {
                // PARVOZ PATCH (3): yangi (hali foreground bo'lmagan) instance'ga
                // kelgan API_UPDATE ham start — avval startForeground (aks holda
                // 10 s ichida ForegroundServiceDidNotStartInTimeException).
                if (!isForegroundStarted && !startForegroundService()) {
                    return stopAfterStartFailure(startId)
                }
                updateNotification()
                val prevCallbackHandle = prevForegroundTaskData?.callbackHandle
                val currCallbackHandle = foregroundTaskData.callbackHandle
                if (prevCallbackHandle != currCallbackHandle) {
                    createForegroundTask()
                } else {
                    val prevEventAction = prevForegroundTaskOptions?.eventAction
                    val currEventAction = foregroundTaskOptions.eventAction
                    if (prevEventAction != currEventAction) {
                        updateForegroundTask()
                    }
                }
            }
            ForegroundServiceAction.REBOOT,
            ForegroundServiceAction.RESTART -> {
                if (!startForegroundService()) return stopAfterStartFailure(startId)
                createForegroundTask()
                Log.d(TAG, "The service has been restarted by Android OS.")
            }
            else -> {
                // PARVOZ PATCH (3): noma'lum action bilan kelgan yangi instance ham
                // startForeground'siz qolmasin (10 s'dan keyin crash bo'lardi).
                if (!isForegroundStarted) {
                    if (!startForegroundService()) return stopAfterStartFailure(startId)
                    createForegroundTask()
                }
            }
        }

        return if (isSetStopWithTaskFlag) {
            START_NOT_STICKY
        } else {
            START_STICKY
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        destroyForegroundTask()
        stopForegroundService()
        unregisterBroadcastReceiver()

        val isCorrectlyStopped = foregroundServiceStatus.isCorrectlyStopped()
        val isSetStopWithTaskFlag = ForegroundServiceUtils.isSetStopWithTaskFlag(this)
        // PARVOZ PATCH (3): start xatosidan keyingi to'xtashda restart-alarm
        // qo'yilmaydi — fonda baribir ruxsat yo'q, faqat 5 s'lik start/stop sikli
        // bo'lardi. Keyingi start: boot, ilova ochilishi yoki native tick.
        if (!isCorrectlyStopped && !isSetStopWithTaskFlag && !isStoppedAfterStartFailure) {
            Log.e(TAG, "The service was terminated due to an unexpected problem. The service will restart after 5 seconds.")
            RestartReceiver.setRestartAlarm(this, 5000)
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        if (ForegroundServiceUtils.isSetStopWithTaskFlag(this)) {
            stopSelf()
        } else {
            RestartReceiver.setRestartAlarm(this, 1000)
        }
    }

    private fun loadDataFromPreferences() {
        foregroundServiceStatus = ForegroundServiceStatus.getData(applicationContext)

        if (::foregroundTaskOptions.isInitialized) {
            prevForegroundTaskOptions = foregroundTaskOptions
        }
        foregroundTaskOptions = ForegroundTaskOptions.getData(applicationContext)

        if (::foregroundTaskData.isInitialized) {
            prevForegroundTaskData = foregroundTaskData
        }
        foregroundTaskData = ForegroundTaskData.getData(applicationContext)

        if (::notificationOptions.isInitialized) {
            prevNotificationOptions = notificationOptions
        }
        notificationOptions = NotificationOptions.getData(applicationContext)

        if (::notificationContent.isInitialized) {
            prevNotificationContent = notificationContent
        }
        notificationContent = NotificationContent.getData(applicationContext)
    }

    private fun registerBroadcastReceiver() {
        val intentFilter = IntentFilter().apply {
            addAction(ACTION_NOTIFICATION_BUTTON_PRESSED)
            addAction(ACTION_NOTIFICATION_PRESSED)
            addAction(ACTION_NOTIFICATION_DISMISSED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(broadcastReceiver, intentFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(broadcastReceiver, intentFilter)
        }
    }

    private fun unregisterBroadcastReceiver() {
        unregisterReceiver(broadcastReceiver)
    }

    /**
     * PARVOZ PATCH (2, 3): startForeground ish vaqtida tanlangan tur bilan va
     * himoyalangan holda chaqiriladi (FOREGROUND_SERVICE_TYPE_MANIFEST HECH QACHON).
     *
     * @return servis foreground holatdami. Avval foreground bo'lgan instance'da
     * qayta chaqiruv xato bersa ham true — servis eski tur/notification bilan
     * ishlashda davom etadi.
     */
    private fun startForegroundService(): Boolean {
        val isStarted = tryStartForeground(withLocation = true)

        releaseLockMode()
        acquireLockMode()

        if (isStarted) {
            isForegroundStarted = true
            isStoppedAfterStartFailure = false
            _isRunningServiceState.update { true }
        }
        return isForegroundStarted
    }

    private fun stopForegroundService() {
        releaseLockMode()
        stopForeground(true)
        stopSelf()

        isForegroundStarted = false
        _isRunningServiceState.update { false }
    }

    /**
     * PARVOZ PATCH (3): startForeground bo'lmadi — jarayonni yiqitmasdan shu start
     * so'rovini yakunlaymiz. stopSelf(startId): orada yangi start kelgan bo'lsa
     * (masalan ilova UI'dan) servis to'xtamaydi va yangi so'rov qayta urinadi.
     */
    private fun stopAfterStartFailure(startId: Int): Int {
        isStoppedAfterStartFailure = true
        stopSelf(startId)
        return START_NOT_STICKY
    }

    /**
     * PARVOZ PATCH (2, 3): startForeground'ni xavfsiz chaqiradi, hech qachon
     * exception tashlamaydi.
     * - [withLocation] va joylashuv ruxsati bo'lsa LOCATION turi qo'shiladi;
     *   u rad etilsa (Android 14+ SecurityException: fon start + faqat
     *   "ilova ishlatilayotganda" ruxsati) darhol LOCATION'siz qayta urinadi.
     * - ForegroundServiceStartNotAllowedException (API 31+, masalan START_STICKY
     *   restart fonda) — qayta urinilmaydi, false.
     */
    private fun tryStartForeground(withLocation: Boolean): Boolean {
        val serviceType = resolveServiceType(withLocation && hasLocationPermission())
        try {
            startForegroundWithType(serviceType)
            return true
        } catch (e: Exception) {
            if (isStartNotAllowed(e)) {
                Log.w(TAG, "startForeground is not allowed now (background start), stopping: ${e.message}")
                return false
            }
            if (!hasLocationType(serviceType)) {
                Log.e(TAG, "startForeground failed (type=$serviceType), stopping", e)
                return false
            }
            Log.w(TAG, "startForeground with the location type failed, retrying without it: ${e.message}")
        }

        val fallbackType = fallbackServiceType()
        return try {
            startForegroundWithType(fallbackType)
            true
        } catch (e: Exception) {
            if (isStartNotAllowed(e)) {
                Log.w(TAG, "startForeground is not allowed now (background start), stopping: ${e.message}")
            } else {
                Log.e(TAG, "startForeground failed (type=$fallbackType), stopping", e)
            }
            false
        }
    }

    /**
     * PARVOZ PATCH (2): FGS turi ish vaqtida. null = startForeground(id, notification).
     * - API 34+: SPECIAL_USE har doim (+ LOCATION faqat [withLocation] bo'lsa).
     * - API 29-33: LOCATION yoki turisiz chaqiruv. Bu versiyalar FGS turi uchun
     *   ruxsat talab qilmaydi (SecurityException yo'q); turisiz chaqiruv manifest
     *   turini oladi — ruxsat keyinroq berilsa ham joylashuv imkoniyati saqlanadi.
     * - API < 29: FGS turlari yo'q.
     */
    private fun resolveServiceType(withLocation: Boolean): Int? = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE -> {
            val specialUse = ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            if (withLocation) specialUse or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION else specialUse
        }
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && withLocation ->
            ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
        else -> null
    }

    /**
     * PARVOZ PATCH (2): LOCATION'li urinish rad etilgandan keyingi tur — joylashuvsiz.
     * API 29-33 da aniq "turi yo'q" (0) uzatiladi, chunki turisiz chaqiruv
     * manifestdagi location bitini qaytadan qo'yardi.
     */
    private fun fallbackServiceType(): Int? = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE ->
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> FGS_TYPE_NONE
        else -> null
    }

    private fun hasLocationType(serviceType: Int?): Boolean =
        serviceType != null && (serviceType and ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION) != 0

    /** PARVOZ PATCH (2): aniq yoki taxminiy joylashuv ruxsati berilganmi. */
    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
        return fine == PackageManager.PERMISSION_GRANTED || coarse == PackageManager.PERMISSION_GRANTED
    }

    private fun isStartNotAllowed(e: Exception): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            e is ForegroundServiceStartNotAllowedException

    @SuppressLint("WrongConstant")
    private fun startForegroundWithType(serviceType: Int?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createNotificationChannel()
        }

        val serviceId = notificationOptions.serviceId
        val notification = createNotification()
        if (serviceType != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(serviceId, notification, serviceType)
        } else {
            startForeground(serviceId, notification)
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun createNotificationChannel() {
        val channelId = notificationOptions.channelId
        val channelName = notificationOptions.channelName
        val channelDesc = notificationOptions.channelDescription
        val channelImportance = notificationOptions.channelImportance

        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(channelId) == null) {
            val channel = NotificationChannel(channelId, channelName, channelImportance).apply {
                if (channelDesc != null) {
                    description = channelDesc
                }
                enableVibration(notificationOptions.enableVibration)
                if (!notificationOptions.playSound) {
                    setSound(null, null)
                }
                setShowBadge(notificationOptions.showBadge)
            }
            nm.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        // notification icon
        val icon = notificationContent.icon
        val iconResId = getIconResId(icon)
        val iconBackgroundColor = icon?.backgroundColorRgb?.let(::getRgbColor)

        // notification intent
        val contentIntent = getContentIntent()
        val deleteIntent = getDeleteIntent()

        // notification actions
        var needsRebuildButtons = false
        val prevButtons = prevNotificationContent?.buttons
        val currButtons = notificationContent.buttons
        if (prevButtons != null) {
            if (prevButtons.size != currButtons.size) {
                needsRebuildButtons = true
            } else {
                for (i in currButtons.indices) {
                    if (prevButtons[i] != currButtons[i]) {
                        needsRebuildButtons = true
                        break
                    }
                }
            }
        } else {
            needsRebuildButtons = true
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val builder = Notification.Builder(this, notificationOptions.channelId)
            builder.setOngoing(true)
            builder.setShowWhen(notificationOptions.showWhen)
            builder.setSmallIcon(iconResId)
            builder.setContentIntent(contentIntent)
            builder.setContentTitle(notificationContent.title)
            builder.setContentText(notificationContent.text)
            builder.style = Notification.BigTextStyle()
            builder.setVisibility(notificationOptions.visibility)
            builder.setOnlyAlertOnce(notificationOptions.onlyAlertOnce)
            if (iconBackgroundColor != null) {
                builder.setColor(iconBackgroundColor)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                builder.setDeleteIntent(deleteIntent)
            }

            val actions = buildNotificationActions(currButtons, needsRebuildButtons)
            for (action in actions) {
                builder.addAction(action)
            }

            return builder.build()
        } else {
            val builder = NotificationCompat.Builder(this, notificationOptions.channelId)
            builder.setOngoing(true)
            builder.setShowWhen(notificationOptions.showWhen)
            builder.setSmallIcon(iconResId)
            builder.setContentIntent(contentIntent)
            builder.setContentTitle(notificationContent.title)
            builder.setContentText(notificationContent.text)
            builder.setStyle(NotificationCompat.BigTextStyle().bigText(notificationContent.text))
            builder.setVisibility(notificationOptions.visibility)
            builder.setOnlyAlertOnce(notificationOptions.onlyAlertOnce)
            if (iconBackgroundColor != null) {
                builder.color = iconBackgroundColor
            }
            if (!notificationOptions.enableVibration) {
                builder.setVibrate(longArrayOf(0L))
            }
            if (!notificationOptions.playSound) {
                builder.setSound(null)
            }
            builder.priority = notificationOptions.priority

            val actions = buildNotificationCompatActions(currButtons, needsRebuildButtons)
            for (action in actions) {
                builder.addAction(action)
            }

            return builder.build()
        }
    }

    private fun updateNotification() {
        val serviceId = notificationOptions.serviceId
        val notification = createNotification()
        val nm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            getSystemService(NotificationManager::class.java)
        } else {
            // crash 23+
            ContextCompat.getSystemService(this, NotificationManager::class.java)
        }
        nm?.notify(serviceId, notification)
    }

    /**
     * PARVOZ PATCH (1): WakeLock va WifiLock HECH QACHON olinmaydi — options'dagi
     * allowWakeLock / allowWifiLock (plagin standarti allowWakeLock=true!) e'tiborsiz.
     * Muddatsiz PARTIAL_WAKE_LOCK telefonni 24/7 uyg'oq ushlab, batareyani yeb
     * qo'yardi. Fon ishi native 5 daqiqalik alarm + qisqa vaqtli wakelock bilan
     * (ilova kodi) bajariladi. releaseLockMode() saqlangan.
     */
    private fun acquireLockMode() {
        if (foregroundTaskOptions.allowWakeLock || foregroundTaskOptions.allowWifiLock) {
            Log.d(TAG, "allowWakeLock/allowWifiLock are ignored (Parvoz patch: no permanent locks)")
        }
    }

    private fun releaseLockMode() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
                wakeLock = null
            }
        }

        wifiLock?.let {
            if (it.isHeld) {
                it.release()
                wifiLock = null
            }
        }
    }

    private fun createForegroundTask() {
        destroyForegroundTask()

        task = ForegroundTask(
            context = this,
            serviceStatus = foregroundServiceStatus,
            taskData = foregroundTaskData,
            taskEventAction = foregroundTaskOptions.eventAction,
            taskLifecycleListener = taskLifecycleListeners
        )
    }

    private fun updateForegroundTask() {
        task?.update(taskEventAction = foregroundTaskOptions.eventAction)
    }

    private fun destroyForegroundTask() {
        task?.destroy()
        task = null
    }

    private fun getIconResId(icon: NotificationIcon?): Int {
        try {
            val packageManager = applicationContext.packageManager
            val packageName = applicationContext.packageName
            val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)

            // application icon
            if (icon == null) {
                return appInfo.icon
            }

            // custom icon
            val metaData = appInfo.metaData
            if (metaData != null) {
                return metaData.getInt(icon.metaDataName)
            }

            return 0
        } catch (e: Exception) {
            Log.e(TAG, "getIconResId($icon)", e)
            return 0
        }
    }

    private fun getContentIntent(): PendingIntent {
        val packageManager = applicationContext.packageManager
        val packageName = applicationContext.packageName
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            putExtra(INTENT_DATA_NAME, ACTION_NOTIFICATION_PRESSED)

            // set initialRoute
            val initialRoute = notificationContent.initialRoute
            if (initialRoute != null) {
                putExtra("route", initialRoute)
            }
        }

        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }

        return PendingIntent.getActivity(this, RequestCode.NOTIFICATION_PRESSED, intent, flags)
    }

    private fun getDeleteIntent(): PendingIntent {
        val intent = Intent(ACTION_NOTIFICATION_DISMISSED).apply {
            setPackage(packageName)
        }

        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }

        return PendingIntent.getBroadcast(this, RequestCode.NOTIFICATION_DISMISSED, intent, flags)
    }

    private fun getRgbColor(rgb: String): Int? {
        val rgbSet = rgb.split(",")
        return if (rgbSet.size == 3) {
            Color.rgb(rgbSet[0].toInt(), rgbSet[1].toInt(), rgbSet[2].toInt())
        } else {
            null
        }
    }

    private fun getTextSpan(text: String, color: Int?): Spannable {
        return if (color != null) {
            SpannableString(text).apply {
                setSpan(ForegroundColorSpan(color), 0, length, 0)
            }
        } else {
            SpannableString(text)
        }
    }

    private fun buildNotificationActions(
        buttons: List<NotificationButton>,
        needsRebuild: Boolean = false
    ): List<Notification.Action> {
        val actions = mutableListOf<Notification.Action>()
        for (i in buttons.indices) {
            val intent = Intent(ACTION_NOTIFICATION_BUTTON_PRESSED).apply {
                setPackage(packageName)
                putExtra(INTENT_DATA_NAME, buttons[i].id)
            }
            var flags = PendingIntent.FLAG_IMMUTABLE
            if (needsRebuild) {
                flags = flags or PendingIntent.FLAG_CANCEL_CURRENT
            }
            val textColor = buttons[i].textColorRgb?.let(::getRgbColor)
            val text = getTextSpan(buttons[i].text, textColor)
            val pendingIntent =
                PendingIntent.getBroadcast(this, i + 1, intent, flags)
            val action = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Notification.Action.Builder(null, text, pendingIntent).build()
            } else {
                Notification.Action.Builder(0, text, pendingIntent).build()
            }
            actions.add(action)
        }

        return actions
    }

    private fun buildNotificationCompatActions(
        buttons: List<NotificationButton>,
        needsRebuild: Boolean = false
    ): List<NotificationCompat.Action> {
        val actions = mutableListOf<NotificationCompat.Action>()
        for (i in buttons.indices) {
            val intent = Intent(ACTION_NOTIFICATION_BUTTON_PRESSED).apply {
                setPackage(packageName)
                putExtra(INTENT_DATA_NAME, buttons[i].id)
            }
            var flags = PendingIntent.FLAG_IMMUTABLE
            if (needsRebuild) {
                flags = flags or PendingIntent.FLAG_CANCEL_CURRENT
            }
            val textColor = buttons[i].textColorRgb?.let(::getRgbColor)
            val text = getTextSpan(buttons[i].text, textColor)
            val pendingIntent =
                PendingIntent.getBroadcast(this, i + 1, intent, flags)
            val action = NotificationCompat.Action.Builder(0, text, pendingIntent).build()
            actions.add(action)
        }

        return actions
    }
}