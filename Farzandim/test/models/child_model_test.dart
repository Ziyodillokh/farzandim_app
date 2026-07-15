// Child modeli — fromJson parse, jonli status (isLiveOnline/isConnectionLost)
// va value-based equality (polling dedup shu ==ga tayanadi!).

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
}
