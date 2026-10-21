// AppNotification — JSON roundtrip (SharedPreferences persist) va backend
// type mapping (push navigatsiya/ikonka shu turga bog'liq).

import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

  group('maktab va Growth push turlari', () {
    AppNotification fromPush(String type, [Map<String, dynamic>? extra]) =>
        AppNotification.fromRemoteMessage(
          RemoteMessage(
            messageId: 'm-$type',
            data: {'type': type, ...?extra},
            notification: const RemoteNotification(title: 'T', body: 'B'),
          ),
        );

    const backendTypes = {
      'school_attendance': NotificationType.schoolAttendance,
      'school_early_exit': NotificationType.schoolEarlyExit,
      'SCHOOL_ANNOUNCEMENT': NotificationType.schoolAnnouncement,
      'SCHOOL_REMINDER': NotificationType.schoolReminder,
      'SCHOOL_PAYMENT_REMINDER': NotificationType.schoolPayment,
      'SCHOOL_VERIFICATION_ANSWERED': NotificationType.schoolVerification,
      'SCHOOL_MODE_REMIND': NotificationType.schoolMode,
      'learning_weekly': NotificationType.learningReport,
    };

    test('backend yuboradigan registrda to`g`ri tur', () {
      for (final MapEntry(key: raw, value: expected) in backendTypes.entries) {
        expect(fromPush(raw).type, expected, reason: raw);
      }
    });

    test('katta/kichik harf va bo`shliqlar ahamiyatsiz', () {
      for (final MapEntry(key: raw, value: expected) in backendTypes.entries) {
        expect(fromPush(raw.toUpperCase()).type, expected, reason: raw);
        expect(fromPush(raw.toLowerCase()).type, expected, reason: raw);
        expect(fromPush(' $raw ').type, expected, reason: raw);
      }
      // Eski turlar ham registrdan qat'i nazar taniladi.
      expect(fromPush('PAIR_REQUEST').type, NotificationType.pairRequest);
    });

    test("noma'lum maktab turi — online (eng zararsiz)", () {
      expect(fromPush('SCHOOL_SOMETHING_NEW').type, NotificationType.online);
    });

    test('data getter`lari: bo`shliqsiz satr, bo`sh/boshqa tur → null', () {
      final n = fromPush('school_attendance', {
        'studentId': ' st-1 ',
        'date': '2026-10-20',
        'announcementId': '',
        'paymentReminderId': 'p-1',
        'verificationId': '   ',
      });
      expect(n.studentId, 'st-1');
      expect(n.attendanceDate, '2026-10-20');
      expect(n.announcementId, isNull);
      expect(n.paymentReminderId, 'p-1');
      expect(n.verificationId, isNull);

      final numeric = AppNotification(
        id: 'x',
        type: NotificationType.schoolMode,
        childId: '',
        childName: '',
        title: '',
        message: '',
        timestamp: DateTime(2026, 10, 20),
        data: const {'studentId': 42},
      );
      expect(numeric.studentId, isNull);
      expect(numeric.copyWith(isRead: true).studentId, isNull);
    });

    test('JSON roundtrip yangi turlarni va data`ni saqlaydi', () {
      for (final type in backendTypes.values) {
        final n = AppNotification(
          id: 'id-${type.name}',
          type: type,
          childId: 'kid-1',
          childName: 'Bola',
          title: "Yangi e'lon",
          message: 'Matn',
          timestamp: DateTime(2026, 10, 20, 8, 5),
          data: const {
            'studentId': 'st-1',
            'announcementId': 'a-1',
            'paymentReminderId': 'p-1',
            'verificationId': 'v-1',
            'date': '2026-10-20',
          },
        );
        final back = AppNotification.fromJson(n.toJson());
        expect(back, isNotNull, reason: type.name);
        expect(back!.type, type);
        expect(back.timestamp, n.timestamp);
        expect(back.studentId, 'st-1');
        expect(back.announcementId, 'a-1');
        expect(back.paymentReminderId, 'p-1');
        expect(back.verificationId, 'v-1');
        expect(back.attendanceDate, '2026-10-20');
      }
    });

    test('isSchool faqat 8 ta yangi turda', () {
      final school = NotificationType.values.where((t) => t.isSchool).toSet();
      expect(school, backendTypes.values.toSet());
    });

    test('har tur uchun yorliq, ikonka va rang bor', () {
      for (final type in NotificationType.values) {
        expect(type.label, isNotEmpty, reason: type.name);
        expect(type.icon.codePoint, greaterThan(0), reason: type.name);
        expect(type.color.a, greaterThan(0), reason: type.name);
      }
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
