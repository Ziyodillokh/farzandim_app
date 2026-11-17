# flutter_foreground_task 8.17.0 — Parvoz yamoqlari (1.0.20)

Manba: pub.dev `flutter_foreground_task` 8.17.0 (`~/.pub-cache/hosted/pub.dev/flutter_foreground_task-8.17.0`).
Nusxalangan: `lib/`, `android/`, `ios/`, `pubspec.yaml`, `LICENSE`, `README.md`, `CHANGELOG.md`.
Nusxalanmagan: `example/`, `test/`, `documentation/`, `.iml`, upstream `analysis_options.yaml`
(o'rniga `analysis_options.yaml` — vendor kodi ilovaning `flutter analyze`'idan chiqarilgan, `third_party/health` kabi).

Ulanishi: `farzandim_child/pubspec.yaml` → `dependency_overrides: flutter_foreground_task: path: third_party/flutter_foreground_task`
(`dependencies` dagi `flutter_foreground_task: ^8.17.0` qatori qoladi).

**Dart (`lib/`) va iOS (`ios/`) qismi O'ZGARMAGAN.** Faqat Android Kotlin yamalgan. Har bir yamoq kodda
`// PARVOZ PATCH (n)` izohi bilan belgilangan. Kotlin fayllar upstream'dagidek CRLF qator oxiri bilan saqlangan
(diff toza chiqishi uchun).

Ochiq API'lar O'ZGARMAGAN (ilova native kodi ularni chaqiradi): `ForegroundService.sendData(Any?)`,
`ForegroundService.isRunningServiceState`, `FlutterForegroundTaskPlugin.addTaskLifecycleListener`,
`FlutterForegroundTaskLifecycleListener.onEngineCreate`, `ForegroundServiceStatus`, `ForegroundServiceAction`.

## 1. Doimiy WakeLock / WifiLock yo'q — `service/ForegroundService.kt`

`acquireLockMode()` endi hech narsa olmaydi (`allowWakeLock` / `allowWifiLock` e'tiborsiz — plagin standarti
`allowWakeLock=true`!). `releaseLockMode()` saqlangan.

Nega: muddatsiz `PARTIAL_WAKE_LOCK` + `WIFI_MODE_FULL_HIGH_PERF` FGS ishlagan butun vaqt (24/7) ushlanardi —
SoC hech qachon uxlamasdi, Doze ta'sir qilmasdi (FGS procstate), OEM batareya menejerlari ilovani "ko'p quvvat
sarflovchi" deb to'xtatardi. Bloklash ekran yoqiq paytda ishlaydi (CPU baribir uyg'oq); fon ishi native 5 daqiqalik
alarm + qisqa vaqtli wakelock (ilova kodi) orqali.
Topilmalar: `kill-native-fgs-wakelock-wifilock`, `bat-native-fgs-wakelock`, `bat-dart-wakelock-wifilock`,
`ui-fgs-permanent-wakelock`.

## 2. FGS turi ish vaqtida tanlanadi — `service/ForegroundService.kt`

Upstream `startForeground(id, n, FOREGROUND_SERVICE_TYPE_MANIFEST)` chaqirardi (manifestdagi `location`).
Endi `resolveServiceType()`:

| API | Tur |
| --- | --- |
| 34+ | `SPECIAL_USE` har doim; `LOCATION` faqat `ACCESS_FINE_LOCATION` yoki `ACCESS_COARSE_LOCATION` berilgan bo'lsa |
| 29–33 | ruxsat bo'lsa `LOCATION`, aks holda `startForeground(id, n)` (turisiz) |
| < 29 | `startForeground(id, n)` |

`LOCATION` qo'shilgan urinish xato bersa (Android 14+ `SecurityException`: fondan start — boot, APK yangilanishi,
START_STICKY — va faqat "ilova ishlatilayotganda" ruxsati) darhol `fallbackServiceType()` bilan qayta uriniladi:
API 34+ da faqat `SPECIAL_USE`, API 29–33 da aniq "turi yo'q" (0).

