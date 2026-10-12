// ─────────────────────────────────────────────────────────────────────
// IosRestrictionsSyncService — ota-ona siyosatini Family Controls'ga
// ─────────────────────────────────────────────────────────────────────
//
// Backend'dan faqat ilova-nomisiz siyosat olinadi (BLOCK jadvallar,
// "barcha ilovalarni bloklash", virtual "iPhone: tanlangan ilovalar"
// elementiga qo'yilgan blok/kunlik limit va rejimlar) va native tomonga
// beriladi. Jadval chegaralarida va limit tugaganda cheklovni ParvozMonitor
// kengaytmasi o'zi yoqadi — ilova yopiq bo'lsa ham. iOS'da haqiqiy ilovalar
// ro'yxati/usage HECH QACHON serverga yuborilmaydi — faqat bitta virtual
// element (ota-ona Android'dan boshqarishi uchun, qarang IosShieldPolicy).
//
// FAIL-CLOSED: tarmoq xatosida oxirgi siyosat o'zgarmaydi (Android bilan
// bir xil) — aviarejim cheklovni o'chirib yubormasin.
//
// Qo'shimcha vaqt: ota-ona tasdiqlagan grant (`GET /unlock-requests/active`)
// native'ga beriladi — u tugaganda kengaytma cheklovni o'zi qaytaradi.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';

import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_device_policy_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_installed_apps_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_unlock_request_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restrictions_sync.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_routine_repository.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';
import 'package:farzandim_child/features/screen_time/data/screen_time_channel.dart';
import 'package:farzandim_child/features/screen_time/domain/ios_shield_policy.dart';

class IosRestrictionsSyncService implements RestrictionsSync {
  IosRestrictionsSyncService({
    required BackendScheduleRepository scheduleRepo,
    required BackendDevicePolicyRepository devicePolicyRepo,
    required BackendUnlockRequestRepository unlockRepo,
    required BackendAppLimitRepository appLimitRepo,
    required BackendRoutineRepository routineRepo,
    required BackendInstalledAppsRepository installedAppsRepo,
    required ScreenTimeChannel channel,
    DateTime Function()? clock,
    bool shouldPublishSelection = true,
  }) : _shouldPublishSelection = shouldPublishSelection,
       _scheduleRepo = scheduleRepo,
       _devicePolicyRepo = devicePolicyRepo,
       _unlockRepo = unlockRepo,
       _appLimitRepo = appLimitRepo,
       _routineRepo = routineRepo,
       _installedAppsRepo = installedAppsRepo,
       _channel = channel,
       _clock = clock ?? DateTime.now;

  /// Ilova ochiq paytdagi davriy yangilash. Ilova yopiq bo'lsa jadvallarni
  /// kengaytma bajaradi, "darhol bloklash" esa WS/push bilan keladi.
  static const syncInterval = Duration(seconds: 60);
  static const _prefsKeyBlockAllCache = 'screenTime.blockAllCache.v1';

  /// Ota-ona ro'yxatidagi `lastSeenAt` eskirmasligi uchun shu oraliqda
  /// virtual element qayta yuboriladi.
  static const _selectionRepublishInterval = Duration(hours: 12);

  /// Fon push'i uchun iOS ~30 soniya beradi (firebase_messaging 25 s da
  /// majburan tugatadi) — sync shundan oldin tugashi kerak.
  static const _backgroundSyncTimeout = Duration(seconds: 20);

  /// Ketma-ketlik: bir vaqtda faqat bitta sync (fon nusxasi bilan ham).
  /// Ish paytida kelgan so'rov tugagach yana bir marta ishlatiladi — eski
  /// ma'lumot bilan tugagan sync yangi siyosat ustidan yozib qo'ymasin.
  static Future<void>? _running;
  static bool _isRerunRequested = false;

  /// easy_localization tanlangan tilni shu kalitda saqlaydi ("uz", "ru_RU").
  static const _prefsKeyLocale = 'locale';

  final BackendScheduleRepository _scheduleRepo;
  final BackendDevicePolicyRepository _devicePolicyRepo;
  final BackendUnlockRequestRepository _unlockRepo;
  final BackendAppLimitRepository _appLimitRepo;
  final BackendRoutineRepository _routineRepo;
  final BackendInstalledAppsRepository _installedAppsRepo;
  final ScreenTimeChannel _channel;
  final bool _shouldPublishSelection;
  final DateTime Function() _clock;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  String? _childId;

  /// Native'ga oxirgi berilgan grant oxiri; `null` — grant yo'q (yoki hali
  /// bilinmaydi: start'dan keyin birinchi sync eski holatni tozalaydi).
  DateTime? _appliedUnlockUntil;
  bool _unlockStateKnown = false;

