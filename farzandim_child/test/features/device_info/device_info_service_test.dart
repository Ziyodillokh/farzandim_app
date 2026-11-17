// DeviceInfoService: taymersiz heartbeat; plagin yo'q bo'lsa usagePermission
// YUBORILMAYDI (soxta "ruxsat o'chirildi" yo'q); ≥ 4.5 daqiqa yoki ruxsat
// o'zgarganda yuboriladi.

import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/device_info/data/services/device_info_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../background/fake_dio.dart';

const _usageChannel = MethodChannel('farzandim/usage_stats');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(_usageChannel, null));

  test(
    'plagin yo\'q (fon dvigateli) — usagePermission maydoni yo\'q',
    () async {
      final (dio, adapter) = recordingDio();
      final service = DeviceInfoService(
        dio: dio,
        usageStats: UsageStatsService(),
      );

      await service.start(parentUid: 'p1', childId: 'c1');
      await service
          .sendNow(); // start'dagi so'rovga qo'shiladi (bir vaqtda bitta)

      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(request.path, '/children/c1/device-info');
      expect(request.json.containsKey('usagePermission'), isFalse);
      expect(request.json.containsKey('accessibilityEnabled'), isFalse);
    },
  );

  test('plagin bor — haqiqiy qiymat yuboriladi', () async {
    messenger.setMockMethodCallHandler(_usageChannel, (call) async {
      if (call.method == 'hasPermission') return true;
      if (call.method == 'isAccessibilityEnabled') return false;
      return null;
    });
    final (dio, adapter) = recordingDio();
    final service = DeviceInfoService(
      dio: dio,
      usageStats: UsageStatsService(),
    );

    await service.start(parentUid: 'p1', childId: 'c1');
    await service
        .sendNow(); // start'dagi so'rovga qo'shiladi (bir vaqtda bitta)

    expect(adapter.requests.single.json['usagePermission'], isTrue);
    expect(adapter.requests.single.json['accessibilityEnabled'], isFalse);
  });

  test(
    'sendIfDue: 4.5 daqiqagacha jim, keyin yuboradi; ruxsat o\'zgarsa darhol',
    () async {
      var hasUsage = true;
      messenger.setMockMethodCallHandler(_usageChannel, (call) async {
        if (call.method == 'hasPermission') return hasUsage;
        return null;
      });
      var now = DateTime.utc(2026, 11, 13, 5);
      final (dio, adapter) = recordingDio();
      final service = DeviceInfoService(
        dio: dio,
        usageStats: UsageStatsService(),
        clock: () => now,
      );
      await service.start(parentUid: 'p1', childId: 'c1');
      await service
          .sendNow(); // start'dagi so'rovga qo'shiladi (bir vaqtda bitta)
      expect(adapter.requests, hasLength(1));

      now = now.add(const Duration(minutes: 3));
      await service.sendIfDue();
      expect(adapter.requests, hasLength(1));

      hasUsage = false;
      await service.sendIfDue();
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.last.json['usagePermission'], isFalse);

      now = now.add(const Duration(minutes: 4, seconds: 30));
      await service.sendIfDue();
      expect(adapter.requests, hasLength(3));
    },
  );

  test(
    'server xatosi — muvaffaqiyat hisoblanmaydi, keyingi tick qayta yuboradi',
    () async {
      var status = 503;
      var now = DateTime.utc(2026, 11, 13, 5);
      final (dio, adapter) = recordingDio((_) => (status, null));
      final service = DeviceInfoService(
        dio: dio,
        usageStats: UsageStatsService(),
        clock: () => now,
      );
      await service.start(parentUid: 'p1', childId: 'c1');
      await service
          .sendNow(); // start'dagi so'rovga qo'shiladi (bir vaqtda bitta)

      status = 200;
      now = now.add(const Duration(minutes: 1));
      await service.sendIfDue();

      expect(adapter.requests, hasLength(2));
    },
  );

  test('markOffline (unpair) dan keyin yuborilmaydi', () async {
    final (dio, adapter) = recordingDio();
    final service = DeviceInfoService(
      dio: dio,
      usageStats: UsageStatsService(),
    );
    await service.start(parentUid: 'p1', childId: 'c1');
    await service
        .sendNow(); // start'dagi so'rovga qo'shiladi (bir vaqtda bitta)

    await service.markOffline();
    await service.sendNow();

    expect(adapter.requests, hasLength(1));
  });
}
