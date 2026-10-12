import 'package:dio/dio.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_device_policy_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_installed_apps_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_unlock_request_repository.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_routine_repository.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';
import 'package:farzandim_child/features/screen_time/data/ios_restrictions_sync_service.dart';
import 'package:farzandim_child/features/screen_time/data/screen_time_channel.dart';
import 'package:farzandim_child/features/screen_time/domain/ios_shield_policy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('uz.parvoz.growth/screen_time');
const _childId = 'child-1';

/// Backend javoblarini soxtalashtiradi: `null` qiymat = tarmoq xatosi.
class _FakeBackend extends Interceptor {
  Object? schedules = {
    'schedules': [
      {
        'id': 's1',
        'startTime': '21:00',
        'endTime': '07:00',
        'daysOfWeek': [1, 2, 3],
        'action': 'BLOCK',
        'isActive': true,
      },
    ],
  };
  Object? devicePolicy = {'blockAllApps': false};
  Object? grants = {'grants': <Object>[], 'count': 0};
  Object? limits = {'limits': <Object>[], 'count': 0};
  Object? routines = {'routines': <Object>[], 'count': 0};
  Object? installedAppsResult = {'ok': true};
  final publishedApps = <Object?>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;
    if (path.endsWith('/installed-apps')) {
      publishedApps.add(options.data);
    }
    final data = switch (path) {
      _ when path.endsWith('/schedules') => schedules,
      _ when path.endsWith('/unlock-requests/active') => grants,
      _ when path.endsWith('/app-limits') => limits,
      _ when path.endsWith('/routines') => routines,
      _ when path.endsWith('/installed-apps') => installedAppsResult,
      _ => devicePolicy,
    };
    if (data == null) {
      handler.reject(DioException(requestOptions: options));
      return;
    }
    handler.resolve(
      Response(requestOptions: options, data: data, statusCode: 200),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 10, 10, 9);
  late _FakeBackend backend;
  late List<Map<Object?, Object?>> applied;
  late List<MethodCall> unlockCalls;
  late IosRestrictionsSyncService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({'locale': 'ru_RU'});
    backend = _FakeBackend();
    applied = [];
    unlockCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'applyPolicy') {
        applied.add(Map<Object?, Object?>.from(call.arguments as Map));
      }
      if (call.method == 'grantUnlock' || call.method == 'clearUnlock') {
        unlockCalls.add(call);
      }
      return {
        'authorization': 'approved',
        'blocking': false,
        'scheduleErrors': <String>[],
      };
    });
    final dio = Dio()..interceptors.add(backend);
    service = IosRestrictionsSyncService(
      scheduleRepo: BackendScheduleRepository(dio: dio),
      devicePolicyRepo: BackendDevicePolicyRepository(dio: dio),
      unlockRepo: BackendUnlockRequestRepository(dio: dio),
      appLimitRepo: BackendAppLimitRepository(dio: dio),
      routineRepo: BackendRoutineRepository(dio: dio),
      installedAppsRepo: BackendInstalledAppsRepository(dio: dio),
      channel: const ScreenTimeChannel(_channel),
      clock: () => now,
    );
  });

  tearDown(() {
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<void> startAndSync() async {
    service.start(childId: _childId);
    await service.sync();
  }

  test('jadval va "hammasini bloklash" native siyosatga uzatiladi', () async {
    backend.devicePolicy = {'blockAllApps': true};

    await startAndSync();

    expect(applied.last, {
      'blockAll': true,
      'windows': [
        {'start': 1260, 'end': 420, 'weekdays': [1, 2, 3]},
      ],
      'language': 'ru',
    });
  });

  test('jadval kelmasa (tarmoq yo\'q) siyosat o\'zgartirilmaydi', () async {
    backend.schedules = null;

    await startAndSync();

    expect(applied, isEmpty);
  });

  test('qurilma-siyosati yiqilsa oxirgi "hammasini bloklash" saqlanadi',
      () async {
    backend.devicePolicy = {'blockAllApps': true};
    await startAndSync();

    backend.devicePolicy = null;
    await service.sync();

    expect(applied.last['blockAll'], isTrue);
  });

  group('virtual "iPhone: tanlangan ilovalar" elementi', () {
    const selection = IosShieldPolicy.selectionPackage;

    test('ota-ona ro\'yxatiga bola tilida bir marta yuboriladi', () async {
      await startAndSync();
      await service.sync();

      expect(backend.publishedApps, [
        {
          'apps': [
            {
              'packageName': selection,
              'appName': 'iPhone: выбранные приложения',
              'isSystem': false,
            },
          ],
        },
      ]);
    });

    test('yuborish yiqilsa keyingi sync qayta uradi', () async {
      backend.installedAppsResult = null;
      await startAndSync();

      final failedAttempts = backend.publishedApps.length;

      backend.installedAppsResult = {'ok': true};
      await service.sync();
      await service.sync();

      // Har yiqilgan sync qayta urinadi; muvaffaqiyatdan keyin yuborilmaydi.
      expect(failedAttempts, greaterThan(0));
      expect(backend.publishedApps, hasLength(failedAttempts + 1));
    });

    test('ota-ona bloklasa (limit 0) tanlov doim bloklanadi', () async {
      backend.limits = {
        'limits': [
          {'id': 'l1', 'packageName': selection, 'dailyLimitMs': 0},
        ],
      };

      await startAndSync();

      expect(applied.last['blockAll'], isTrue);
      expect(applied.last.containsKey('dailyLimitMinutes'), isFalse);
    });

    test('kunlik limit daqiqada native\'ga beriladi', () async {
      backend.limits = {
        'limits': [
          {'id': 'l1', 'packageName': 'com.other', 'dailyLimitMs': 0},
          {'id': 'l2', 'packageName': selection, 'dailyLimitMs': 3600000},
        ],
      };

      await startAndSync();

      expect(applied.last['blockAll'], isFalse);
      expect(applied.last['dailyLimitMinutes'], 60);
    });

    test('tanlov qo\'shilgan rejim oynaga aylanadi', () async {
      backend.schedules = {'schedules': <Object>[]};
      backend.routines = {
        'routines': [
          {
            'id': 'r1',
            'title': 'Maktab',
            'type': 'SCHOOL',
            'startHour': 8,
            'startMinute': 0,
            'endHour': 13,
            'endMinute': 30,
            'weekdays': [1, 2, 3, 4, 5],
            'isActive': true,
            'blockedApps': [selection],
          },
          {
            'id': 'r2',
            'title': 'Sport',
            'type': 'SPORT',
            'startHour': 17,
            'startMinute': 0,
            'endHour': 18,
            'endMinute': 0,
            'weekdays': [6],
            'isActive': true,
            'blockedApps': ['com.android.game'],
          },
        ],
      };

      await startAndSync();

      expect(applied.last['windows'], [
        {'start': 480, 'end': 810, 'weekdays': [1, 2, 3, 4, 5]},
      ]);
    });

    test('limitlar yoki rejimlar kelmasa siyosat o\'zgartirilmaydi', () async {
      backend.limits = null;
      await startAndSync();
      expect(applied, isEmpty);

      backend
        ..limits = {'limits': <Object>[]}
        ..routines = null;
      await service.sync();
      expect(applied, isEmpty);
    });
  });

  test('ish paytida kelgan sync navbatga turadi va oxirgi ma\'lumotni qo\'llaydi',
      () async {
    service.start(childId: _childId);
    final first = service.sync();
    backend.devicePolicy = {'blockAllApps': true};
    final second = service.sync();
    await Future.wait([first, second]);

    expect(applied, hasLength(2));
    expect(applied.last['blockAll'], isTrue);
  });

  test('start() dan oldin sync() hech narsa qilmaydi', () async {
    await service.sync();

    expect(applied, isEmpty);
  });

  group('ota-ona bergan qo\'shimcha vaqt', () {
    Map<String, Object> grant(DateTime expiresAt) => {
          'status': 'APPROVED',
          'expiresAt': expiresAt.toIso8601String(),
          'remainingSeconds': expiresAt.difference(now).inSeconds,
        };

    test('faol grant native\'ga beriladi (eng kech tugaydigani)', () async {
      final later = now.add(const Duration(minutes: 20));
      backend.grants = {
        'grants': [grant(now.add(const Duration(minutes: 5))), grant(later)],
      };

      await startAndSync();

      final call = unlockCalls.last;
      expect(call.method, 'grantUnlock');
      expect(call.arguments, {
        'untilMs': later.millisecondsSinceEpoch,
        'minutes': 20,
      });
    });

    test('o\'zgarmagan grant qayta yuborilmaydi', () async {
      backend.grants = {
        'grants': [grant(now.add(const Duration(minutes: 15)))],
      };

      await startAndSync();
      await service.sync();

      expect(unlockCalls.where((c) => c.method == 'grantUnlock'), hasLength(1));
    });

    test('grant tugasa bir marta tozalanadi', () async {
      backend.grants = {
        'grants': [grant(now.add(const Duration(minutes: 15)))],
      };
      await startAndSync();

      backend.grants = {'grants': <Object>[]};
      await service.sync();
      await service.sync();

      expect(unlockCalls.map((c) => c.method), ['grantUnlock', 'clearUnlock']);
    });

    test('grantlar so\'rovi yiqilsa holat o\'zgarmaydi', () async {
      backend.grants = null;

      await startAndSync();

      expect(unlockCalls, isEmpty);
    });
  });
}