  /// Shu jarayonda virtual element oxirgi marta yuborilgan payt va nom (til
  /// o'zgarsa qayta yuboriladi). Yuborish boshlanishidayoq belgilanadi —
  /// parallel sync'lar ikkinchi marta yubormasin.
  DateTime? _selectionPublishedAt;
  String? _selectionPublishedName;

  /// Ilova fonda/yopiq paytida kelgan jim push (`restrictions_sync`) uchun:
  /// Riverpod'siz, taymersiz bitta sync. Ota-ona Android'da blok/limit/rejimni
  /// o'zgartirsa iPhone ilova ochilishini kutmaydi. Best-effort — native
  /// kanal shu dvigatelda bo'lmasa sync jim tugaydi.
  static Future<void> syncInBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final childId = prefs.getString('childId');
    if (childId == null) return;
    final dio = createBackendDio(TokenStorage());
    final service = IosRestrictionsSyncService(
      scheduleRepo: BackendScheduleRepository(dio: dio),
      devicePolicyRepo: BackendDevicePolicyRepository(dio: dio),
      unlockRepo: BackendUnlockRequestRepository(dio: dio),
      appLimitRepo: BackendAppLimitRepository(dio: dio),
      routineRepo: BackendRoutineRepository(dio: dio),
      installedAppsRepo: BackendInstalledAppsRepository(dio: dio),
      channel: const ScreenTimeChannel(),
      // Virtual element ilova ochiq paytda yuboriladi — fon vaqti tejaladi.
      shouldPublishSelection: false,
    ).._childId = childId;
    try {
      await service.sync().timeout(_backgroundSyncTimeout);
    } on TimeoutException {
      debugPrint('IosRestrictionsSync: fon sync vaqti tugadi');
    } finally {
      dio.close();
    }
  }

  @override
  void start({required String childId}) {
    _childId = childId;
    _unlockStateKnown = false;
    _selectionPublishedAt = null;
    _selectionPublishedName = null;
    _timer?.cancel();
    unawaited(sync());
    _timer = Timer.periodic(syncInterval, (_) => unawaited(sync()));
    // Fondan qaytganda darhol — iOS fonda taymer/WS'ni to'xtatgan bo'lishi
    // mumkin, ota-ona o'zgarishi 60 s kutmasin.
    _lifecycle ??= AppLifecycleListener(onResume: () => unawaited(sync()));
  }

  @override
  Future<void> sync() {
    final childId = _childId;
    if (childId == null) return Future.value();
    final running = _running;
    if (running != null) {
      _isRerunRequested = true;
      return running;
    }
    final loop = _syncLoop(childId).whenComplete(() => _running = null);
    _running = loop;
    return loop;
  }

  Future<void> _syncLoop(String childId) async {
    do {
      _isRerunRequested = false;
      await _syncOnce(childId);
    } while (_isRerunRequested);
  }

  Future<void> _syncOnce(String childId) async {
    String? languageCode;
    try {
      final prefs = await SharedPreferences.getInstance();
      languageCode = prefs.getString(_prefsKeyLocale)?.split('_').first;
      await _applyBackendPolicy(childId, languageCode);
    } catch (e) {
      debugPrint('IosRestrictionsSync xato: $e');
    }
    // Siyosatdan KEYIN — sekin tarmoqda bloklash kechikmasin.
    if (_shouldPublishSelection) {
      await _publishSelectionApp(childId, languageCode);
    }
  }

  Future<void> _applyBackendPolicy(String childId, String? languageCode) async {
    final (schedules, limits, routines) = await (
      _scheduleRepo.getSchedules(childId),
      _appLimitRepo.getLimits(childId),
      _routineRepo.getRoutines(childId),
    ).wait;
    // FAIL-CLOSED: birortasi kelmasa — oxirgi siyosat o'zgarmaydi.
    if (schedules == null || limits == null || routines == null) {
      debugPrint("IosRestrictionsSync: tarmoq yo'q — oxirgi siyosat saqlanadi");
      return;
    }
    final devicePolicy = await _devicePolicyRepo.getDevicePolicy(childId);
    final blockAll = await _resolveBlockAll(devicePolicy.blockAllApps);
    final policy = IosShieldPolicy.fromBackend(
      schedules: schedules,
      blockAll: blockAll,
      routines: routines,
      limits: limits,
    );
    final isBlocking = await _channel.applyPolicy(
      policy,
      languageCode: languageCode,
    );
    await _syncUnlock();
    debugPrint(
      'IosRestrictionsSync: windows=${policy.windows.length} '
      'blockAll=${policy.blockAll} limit=${policy.dailyLimitMinutes} '
      'blocking=$isBlocking',
    );
  }

  /// Virtual "iPhone: tanlangan ilovalar" elementini ota-ona ro'yxatiga
  /// yuboradi: ishga tushganda, til o'zgarganda va har
  /// [_selectionRepublishInterval]da. Xato bo'lsa keyingi sync qayta uradi.
  Future<void> _publishSelectionApp(
    String childId,
    String? languageCode,
  ) async {
    ScreenTimeStatus? status;
    try {
      status = await _channel.status();
    } catch (e) {
      debugPrint('IosRestrictionsSync: holat o\'qilmadi: $e');
    }
    final name = selectionAppName(languageCode, status);
    final now = _clock();
    final publishedAt = _selectionPublishedAt;
    final isFresh =
        publishedAt != null &&
        now.difference(publishedAt) < _selectionRepublishInterval &&
        _selectionPublishedName == name;
    if (isFresh) return;
    _selectionPublishedAt = now;
    _selectionPublishedName = name;
    final isSaved = await _installedAppsRepo.upsertInstalledApps(
      childId: childId,
      apps: [
        {
          'packageName': IosShieldPolicy.selectionPackage,
          'appName': name,
          'isSystem': false,
        },
      ],
    );
    if (!isSaved) {
      _selectionPublishedAt = null;
      _selectionPublishedName = null;
    }
  }

  /// Ota-ona ilovasida ko'rinadigan nom (bola ilovasi tilida) + holat:
  /// himoya o'chiqmi, nechta ilova/toifa/sayt tanlangan. Faqat sonlar —
  /// qaysi ilovalar ekani telefondan chiqmaydi (Apple sharti).
  @visibleForTesting
  static String selectionAppName(
    String? languageCode, [
    ScreenTimeStatus? status,
  ]) {
    final texts = switch (languageCode) {
      'ru' => _ruTexts,
      'en' => _enTexts,
      _ => _uzTexts,
    };
    final detail = switch (status) {
      null => null,
      ScreenTimeStatus(isAuthorized: false) => texts.off,
      ScreenTimeStatus(hasSelection: false) => texts.empty,
      final s => [
        if (s.apps > 0) texts.apps(s.apps),
        if (s.categories > 0) texts.categories(s.categories),
        if (s.webDomains > 0) texts.sites(s.webDomains),
      ].join(', '),
    };
    return detail == null ? texts.title : '${texts.title} · $detail';
  }

  static final _uzTexts = (
    title: 'iPhone: tanlangan ilovalar',
    off: "himoya o'chiq",
    empty: 'hali tanlanmagan',
    apps: (int n) => '$n ta ilova',
    categories: (int n) => '$n ta toifa',
    sites: (int n) => '$n ta sayt',
  );
  static final _ruTexts = (
    title: 'iPhone: выбранные приложения',
    off: 'защита выключена',
    empty: 'ничего не выбрано',
    apps: (int n) => 'приложений: $n',
    categories: (int n) => 'категорий: $n',
    sites: (int n) => 'сайтов: $n',
  );
  static final _enTexts = (
    title: 'iPhone: selected apps',
    off: 'protection off',
    empty: 'nothing selected',
    apps: (int n) => '$n apps',
    categories: (int n) => '$n categories',
    sites: (int n) => '$n websites',
  );

  /// Ota-ona tasdiqlagan qo'shimcha vaqt → native. So'rov yiqilsa holat
  /// o'zgarmaydi; o'zgarmagan grant qayta yuborilmaydi.
  Future<void> _syncUnlock() async {
    final grants = await _unlockRepo.getActiveGrants();
    if (grants == null) return;
    final now = _clock();
    final active = grants.where((g) => g.expiresAt.isAfter(now)).toList();
    if (active.isEmpty) {
      if (_unlockStateKnown && _appliedUnlockUntil == null) return;
      await _channel.clearUnlock();
      _appliedUnlockUntil = null;
      _unlockStateKnown = true;
      return;
    }
    final latest = active.reduce(
      (a, b) => a.expiresAt.isAfter(b.expiresAt) ? a : b,
    );
    if (_unlockStateKnown && _appliedUnlockUntil == latest.expiresAt) return;
    final minutes = (latest.expiresAt.difference(now).inSeconds / 60).ceil();
    await _channel.grantUnlock(
      until: latest.expiresAt,
      minutes: minutes < 1 ? 1 : minutes,
    );
    _appliedUnlockUntil = latest.expiresAt;
    _unlockStateKnown = true;
  }

  /// Qurilma-siyosati so'rovi alohida yiqilsa (`null`) — oxirgi ma'lum
  /// qiymat, aks holda "hammasini bloklash" tarmoq uzilishida o'chib qolardi.
  Future<bool> _resolveBlockAll(bool? fetched) async {
    final prefs = await SharedPreferences.getInstance();
    if (fetched != null) {
      await prefs.setBool(_prefsKeyBlockAllCache, fetched);
      return fetched;
    }
    return prefs.getBool(_prefsKeyBlockAllCache) ?? false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}
