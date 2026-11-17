// UsageSyncService: taymersiz, ~5 daqiqada bir, ikonsiz statistika,
// o'zgarmagan jamlar qayta yuborilmaydi, o'rnatilgan ilovalar kuniga bir
// marta / yangi paketda, xatoda backoff, plagin yo'q — jim.

import 'package:dio/dio.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_installed_apps_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_sync_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('farzandim/usage_stats');

class _FakeInstalledRepo extends BackendInstalledAppsRepository {
  _FakeInstalledRepo() : super(dio: Dio());

  final usageUploads = <List<Map<String, dynamic>>>[];
  final installedUploads = <List<Map<String, dynamic>>>[];
  bool installedOk = true;

  @override
  Future<bool> upsertAppUsage({
    required String childId,
    required List<Map<String, dynamic>> entries,
  }) async {
    usageUploads.add(entries);
    return true;
  }

  @override
  Future<bool> upsertInstalledApps({
    required String childId,
    required List<Map<String, dynamic>> apps,
  }) async {
    installedUploads.add(apps);
    return installedOk;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late _FakeInstalledRepo repo;
  late DateTime now;
  late List<Map<String, Object>> usage;
  late List<Map<String, Object>> installed;
  late List<MethodCall> calls;

  UsageSyncService build() => UsageSyncService(
    backendRepo: repo,
    statsService: UsageStatsService(),
    childId: 'c1',
    clock: () => now,
  );

  void mockPlugin() {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'hasPermission':
          return true;
        case 'getUsageStats':
          return usage;
        case 'getInstalledApps':
          return installed;
      }
      return null;
    });
  }

  Map<String, Object> app(String pkg, int ms) => {
    'packageName': pkg,
    'appName': pkg,
    'totalTimeMs': ms,
    'lastTimeUsed': 1763000000000,
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = _FakeInstalledRepo();
    now = DateTime.utc(2026, 11, 13, 5);
    usage = [app('com.a', 60000)];
    installed = [
      {'packageName': 'com.a', 'appName': 'A'},
    ];
    calls = [];
    mockPlugin();
  });

  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  test('ikonsiz statistika; 5 daqiqa ichida takrorlanmaydi', () async {
    final service = build();

    await service.syncIfDue();
    now = now.add(const Duration(minutes: 2));
    await service.syncIfDue();

    expect(repo.usageUploads, hasLength(1));
    final statsCall = calls.firstWhere((c) => c.method == 'getUsageStats');
    expect(statsCall.arguments, {'days': 1, 'includeIcons': false});
  });

  test('jamlar o\'zgarmagan bo\'lsa POST yo\'q, o\'zgarsa — bor', () async {
    final service = build();
    await service.syncIfDue();

    now = now.add(const Duration(minutes: 5));
    await service.syncIfDue();
    expect(repo.usageUploads, hasLength(1));

    usage = [app('com.a', 120000)];
    now = now.add(const Duration(minutes: 5));
    await service.syncIfDue();
    expect(repo.usageUploads, hasLength(2));
  });

  test(
    'o\'rnatilgan ilovalar: kuniga bir marta, yangi paket — darhol',
    () async {
      final service = build();
      await service.syncIfDue();
      expect(repo.installedUploads, hasLength(1));

      // Qayta ishga tushish (yangi nusxa) — prefs'dagi holat: bugun bo'lgan.
      usage = [app('com.a', 90000)];
      now = now.add(const Duration(minutes: 5));
      await build().syncIfDue();
      expect(repo.installedUploads, hasLength(1));

      // Yangi o'rnatilgan ilova ishlatildi.
      usage = [app('com.a', 90000), app('com.new', 1000)];
      installed = [
        {'packageName': 'com.a', 'appName': 'A'},
        {'packageName': 'com.new', 'appName': 'New'},
      ];
      now = now.add(const Duration(minutes: 5));
      await service.syncIfDue();
      expect(repo.installedUploads, hasLength(2));
    },
  );

  test(
    'o\'rnatilgan ilovalar xatosi — backoff (har tick\'da qayta emas)',
    () async {
      repo.installedOk = false;
      final service = build();
      await service.syncIfDue();
      expect(repo.installedUploads, hasLength(1));

      usage = [app('com.a', 70000)];
      now = now.add(const Duration(minutes: 1));
      await service.syncIfDue(); // muddati kelmagan
      usage = [app('com.a', 80000)];
      now = now.add(const Duration(minutes: 5));
      await service.syncIfDue(); // backoff 2 daq — o'tgan, qayta urinadi
      expect(repo.installedUploads, hasLength(2));

      usage = [app('com.a', 90000)];
      now = now.add(const Duration(minutes: 5));
      await service.syncIfDue(); // backoff 4 daq — o'tgan
      expect(repo.installedUploads, hasLength(3));
    },
  );

  test('plagin yo\'q (fon dvigateli) — jim, hech narsa yuborilmaydi', () async {
    messenger.setMockMethodCallHandler(_channel, null);

    await build().syncIfDue();

    expect(repo.usageUploads, isEmpty);
    expect(repo.installedUploads, isEmpty);
    expect(await UsageStatsService().tryHasPermission(), isNull);
    expect(await UsageStatsService().hasPermission(), isFalse);
  });
}
