// Child modeli — fromJson parse, jonli status (isLiveOnline/isConnectionLost),
// iOS (iPhone) aniqlash + screenTimePermission va value-based equality
// (polling dedup shu ==ga tayanadi!).

import 'package:farzandim/features/child_management/data/models/child_device_info.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Child.fromJson', () {
    test('minimal JSON parse bo`ladi (defaults)', () {
      final c = Child.fromJson(const {
        'id': 'c1',
        'name': 'Testbola',
      });
      expect(c.id, 'c1');
      expect(c.name, 'Testbola');
      expect(c.isConnected, false);
      expect(c.blockAllApps, false);
      expect(c.lastSeenAt, isNull);
    });

    test('UTC lastSeenAt parse bo`ladi', () {
      final c = Child.fromJson(const {
        'id': 'c1',
        'name': 'T',
        'lastSeenAt': '2026-06-12T10:00:00.000Z',
        'isConnected': true,
      });
      expect(c.lastSeenAt, isNotNull);
      expect(c.isConnected, true);
    });
  });

  group('jonli status (heartbeat-aware)', () {
    Child child({required bool connected, DateTime? seen}) =>
        Child.fromJson(const {'id': 'c1', 'name': 'T'}).copyWith(
          isConnected: connected,
          lastSeenAt: seen,
        );

    test('heartbeat 2 daqiqa ICHIDA + ulangan → ONLINE', () {
      // Ostona backend ConnectionMonitor (120s) bilan moslashtirildi (3→2 daq).
      final c = child(
        connected: true,
        seen: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(c.isLiveOnline, isTrue);
      expect(c.isConnectionLost, isFalse);
    });

    test('heartbeat 2 daqiqadan ESKI + ulangan → ALOQA UZILDI', () {
      final c = child(
        connected: true,
        seen: DateTime.now().subtract(const Duration(minutes: 3)),
      );
      expect(c.isLiveOnline, isFalse);
      expect(c.isConnectionLost, isTrue);
    });

    test('ulanmagan → hech qachon online emas', () {
      final c = child(connected: false, seen: DateTime.now());
      expect(c.isLiveOnline, isFalse);
      expect(c.isConnectionLost, isFalse); // "ulanmagan", "uzildi" emas
    });

    test('heartbeat YO`Q + ulangan → aloqa uzildi', () {
      final c = child(connected: true);
      expect(c.isLiveOnline, isFalse);
      expect(c.isConnectionLost, isTrue);
    });
  });

  group('equality (polling dedup asosi)', () {
    test('bir xil JSON → teng obyektlar', () {
      const json = {
        'id': 'c1',
        'name': 'T',
        'isConnected': true,
        'lastSeenAt': '2026-06-12T10:00:00.000Z',
        'createdAt': '2026-06-01T00:00:00.000Z',
      };
      expect(Child.fromJson(json), equals(Child.fromJson(json)));
    });

    test('lastSeenAt farqi → teng EMAS (status yangilanishi yutilmasin)', () {
      const base = {
        'id': 'c1',
        'name': 'T',
        'createdAt': '2026-06-01T00:00:00.000Z',
      };
      final a = Child.fromJson(
        const {...base, 'lastSeenAt': '2026-06-12T10:00:00.000Z'},
      );
      final b = Child.fromJson(
        const {...base, 'lastSeenAt': '2026-06-12T10:01:00.000Z'},
      );
      expect(a, isNot(equals(b)));
    });

    test('isConnected farqi → teng EMAS', () {
      const base = {
        'id': 'c1',
        'name': 'T',
        'createdAt': '2026-06-01T00:00:00.000Z',
      };
      final a = Child.fromJson(const {...base, 'isConnected': true});
      final b = Child.fromJson(const {...base, 'isConnected': false});
      expect(a, isNot(equals(b)));
    });
  });
  group('isIosDevice (platforma aniqlash)', () {
    Child child({String? os, String? model}) => Child.fromJson({
      'id': 'c1',
      'name': 'T',
      'androidVersion': ?os,
      'deviceModel': ?model,
    });

    test('"iOS 18.2" → iPhone', () {
      expect(child(os: 'iOS 18.2').isIosDevice, isTrue);
    });

    test('"iPadOS 17" → iPhone/iPad', () {
      expect(child(os: 'iPadOS 17').isIosDevice, isTrue);
    });

    test('registr va bo`shliqqa befarq: "  ios 17 "', () {
      expect(child(os: '  ios 17 ').isIosDevice, isTrue);
      expect(child(os: 'IOS 17').isIosDevice, isTrue);
    });

    test('"Android 14" → iPhone EMAS', () {
      expect(child(os: 'Android 14').isIosDevice, isFalse);
    });

    test('OS "Android" bo`lsa model nomi iPhone ko`rinsa ham → Android', () {
      // OS versiyasi modeldan ustun.
      expect(child(os: 'Android 14', model: 'iPhone 15').isIosDevice, isFalse);
    });

    test('OS yo`q → model "iPhone 15" bo`yicha iPhone', () {
      expect(child(model: 'iPhone 15').isIosDevice, isTrue);
    });

    test('OS yo`q → model "iPad Air" bo`yicha iPhone/iPad', () {
      expect(child(model: 'iPad Air').isIosDevice, isTrue);
    });

    test('OS bo`sh qator → model bo`yicha', () {
      expect(child(os: '   ', model: 'iphone 13').isIosDevice, isTrue);
    });

    test('OS va model yo`q → Android deb hisoblanadi', () {
      expect(child().isIosDevice, isFalse);
    });

    test('oddiy Android model ("Redmi Note 12") → false', () {
      expect(child(model: 'Redmi Note 12').isIosDevice, isFalse);
    });

    test('deviceInfo.deviceModel fallback (top-level model yo`q)', () {
      final c = Child.fromJson(const {
        'id': 'c1',
        'name': 'T',
      }).copyWith(deviceInfo: const ChildDeviceInfo(deviceModel: 'iPhone 14'));
      expect(c.deviceModel, isNull);
      expect(c.isIosDevice, isTrue);
    });

    test('deviceInfo yo`q → false', () {
      expect(
        Child.fromJson(const {'id': 'c1', 'name': 'T'}).isIosDevice,
        isFalse,
      );
    });
  });

  group('detectIosDevice (sof funksiya)', () {
    test('ikkala argument null → false', () {
      expect(detectIosDevice(), isFalse);
    });

    test('"android" bilan boshlansa model qaralmaydi', () {
      expect(
        detectIosDevice(osVersion: 'android 9', deviceModel: 'iPad'),
        isFalse,
      );
    });

    test('"iPhone" ichida emas, boshida bo`lishi shart', () {
      expect(detectIosDevice(deviceModel: 'Not an iPhone'), isFalse);
    });
  });

  group('screenTimePermission', () {
    test('true → Child.screenTimePermission true (deviceInfo ichida)', () {
      final c = Child.fromJson(const {
        'id': 'c1',
        'name': 'T',
        'screenTimePermission': true,
      });
      expect(c.screenTimePermission, isTrue);
      expect(c.deviceInfo?.screenTimePermission, isTrue);
    });

    test('false → false (o`chirilgan)', () {
      final c = Child.fromJson(const {
        'id': 'c1',
        'name': 'T',
        'screenTimePermission': false,
      });
      expect(c.screenTimePermission, isFalse);
    });

    test('maydon yo`q (eski backend) → null, deviceInfo ham null', () {
      final c = Child.fromJson(const {'id': 'c1', 'name': 'T'});
      expect(c.screenTimePermission, isNull);
      expect(c.deviceInfo, isNull);
    });

    test('Android: boshqa ruxsatlar bor, screenTimePermission null', () {
      final c = Child.fromJson(const {
        'id': 'c1',
        'name': 'T',
        'androidVersion': 'Android 14',
        'usagePermission': true,
      });
      expect(c.screenTimePermission, isNull);
      expect(c.deviceInfo?.usagePermission, isTrue);
    });

    test('iOS bola: backgroundAllowed/accessibility/usage null', () {
      final c = Child.fromJson(const {
        'id': 'c1',
        'name': 'T',
        'androidVersion': 'iOS 18.2',
        'deviceModel': 'iPhone 15',
        'backgroundAllowed': null,
        'accessibilityEnabled': null,
        'usagePermission': null,
        'screenTimePermission': true,
      });
      expect(c.isIosDevice, isTrue);
      expect(c.deviceInfo?.backgroundAllowed, isNull);
      expect(c.deviceInfo?.accessibilityEnabled, isNull);
      expect(c.deviceInfo?.usagePermission, isNull);
      expect(c.screenTimePermission, isTrue);
    });

    test('faqat screenTimePermission kelsa ham deviceInfo yaratiladi', () {
      final c = Child.fromJson(const {
        'id': 'c1',
        'name': 'T',
        'screenTimePermission': false,
      });
      expect(c.deviceInfo, isNotNull);
    });

    test('screenTimePermission farqi → teng EMAS (UI yangilansin)', () {
      const base = {
        'id': 'c1',
        'name': 'T',
        'createdAt': '2026-06-01T00:00:00.000Z',
      };
      final a = Child.fromJson(const {...base, 'screenTimePermission': true});
      final b = Child.fromJson(const {...base, 'screenTimePermission': false});
      expect(a, isNot(equals(b)));
    });

    test('bir xil screenTimePermission → teng, hashCode bir xil', () {
      const json = {
        'id': 'c1',
        'name': 'T',
        'createdAt': '2026-06-01T00:00:00.000Z',
        'screenTimePermission': true,
      };
      final a = Child.fromJson(json);
      final b = Child.fromJson(json);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