Izoh (API 29–33): 2 argumentli `startForeground` API 29+ da manifest turini (`location|specialUse`) oladi. Bu
versiyalar FGS turi uchun ruxsat TALAB QILMAYDI (SecurityException yo'q), location biti esa ruxsat keyinroq
(servis UI'dan boshlangandan so'ng) berilsa ham joylashuv imkoniyatini saqlaydi. Shuning uchun asosiy yo'lda
turisiz chaqiruv, qayta urinishda esa aniq 0 ishlatiladi.

Talab: ilova manifestida servis `android:foregroundServiceType="location|specialUse"` +
`PROPERTY_SPECIAL_USE_FGS_SUBTYPE` bilan e'lon qilingan bo'lishi SHART (5-band). Ruxsatlar:
`FOREGROUND_SERVICE_LOCATION`, `FOREGROUND_SERVICE_SPECIAL_USE`.

Nega: `location` turidagi FGS fondan qayta ishga tushganda Android 14+ `SecurityException` tashlab BUTUN jarayonni
(RestrictionService ham shu jarayonda) yiqitardi → START_STICKY qayta-qayta crash → tizim jarayonni "bad" deb
belgilab, barcha fon startlarini rad etardi (bloklash, heartbeat, ring, joylashuv soatlab ishlamasdi).
Topilmalar: `kill-native-loc-fgs-restart-crash`, `kill-location-fgs-restart-crash`,
`rob-dart-fgs-location-restart-crash`, `ui-fgs-location-type-boot-crash`.

## 3. startForeground himoyalari — `service/ForegroundService.kt`

- `tryStartForeground()` hech qachon exception tashlamaydi.
  - `ForegroundServiceStartNotAllowedException` (API 31+, faqat `startForegroundService` bo'lmagan startlarda, masalan
    START_STICKY restart fonda) → `Log.w`, qayta urinilmaydi.
  - Boshqa xato → `Log.e` (LOCATION bo'lgan bo'lsa avval LOCATION'siz qayta urinish).
- Muvaffaqiyatsiz bo'lsa: Flutter task (engine) YARATILMAYDI, `stopSelf(startId)` (orada yangi start kelgan bo'lsa
  servis to'xtamaydi), `START_NOT_STICKY`.
- Start xatosidan keyingi `onDestroy` restart-alarm QO'YMAYDI (fonda baribir ruxsat yo'q — 5 s'lik start/stop sikli
  bo'lmasin). Keyingi start: boot, ilova ochilishi, native tick.
- `startForegroundService()` bilan kelgan, hali foreground bo'lmagan instance HECH QACHON `startForeground`'siz
  to'xtamaydi/qolmaydi (aks holda "Context.startForegroundService() did not then call Service.startForeground()" /
  `ForegroundServiceDidNotStartInTimeException` crash):
  - `API_STOP` (intent != null) → avval `startForeground` (joylashuvsiz), keyin to'xtash;
  - `API_UPDATE` yangi instance'da → oddiy start kabi;
  - noma'lum action yangi instance'da → oddiy start kabi.
- Avval foreground bo'lgan servisda qayta `startForeground` xato bersa, servis eski tur/notification bilan ishlashda
  davom etadi (to'xtatilmaydi).
- `_isRunningServiceState` faqat muvaffaqiyatli `startForeground`'dan keyin `true`.

## 4. RebootReceiver / RestartReceiver — `service/RebootReceiver.kt`, `service/RestartReceiver.kt`

`onReceive` tanasi to'liq `try/catch` ichida; har bir `ContextCompat.startForegroundService` alohida `try/catch`
(faqat log). `RestartReceiver.setRestartAlarm` / `cancelRestartAlarm` ham himoyalangan (ular `onDestroy` /
`onTaskRemoved` ichidan chaqiriladi).

Nega: boot / `MY_PACKAGE_REPLACED` / restart alarm fondan keladi — Android 12+ da `startForegroundService`
`ForegroundServiceStartNotAllowedException` tashlashi mumkin; receiver'dagi har qanday xato jarayonni yiqitardi.

## 5. Ilova manifesti (`android/app/src/main/AndroidManifest.xml`, plagin tashqarisida)

```xml
<service
    android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
    android:foregroundServiceType="location|specialUse"
    android:exported="false"
    android:stopWithTask="false"
    tools:replace="android:foregroundServiceType"
    tools:targetApi="34">
    <property
        android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
        android:value="Parental control: keeps app-blocking schedules and child safety status in sync"
        tools:targetApi="34"/>
</service>
```

Manifest turi — ruxsat etilgan turlar to'plami; haqiqiy tur 2-banddagi kod bilan tanlanadi (uzatilgan tur manifest
turining qism-to'plami bo'lishi shart).

## 6. `sendData` istalgan thread'dan xavfsiz — `service/ForegroundService.kt`

`ForegroundService.sendData(Any?)` (imzo o'zgarmagan): main thread'da bo'lmasa `Handler(mainLooper)` orqali
uzatiladi; `invokeMethod` xatosi `try/catch` bilan log qilinadi. Nega: `MethodChannel` faqat main thread'da ishlaydi,
native triggerlar esa (masalan FCM `onMessageReceived`) worker thread'dan kelishi mumkin.

## Qayta vendor qilish / tekshirish

1. Yangi versiyani shu ro'yxat bo'yicha nusxalang, `pubspec.yaml` dagi `PARVOZ VENDOR` izohini va
   `analysis_options.yaml` ni saqlang.
2. Yamoqlarni qayta qo'llang: `diff -ru <pub-cache>/flutter_foreground_task-8.17.0/android third_party/flutter_foreground_task/android`
   (`PARVOZ PATCH` izohlarini qidiring). Upstream'da shu muammolar tuzatilgan bo'lsa, tegishli bandni olib tashlang.
3. Qurilmada tekshirish (Android 14+):
   - `adb shell dumpsys power | grep -i wake_lock` — `ForegroundService:WakeLock` bo'lmasligi kerak.
   - Joylashuvni "Faqat ilova ishlatilayotganda" qiling → telefonni qayta yoqing →
     `adb logcat | grep -E "Starting FGS with type location|ForegroundService"` — crash yo'q, servis `specialUse`
     bilan ishlayapti (`adb shell dumpsys activity services com.farzandim.growth | grep -iE "isForeground|types|foregroundServiceType"`).
