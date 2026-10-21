// Maktab, Growth va Kelajak marshrutlari: yo'l quruvchilar, ro'yxatdan
// o'tganligi
// va `/school/attendance/:studentId?month=` to'g'ri ajralishi. Push
// parametrlari (`remind`, `focus`, `verification`) ham. E'lon push matni
// faqat `extra`dan — URL'dagi `title`/`body` (tashqi havola) e'tiborsiz.
// Har ochilish yangi sahifa (`state.pageKey`) — ochiq ekranga kelgan push
// yangi parametrlari bilan ochiladi.

import 'package:farzandim/core/routing/app_router.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/school/presentation/school_push.dart';
import 'package:farzandim/features/school/presentation/screens/school_announcements_screen.dart';
import 'package:farzandim/features/school/presentation/screens/school_attendance_screen.dart';
import 'package:farzandim/features/school/presentation/screens/school_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// [location] uchun sahifa (pageBuilder) — [pageKey] va [extra] bilan.
Page<Object?> _pageFor(
  BuildContext context,
  GoRouter router,
  String location, {
  required String pageKey,
  Object? extra,
}) {
  final match = router.configuration.findMatch(Uri.parse(location));
  final route = match.last.route;
  final state = GoRouterState(
    router.configuration,
    uri: match.uri,
    matchedLocation: match.last.matchedLocation,
    fullPath: match.fullPath,
    pathParameters: match.pathParameters,
    extra: extra,
    pageKey: ValueKey<String>(pageKey),
  );
  return route.pageBuilder!(context, state);
}

