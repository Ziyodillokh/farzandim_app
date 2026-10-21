// Maktab va Growth push'lari qaysi ekranni ochadi (`schoolRouteFor`):
// backend yuboradigan 8 xil `data.type` (katta/kichik harf aralash)
// `AppNotification.fromRemoteMessage` orqali o'tib, to'g'ri yo'lga va
// bildirishnoma sahifasidagi tugma yorlig'iga aylanadi. Har yo'l
// marshrutlar ro'yxatida bor (push bosilganda "sahifa topilmadi" yo'q).

import 'package:farzandim/core/routing/app_router.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/notifications/data/services/fcm_service.dart';
import 'package:farzandim/features/school/presentation/school_push.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

AppNotification _push(
  String type, {
  Map<String, dynamic> data = const {},
  String title = 'Sarlavha',
  String body = 'Matn',
}) => AppNotification.fromRemoteMessage(
  RemoteMessage(
    messageId: 'm-$type',
    data: {'type': type, ...data},
    notification: RemoteNotification(title: title, body: body),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('davomat (school_attendance)', () {
    test('o`quvchi va `date` oyi bilan', () {
      final n = _push(
        'school_attendance',
        data: {'kind': 'ARRIVED', 'studentId': 'st-1', 'date': '2026-10-20'},
      );
      expect(n.type, NotificationType.schoolAttendance);
      expect(schoolRouteFor(n), '/school/attendance/st-1?month=2026-10');
      expect(
        schoolPushTarget(n)?.labelKey,
        'notifications.actions.openAttendance',
      );
    });

    test('sana yo`q yoki buzuq — joriy oy (parametrsiz)', () {
      for (final date in [null, '', '20.10.2026', '2026-10']) {
        final n = _push(
          'school_attendance',
          data: {'studentId': 'st-1', 'date': ?date},
        );
        expect(schoolRouteFor(n), '/school/attendance/st-1', reason: date);
      }
    });

    test('o`quvchi yo`q — maktab sahifasi', () {
      final n = _push('school_attendance', data: {'studentId': '  '});
      expect(schoolRouteFor(n), AppRoutes.school);
      expect(schoolPushTarget(n)?.labelKey, 'notifications.actions.openSchool');
    });
  });

  test('erta ketish (school_early_exit) — so`rovlar ro`yxati', () {
    final n = _push(
      'school_early_exit',
      data: {'status': 'APPROVED', 'requestId': 'r-1', 'studentId': 'st-1'},
    );
    expect(n.type, NotificationType.schoolEarlyExit);
    expect(schoolRouteFor(n), AppRoutes.schoolEarlyExits);
    expect(
      schoolPushTarget(n)?.labelKey,
      'notifications.actions.openEarlyExits',
    );
  });

  group("e'lon (SCHOOL_ANNOUNCEMENT)", () {
    test('e`lon id, sarlavha va matn bilan', () {
      final n = _push(
        'SCHOOL_ANNOUNCEMENT',
        data: {'announcementId': 'a-1'},
        title: "12-maktab: muhim e'lon",
        body: 'Ertaga yig`ilish',
      );
      expect(n.type, NotificationType.schoolAnnouncement);
      // Matn URL'da emas — `extra`da (tashqi havola soxtalashtira olmaydi).
      expect(schoolRouteFor(n), '/school/announcements?focus=a-1');
      expect(
        schoolPushTarget(n)?.extra,
        const SchoolAnnouncementPreview(
          title: "12-maktab: muhim e'lon",
          body: 'Ertaga yig`ilish',
        ),
      );
      expect(
        schoolPushTarget(n)?.labelKey,
        'notifications.actions.openAnnouncements',
      );
    });

    test('id yo`q — oddiy ro`yxat (matn yuborilmaydi)', () {
      final n = _push('SCHOOL_ANNOUNCEMENT');
      expect(schoolRouteFor(n), AppRoutes.schoolAnnouncements);
      expect(schoolPushTarget(n)?.extra, isNull);
    });
  });

  test('eslatma (SCHOOL_REMINDER) — API yo`q, bildirishnomaning o`zi', () {
    final n = _push('SCHOOL_REMINDER', data: {'reminderId': 'rm-1'});
    expect(n.type, NotificationType.schoolReminder);
    expect(schoolRouteFor(n), isNull);
    expect(schoolPushTarget(n), isNull);
  });

  test("to'lov eslatmasi (SCHOOL_PAYMENT_REMINDER) — to'lovlar", () {
    final n = _push(
      'SCHOOL_PAYMENT_REMINDER',
      data: {'paymentReminderId': 'p-1'},
    );
    expect(n.type, NotificationType.schoolPayment);
    expect(schoolRouteFor(n), AppRoutes.schoolPayments);
    expect(schoolPushTarget(n)?.labelKey, 'notifications.actions.openPayments');
  });

  test('so`rovga javob (SCHOOL_VERIFICATION_ANSWERED) — shu so`rov', () {
    final n = _push(
      'SCHOOL_VERIFICATION_ANSWERED',
      data: {'verificationId': 'v-1', 'paymentReminderId': 'p-1'},
    );
    expect(n.type, NotificationType.schoolVerification);
    expect(schoolRouteFor(n), '/school/payments?verification=v-1');
    expect(schoolPushTarget(n)?.labelKey, 'notifications.actions.openPayments');
  });

  group('School Mode (SCHOOL_MODE_REMIND)', () {
    test('o`quvchi bilan — maktab sahifasi kerakli varaq bilan', () {
      final n = _push('SCHOOL_MODE_REMIND', data: {'studentId': 'st-1'});
      expect(n.type, NotificationType.schoolMode);
      expect(schoolRouteFor(n), '/school?remind=st-1');
      expect(schoolPushTarget(n)?.labelKey, 'notifications.actions.openSchool');
    });

    test('o`quvchi yo`q — maktab sahifasi', () {
      expect(schoolRouteFor(_push('SCHOOL_MODE_REMIND')), AppRoutes.school);
    });
  });

  group('Growth haftalik hisoboti (learning_weekly)', () {
    test('bola bilan — Growth sahifasi', () {
      final n = _push(
        'learning_weekly',
        data: {'childId': 'kid-1', 'weekStart': '2026-10-12'},
      );
      expect(n.type, NotificationType.learningReport);
      expect(schoolRouteFor(n), '/growth/kid-1');
      expect(schoolPushTarget(n)?.labelKey, 'notifications.actions.openGrowth');
    });

    test('bola yo`q — bildirishnomaning o`zi', () {
      expect(schoolRouteFor(_push('learning_weekly')), isNull);
      expect(
        schoolRouteFor(_push('learning_weekly', data: {'childId': ' '})),
        isNull,
      );
    });
  });

  test('turning registri ahamiyatsiz', () {
    expect(
      schoolRouteFor(_push('school_payment_reminder')),
      AppRoutes.schoolPayments,
    );
    expect(
      schoolRouteFor(_push('SCHOOL_EARLY_EXIT')),
      AppRoutes.schoolEarlyExits,
    );
    expect(
      schoolRouteFor(_push('Learning_Weekly', data: {'childId': 'kid-1'})),
      '/growth/kid-1',
    );
  });

  test('maktabga aloqasi yo`q push turlari — `null`', () {
    for (final type in NotificationType.values.where((t) => !t.isSchool)) {
      final n = AppNotification(
        id: 'n-${type.name}',
        type: type,
        childId: 'kid-1',
        childName: 'Bola',
        title: 'T',
        message: 'M',
        timestamp: DateTime(2026, 10, 20),
        data: const {'studentId': 'st-1', 'announcementId': 'a-1'},
      );
      expect(schoolRouteFor(n), isNull, reason: type.name);
    }
    expect(schoolRouteFor(_push('sos')), isNull);
  });

  testWidgets('e`lon push`i bosilsa matn ekranga `extra` bilan boradi', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.dashboard,
      routes: [
        GoRoute(
          path: AppRoutes.dashboard,
          builder: (_, _) => const Text('dashboard'),
        ),
        GoRoute(
          path: AppRoutes.schoolAnnouncements,
          builder: (_, state) {
            final preview = state.extra as SchoolAnnouncementPreview?;
            return Text(
              'focus:${state.uri.queryParameters['focus']} '
              'title:${preview?.title}',
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    handleFcmTap(
      _push(
        'SCHOOL_ANNOUNCEMENT',
        data: {'announcementId': 'a-1'},
        title: 'Yig`ilish',
      ),
      router,
    );
    await tester.pumpAndSettle();

    expect(find.text('focus:a-1 title:Yig`ilish'), findsOneWidget);
  });

  test('har push yo`li marshrutlar ro`yxatida bor', () {
    final router = GoRouter(routes: buildAppRoutes());
    addTearDown(router.dispose);
    final pushes = [
      _push(
        'school_attendance',
        data: {'studentId': 'st-1', 'date': '2026-10-20'},
      ),
      _push('school_attendance'),
      _push('school_early_exit'),
      _push('SCHOOL_ANNOUNCEMENT', data: {'announcementId': 'a-1'}),
      _push('SCHOOL_PAYMENT_REMINDER'),
      _push('SCHOOL_VERIFICATION_ANSWERED', data: {'verificationId': 'v-1'}),
      _push('SCHOOL_MODE_REMIND', data: {'studentId': 'st-1'}),
      _push('learning_weekly', data: {'childId': 'kid-1'}),
    ];
    for (final n in pushes) {
      final route = schoolRouteFor(n);
      expect(route, isNotNull, reason: n.type.name);
      final match = router.configuration.findMatch(Uri.parse(route!));
      expect(match.isError, isFalse, reason: route);
      expect(match.matches, isNotEmpty, reason: route);
    }
  });
}
