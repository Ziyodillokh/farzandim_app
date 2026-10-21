// Davomat QR sahifasi (kamerasiz soxta skaner): kirish / chiqish / takroriy
// natijalar, eskirgan kodda skanerlash davom etishi, tushunarli xatolar,
// serverga yuborilmaydigan QR'lar va bitta so'rov qoidasi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/screens/school_check_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_school_repository.dart';
import 'school_test_app.dart';

const _token = 'eyJzIjoic2Nob29sLTEiLCJ0IjoxfQ.c2lnbmF0dXJl';
const _nextToken = 'eyJzIjoic2Nob29sLTEiLCJ0IjoyfQ.c2lnbmF0dXJl';

Map<String, Object?> _record(String status, {String? inAt, String? outAt}) => {
  'status': status,
  'inAt': inAt,
  'outAt': outAt,
  'source': 'QR',
};

/// Bugungi holatni kuzatuvchi sahifadan (bosh sahifa / "Maktabim"dek) QR
/// sahifasini ochadi; soxta skanerni qaytaradi.
Future<FakeScanner> _openCheckIn(
  WidgetTester tester,
  FakeSchoolRepository repo, {
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  final scanner = FakeScanner();
  await pumpSchoolApp(
    tester,
    repository: repo,
    initialLocation: '/start',
    size: size,
    textScale: textScale,
    routes: [
      GoRoute(
        path: '/start',
        builder: (_, _) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              final today = ref.watch(schoolTodayProvider).valueOrNull;
              return Column(
                children: [
                  Text('start-in:${today?.record?.inAt}'),
                  TextButton(
                    onPressed: () => context.push(SchoolRoutes.checkIn),
                    child: const Text('open-check-in'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      GoRoute(
        path: SchoolRoutes.checkIn,
        builder: (_, _) => SchoolCheckInScreen(scannerBuilder: scanner.build),
      ),
    ],
  );
  await tester.tap(find.text('open-check-in'));
  await tester.pumpAndSettle();
  expect(find.text(FakeScanner.label), findsOneWidget);
  return scanner;
}

/// QR'ni ko'rsatish va javobni kutish.
Future<void> _scan(WidgetTester tester, FakeScanner scanner, String raw) async {
  scanner.scan(raw);
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(setUpSchoolWidgetTests);

  testWidgets('kirish: vaqt, kechikish belgisi va kamera to\'xtaydi', (
    tester,
  ) async {
    final repo = FakeSchoolRepository(
      today: todayWith({'record': _record('LATE', inAt: '08:12')}),
    );
    final scanner = await _openCheckIn(tester, repo);
    expect(find.text('school.checkIn.hint'.tr()), findsOneWidget);

    await _scan(tester, scanner, kioskLink(_token));

    expect(tester.takeException(), isNull);
    expect(find.text('school.checkIn.arrivedTitle'.tr()), findsOneWidget);
    expect(find.text('08:12'), findsOneWidget);
    expect(find.text('school.checkIn.lateBadge'.tr()), findsOneWidget);
    expect(find.text('school.checkIn.lateHint'.tr()), findsOneWidget);
    expect(find.text('school.checkIn.parentsNotified'.tr()), findsOneWidget);
    // Natija chiqqach skaner (kamera) daraxtda yo'q.
    expect(find.text(FakeScanner.label), findsNothing);
    expect(repo.checkInTokens, [_token]);
  });

  testWidgets('o\'z vaqtida kirish — kechikish belgisi yo\'q', (tester) async {
    final repo = FakeSchoolRepository(
      today: todayWith({'record': _record('PRESENT', inAt: '07:56')}),
    );
    final scanner = await _openCheckIn(tester, repo);

    await _scan(tester, scanner, kioskLink(_token));

    expect(find.text('07:56'), findsOneWidget);
    expect(find.text('school.checkIn.lateBadge'.tr()), findsNothing);
  });

  testWidgets('chiqish: ketgan vaqt va xayrlashuv', (tester) async {
    final repo = FakeSchoolRepository(
      today: todayWith({
        'record': _record('PRESENT', inAt: '07:56', outAt: '13:31'),
      }),
      checkInAction: CheckInAction.departed,
    );
    final scanner = await _openCheckIn(tester, repo);

    await _scan(tester, scanner, kioskLink(_token));

    expect(find.text('school.checkIn.departedTitle'.tr()), findsOneWidget);
    expect(find.text('13:31'), findsOneWidget);
    expect(find.text('school.checkIn.departedBody'.tr()), findsOneWidget);
  });

  testWidgets('takroriy skanerlash — allaqachon belgilangan', (tester) async {
    final repo = FakeSchoolRepository(
      today: todayWith({'record': _record('LATE', inAt: '08:12')}),
      checkInAction: CheckInAction.none,
    );
    final scanner = await _openCheckIn(tester, repo);

    await _scan(tester, scanner, kioskLink(_token));

    expect(find.text('school.checkIn.alreadyTitle'.tr()), findsOneWidget);
    expect(find.text('school.status.late'.tr()), findsOneWidget);
    expect(find.text('school.checkIn.exitLater'.tr()), findsOneWidget);
  });

  testWidgets('"Tayyor" — oldingi sahifa yangi holat bilan (qayta '
      'yuklashsiz)', (tester) async {
    final repo = FakeSchoolRepository(today: todayWith({'record': null}));
    final scanner = await _openCheckIn(tester, repo);
    repo.today = todayWith({'record': _record('PRESENT', inAt: '07:56')});

    await _scan(tester, scanner, kioskLink(_token));
    await tester.tap(find.text('school.checkIn.done'.tr()));
    await tester.pumpAndSettle();

    expect(find.text('open-check-in'), findsOneWidget);
    expect(find.text('start-in:07:56'), findsOneWidget);
    expect(repo.calls.where((c) => c == 'loadToday'), hasLength(1));
  });

  testWidgets('eskirgan QR — skanerlash davom etadi, eski kod qayta '
      'yuborilmaydi, yangi kod qabul qilinadi', (tester) async {
    final repo = FakeSchoolRepository(
      today: todayWith({'record': _record('PRESENT', inAt: '07:56')}),
    );
    final scanner = await _openCheckIn(tester, repo);
    repo.failNext = const SchoolException(SchoolErrorCode.kioskExpired);

    await _scan(tester, scanner, kioskLink(_token));

    expect(find.text(FakeScanner.label), findsOneWidget);
    expect(find.text('school.errors.kioskExpired'.tr()), findsOneWidget);

    await _scan(tester, scanner, kioskLink(_token));
    expect(repo.checkInTokens, [_token]);

    await _scan(tester, scanner, kioskLink(_nextToken));
    expect(find.text('school.checkIn.arrivedTitle'.tr()), findsOneWidget);
    expect(repo.checkInTokens, [_token, _nextToken]);
  });

  testWidgets('yaroqsiz QR — xabar, "Qayta skanerlash", kod qayta '
      'yuborilmaydi', (tester) async {
    final repo = FakeSchoolRepository(today: todayWith({}));
    final scanner = await _openCheckIn(tester, repo);
    repo.failNext = const SchoolException(SchoolErrorCode.kioskInvalid);

    await _scan(tester, scanner, kioskLink(_token));

    expect(find.text('school.checkIn.failedTitle'.tr()), findsOneWidget);
    expect(find.text('school.errors.kioskInvalid'.tr()), findsOneWidget);
    expect(find.text(FakeScanner.label), findsNothing);

    await tester.tap(find.text('school.checkIn.scanAgain'.tr()));
    await tester.pumpAndSettle();
    expect(find.text(FakeScanner.label), findsOneWidget);

    await _scan(tester, scanner, kioskLink(_token));
    expect(find.text('school.errors.kioskInvalid'.tr()), findsOneWidget);
    expect(repo.checkInTokens, [_token]);
  });

  for (final code in [
    SchoolErrorCode.notEnrolled,
    SchoolErrorCode.outsideHours,
    SchoolErrorCode.network,
    SchoolErrorCode.unknown,
  ]) {
    testWidgets('${code.name} — tushunarli xabar', (tester) async {
      final repo = FakeSchoolRepository(today: todayWith({}));
      final scanner = await _openCheckIn(tester, repo);
      repo.failNext = SchoolException(code);

      await _scan(tester, scanner, kioskLink(_token));

      expect(tester.takeException(), isNull);
      expect(find.text('school.checkIn.failedTitle'.tr()), findsOneWidget);
      expect(find.text(code.messageKey.tr()), findsOneWidget);
      expect(find.text('school.checkIn.scanAgain'.tr()), findsOneWidget);
    });
  }

  testWidgets('"Yopish" xato sahifasidan chiqaradi', (tester) async {
    final repo = FakeSchoolRepository(today: todayWith({}));
    final scanner = await _openCheckIn(tester, repo);
    repo.failNext = const SchoolException(SchoolErrorCode.outsideHours);
    await _scan(tester, scanner, kioskLink(_token));

    await tester.tap(find.text('common.close'.tr()));
    await tester.pumpAndSettle();

    expect(find.text('open-check-in'), findsOneWidget);
  });

  testWidgets('ulanish QR\'i va begona QR serverga yuborilmaydi', (
    tester,
  ) async {
    final repo = FakeSchoolRepository(today: todayWith({}));
    final scanner = await _openCheckIn(tester, repo);

    await _scan(tester, scanner, 'farzandim:repair:abcdef123456');
    expect(find.text('school.errors.qrPairing'.tr()), findsOneWidget);

    await _scan(tester, scanner, 'https://example.com/menu');
    expect(find.text('school.errors.qrUnknown'.tr()), findsOneWidget);

    expect(find.text(FakeScanner.label), findsOneWidget);
    expect(repo.checkInTokens, isEmpty);
  });

  testWidgets('tekshirilayotganda yangi QR e\'tiborsiz (bitta so\'rov)', (
    tester,
  ) async {
    final repo = FakeSchoolRepository(
      today: todayWith({'record': _record('PRESENT', inAt: '07:56')}),
    );
    final scanner = await _openCheckIn(tester, repo);
    final hold = repo.holdNextCheckIn = Completer<void>();

    scanner.scan(kioskLink(_token));
    await tester.pump();
    expect(find.text('school.checkIn.checking'.tr()), findsOneWidget);

    scanner.scan(kioskLink(_nextToken));
    await tester.pump();
    expect(repo.checkInTokens, [_token]);

    hold.complete();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('school.checkIn.arrivedTitle'.tr()), findsOneWidget);
    expect(repo.checkInTokens, [_token]);
  });

  testWidgets('kichik ekran va katta shriftda natija toshib ketmaydi', (
    tester,
  ) async {
    final repo = FakeSchoolRepository(
      today: todayWith({'record': _record('LATE', inAt: '08:12')}),
    );
    final scanner = await _openCheckIn(
      tester,
      repo,
      size: const Size(320, 560),
      textScale: 1.3,
    );

    await _scan(tester, scanner, kioskLink(_token));

    expect(tester.takeException(), isNull);
    expect(find.text('school.checkIn.done'.tr()), findsOneWidget);
  });
}