T _screenOf<T extends Widget>(Page<Object?> page) =>
    (page as CustomTransitionPage<Object?>).child as T;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('yo`l quruvchilar', () {
    expect(AppRoutes.schoolAttendancePath('st-1'), '/school/attendance/st-1');
    expect(
      AppRoutes.schoolAttendancePath('st-1', month: '2026-10'),
      '/school/attendance/st-1?month=2026-10',
    );
    expect(AppRoutes.growthPath('kid-1'), '/growth/kid-1');
    expect(AppRoutes.kelajakPath('kid-1'), '/kelajak/kid-1');
    expect(AppRoutes.schoolRemindPath('st-1'), '/school?remind=st-1');
    expect(
      AppRoutes.schoolPaymentsPath(verification: 'v-1'),
      '/school/payments?verification=v-1',
    );
  });

  test('bo`sh push parametrlari tashlanadi', () {
    expect(AppRoutes.schoolAnnouncementsPath(), AppRoutes.schoolAnnouncements);
    expect(
      AppRoutes.schoolAnnouncementsPath(focus: ' '),
      AppRoutes.schoolAnnouncements,
    );
    expect(AppRoutes.schoolPaymentsPath(), AppRoutes.schoolPayments);
    expect(AppRoutes.schoolRemindPath(''), AppRoutes.school);
  });

  test('e`lon yo`lida faqat id — push matni URL`da yo`q', () {
    expect(
      AppRoutes.schoolAnnouncementsPath(focus: 'a-1'),
      '/school/announcements?focus=a-1',
    );

    final router = GoRouter(routes: buildAppRoutes());
    addTearDown(router.dispose);
    final remind = router.configuration.findMatch(
      Uri.parse(AppRoutes.schoolRemindPath('st-1')),
    );
    expect(remind.last.route.path, AppRoutes.school);
    expect(remind.uri.queryParameters['remind'], 'st-1');
  });

  testWidgets('e`lon matni faqat ilova ichidan (extra), havoladan emas', (
    tester,
  ) async {
    final router = GoRouter(routes: buildAppRoutes());
    addTearDown(router.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );

    // Tashqi havola: `?title=&body=` — soxta "e'lon" ko'rsatilmaydi.
    final fromLink = _screenOf<SchoolAnnouncementsScreen>(
      _pageFor(
        context,
        router,
        '/school/announcements?focus=a-1'
        "&title=Maktab%20to'lovi&body=8600%20kartaga%20o'tkazing",
        pageKey: 'p-1',
      ),
    );
    expect(fromLink.focusId, 'a-1');
    expect(fromLink.focusTitle, isNull);
    expect(fromLink.focusBody, isNull);

    // Push bosildi — matn `extra`da.
    final fromPush = _screenOf<SchoolAnnouncementsScreen>(
      _pageFor(
        context,
        router,
        AppRoutes.schoolAnnouncementsPath(focus: 'a-1'),
        pageKey: 'p-2',
        extra: const SchoolAnnouncementPreview(
          title: "12-maktab: muhim e'lon",
          body: 'Ertaga yig`ilish',
        ),
      ),
    );
    expect(fromPush.focusTitle, "12-maktab: muhim e'lon");
    expect(fromPush.focusBody, 'Ertaga yig`ilish');
  });

  testWidgets('har ochilish yangi sahifa — ochiq ekran qayta ishlatilmaydi', (
    tester,
  ) async {
    final router = GoRouter(routes: buildAppRoutes());
    addTearDown(router.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );

    for (final location in [
      AppRoutes.schoolRemindPath('st-1'),
      AppRoutes.schoolAnnouncementsPath(focus: 'a-1'),
      AppRoutes.schoolPaymentsPath(verification: 'v-1'),
      AppRoutes.schoolEarlyExits,
      AppRoutes.schoolLink,
      AppRoutes.schoolAttendancePath('st-1', month: '2026-10'),
      AppRoutes.growthPath('kid-1'),
      AppRoutes.kelajakPath('kid-1'),
    ]) {
      final first = _pageFor(context, router, location, pageKey: 'p-1');
      final second = _pageFor(context, router, location, pageKey: 'p-2');
      expect(first.key, const ValueKey<String>('p-1'), reason: location);
      expect(second.key, isNot(first.key), reason: location);
    }

    final home = _screenOf<SchoolHomeScreen>(
      _pageFor(
        context,
        router,
        AppRoutes.schoolRemindPath('st-2'),
        pageKey: 'p-3',
      ),
    );
    expect(home.remindStudentId, 'st-2');
    final attendance = _screenOf<SchoolAttendanceScreen>(
      _pageFor(
        context,
        router,
        AppRoutes.schoolAttendancePath('st-1', month: '2026-09'),
        pageKey: 'p-4',
      ),
    );
    expect(attendance.month, '2026-09');
  });

  test('barcha maktab, Growth va Kelajak marshrutlari ro`yxatdan o`tgan', () {
    final paths = buildAppRoutes()
        .whereType<GoRoute>()
        .map((route) => route.path)
        .toSet();
    expect(
      paths,
      containsAll(<String>[
        AppRoutes.school,
        AppRoutes.schoolLink,
        AppRoutes.schoolAnnouncements,
        AppRoutes.schoolPayments,
        AppRoutes.schoolEarlyExits,
        AppRoutes.schoolAttendancePattern,
        AppRoutes.growthPattern,
        AppRoutes.kelajakPattern,
      ]),
    );
  });

  test('yo`llar o`z ekraniga tushadi (parametrlar bilan)', () {
    final router = GoRouter(routes: buildAppRoutes());
    addTearDown(router.dispose);

    final attendance = router.configuration.findMatch(
      Uri.parse(AppRoutes.schoolAttendancePath('st-1', month: '2026-10')),
    );
    expect(attendance.isError, isFalse);
    expect(attendance.last.route.path, AppRoutes.schoolAttendancePattern);
    expect(attendance.pathParameters['studentId'], 'st-1');
    expect(attendance.uri.queryParameters['month'], '2026-10');

    final link = router.configuration.findMatch(
      Uri.parse(AppRoutes.schoolLink),
    );
    expect(link.last.route.path, AppRoutes.schoolLink);

    final growth = router.configuration.findMatch(
      Uri.parse(AppRoutes.growthPath('kid-1')),
    );
    expect(growth.last.route.path, AppRoutes.growthPattern);
    expect(growth.pathParameters['childId'], 'kid-1');

    final kelajak = router.configuration.findMatch(
      Uri.parse(AppRoutes.kelajakPath('kid-1')),
    );
    expect(kelajak.isError, isFalse);
    expect(kelajak.last.route.path, AppRoutes.kelajakPattern);
    expect(kelajak.pathParameters['childId'], 'kid-1');
  });
}
