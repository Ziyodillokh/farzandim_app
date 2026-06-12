// AppNotification — JSON roundtrip (SharedPreferences persist) va backend
// type mapping (push navigatsiya/ikonka shu turga bog'liq).

import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toJson/fromJson roundtrip', () {
    test("to'liq xabar saqlanib tiklanadi", () {
      final n = AppNotification(
        id: 'm1',
        type: NotificationType.game,
        childId: 'c1',
        childName: 'Bola',
        title: 'CS2',
        message: "O'yin o'ynayapti",
        timestamp: DateTime(2026, 6, 12, 10, 30),
        data: const {'packageName': 'com.cs2', 'appName': 'CS2'},
      );
      final back = AppNotification.fromJson(n.toJson());
      expect(back, isNotNull);
      expect(back!.id, 'm1');
      expect(back.type, NotificationType.game);
      expect(back.packageName, 'com.cs2');
      expect(back.appName, 'CS2');
      expect(back.isGame, isTrue);
    });

    test('buzuq timestamp → null (crash YO`Q)', () {
      expect(
        AppNotification.fromJson(const {'id': 'x', 'timestamp': 'buzuq'}),
        isNull,
      );
    });

    test("noma'lum type → online fallback", () {
      final n = AppNotification.fromJson(const {
        'id': 'x',
        'type': 'mavjud_emas_tur',
        'timestamp': '2026-06-12T10:00:00.000Z',
      });
      expect(n!.type, NotificationType.online);
    });
  });

  group('markAsRead/copyWith', () {
    test('isRead o`zgaradi, qolgani saqlanadi', () {
      final n = AppNotification(
        id: 'm1',
        type: NotificationType.sos,
        childId: 'c1',
        childName: 'B',
        title: 'SOS',
        message: '!',
        timestamp: DateTime(2026, 6, 12),
      );
      final read = n.copyWith(isRead: true);
      expect(read.isRead, isTrue);
      expect(read.id, n.id);
      expect(read.type, n.type);
    });
  });
}
