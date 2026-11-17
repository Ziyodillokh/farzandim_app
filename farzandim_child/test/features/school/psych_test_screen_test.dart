// Psixologik test sahifasi (soxta soat — test binding'ining FakeAsync
// soati): kirish → stimul (soniyalar) → savol, "Keyingi" javobsiz yopiq,
// MULTI bo'sh ham javob, vaqt tugaganda avtomatik yuborish (`durationSec`),
// 409 — bajarilgan, tarmoq xatosida javoblar saqlanib qayta yuboriladi,
// chiqishda tasdiq.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/psych_answer.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/screens/psych_test_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_school_repository.dart';
import 'school_fixtures.dart';
import 'school_test_app.dart';

const _openLabel = 'open-test';

PsychTest _test({Object? timeLimitMin = 10, List<Object?>? items}) =>
    PsychTest.tryFromJson({
      ...psychTestJson,
      'timeLimitMin': timeLimitMin,
      'items': ?items,
    })!;

/// Bitta LIKERT savolli, vaqt chegarasiz test.
final _oneLikert = _test(
  timeLimitMin: null,
  items: [
    {'id': 'l1', 'type': 'LIKERT', 'text': 'Darsda diqqatim tez tarqaladi'},
  ],
);

String _t(String key, [Map<String, String>? args]) => key.tr(namedArgs: args);

/// Boshlang'ich sahifadan testni ochadi (yopilganda shu sahifaga qaytadi).
Future<void> _openTest(
  WidgetTester tester,
  FakeSchoolRepository repo, {
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
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
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () =>
                    context.push(SchoolRoutes.test, extra: 'assign-1'),
                child: const Text(_openLabel),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: SchoolRoutes.test,
        builder: (_, state) => PsychTestScreen(
          assignmentId: state.extra! as String,
          clock: () => tester.binding.clock.now(),
        ),
      ),
      markerRoute(SchoolRoutes.hub),
    ],
  );
  await tester.tap(find.text(_openLabel));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  setUpAll(setUpSchoolWidgetTests);

  testWidgets('kirish: nom, savollar soni, vaqt, ko\'rsatma va ogohlantirish', (
    tester,
  ) async {
    final repo = FakeSchoolRepository(psychTests: [_test()]);

    await _openTest(tester, repo);

    expect(tester.takeException(), isNull);
    expect(find.text('Diqqat testi'), findsWidgets);
    expect(find.text(_t('school.psych.kinds.attention')), findsOneWidget);
    expect(find.text('home.questions'.plural(3)), findsOneWidget);
    expect(
      find.text(_t('school.psych.minutes', {'count': '10'})),
      findsOneWidget,
    );
    expect(find.text('Savollarni diqqat bilan o‘qing'), findsOneWidget);
    expect(
      find.text(_t('school.psych.timeNote', {'count': '10'})),
      findsOneWidget,
    );
    // Vaqt hali ketmaydi — teskari sanoq yo'q.
    expect(find.text('10:00'), findsNothing);
    expect(repo.calls, ['loadPsychTest']);
  });

  testWidgets('stimul → savol (soxta soat), "Keyingi" javobsiz yopiq, '
      'MULTI bo\'sh ham javob, yuborish va "Rahmat!"', (tester) async {
    final repo = FakeSchoolRepository(psychTests: [_test()]);
    await _openTest(tester, repo);

    await _tap(tester, find.text(_t('school.psych.start')));

    // Stimul: "Eslab qoling!", matn va soniyalar; vaqt ketdi.
    expect(find.text(_t('school.psych.remember')), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text(_t('school.psych.seconds', {'sec': '3'})), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text(_t('school.psych.next')), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_t('school.psych.seconds', {'sec': '2'})), findsOneWidget);
    expect(find.text('09:59'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    // Savol o'zi ochildi, stimul qaytmaydi.
    expect(find.text(_t('school.psych.remember')), findsNothing);
    expect(find.text('Qaysi raqam ko‘rsatildi?'), findsOneWidget);
    expect(find.text('09:57'), findsOneWidget);

    // Javobsiz "Keyingi" ishlamaydi.
    await _tap(tester, find.text(_t('school.psych.next')));
    expect(find.text('Qaysi raqam ko‘rsatildi?'), findsOneWidget);

    await _tap(tester, find.text('9'));
    await _tap(tester, find.text(_t('school.psych.next')));
    expect(find.text('Darsda diqqatim tez tarqaladi'), findsOneWidget);

    await _tap(tester, find.text(_t('school.psych.likert.4')));
    await _tap(tester, find.text(_t('school.psych.next')));

    // MULTI (oxirgi): hech narsa tanlamay ham yakunlash mumkin.
    expect(find.text('Qaysilari meva?'), findsOneWidget);
    expect(find.text(_t('school.psych.multiHint')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await _tap(tester, find.text(_t('school.psych.finish')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_t('school.psych.doneTitle')), findsOneWidget);
    expect(find.text(_t('school.psych.doneBody')), findsOneWidget);
    expect(repo.calls, ['loadPsychTest', 'submitPsychTest']);
    final answers = repo.submittedAnswers!;
    expect(encodePsychAnswers(_test(), answers), {
      's1': 'b',
      'l1': 4,
      'm1': <String>[],
    });
    expect(repo.submittedDurationSec, 5);

    await _tap(tester, find.text(_t('school.psych.done')));
    await tester.pumpAndSettle();
    expect(find.text(_openLabel), findsOneWidget);
  });

  testWidgets('"Savolga o\'tish" stimulni erta yopadi', (tester) async {
    final repo = FakeSchoolRepository(psychTests: [_test()]);
    await _openTest(tester, repo);
    await _tap(tester, find.text(_t('school.psych.start')));

    await _tap(tester, find.text(_t('school.psych.toQuestion')));

    expect(find.text(_t('school.psych.remember')), findsNothing);
    expect(find.text('Qaysi raqam ko‘rsatildi?'), findsOneWidget);
  });

  testWidgets('vaqt tugasa — belgilangan javoblar o\'zi yuboriladi', (
    tester,
  ) async {
    final repo = FakeSchoolRepository(psychTests: [_test(timeLimitMin: 1)]);
    await _openTest(tester, repo);
    await _tap(tester, find.text(_t('school.psych.start')));
    expect(find.text('01:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await _tap(tester, find.text('7'));
    // "Keyingi" bosilmadi — tanlangan javob baribir yuboriladi.
    await tester.pump(const Duration(seconds: 50));
    expect(find.text('00:07'), findsOneWidget);
    expect(repo.calls, ['loadPsychTest']);

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();

    expect(find.text(_t('school.psych.timeUpTitle')), findsOneWidget);
    expect(find.text(_t('school.psych.timeUpBody')), findsOneWidget);
    expect(repo.calls, ['loadPsychTest', 'submitPsychTest']);
    expect(encodePsychAnswers(_test(), repo.submittedAnswers!), {'s1': 'a'});
    expect(repo.submittedDurationSec, 60);
  });

  testWidgets('vaqt tugadi, javob yo\'q — hech narsa yuborilmaydi', (
    tester,
  ) async {
    final repo = FakeSchoolRepository(psychTests: [_test(timeLimitMin: 1)]);
    await _openTest(tester, repo);
    await _tap(tester, find.text(_t('school.psych.start')));

    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();

    expect(find.text(_t('school.psych.timeUpTitle')), findsOneWidget);
    expect(find.text(_t('school.psych.timeUpEmptyBody')), findsOneWidget);
    expect(repo.calls, ['loadPsychTest']);
  });

  testWidgets('yuborishda 409 — test bajarilgan deb ko\'rsatiladi', (
    tester,
  ) async {
    final repo = FakeSchoolRepository(psychTests: [_oneLikert]);
    await _openTest(tester, repo);
    await _tap(tester, find.text(_t('school.psych.start')));
    await _tap(tester, find.text(_t('school.psych.likert.2')));

    repo.failNext = const SchoolException(SchoolErrorCode.alreadySubmitted);
    await _tap(tester, find.text(_t('school.psych.finish')));
    await tester.pumpAndSettle();

    expect(find.text(_t('school.psych.doneTitle')), findsOneWidget);
    expect(find.text(_t('school.errors.alreadySubmitted')), findsOneWidget);
    expect(find.text(_t('school.psych.sendFailedTitle')), findsNothing);
  });

  testWidgets('ochishda 409 — bajarilgan; 404 — test yopilgan', (tester) async {
    final repo = FakeSchoolRepository(psychTests: [_oneLikert])
      ..failNext = const SchoolException(SchoolErrorCode.alreadySubmitted);
    await _openTest(tester, repo);

    expect(find.text(_t('school.errors.alreadySubmitted')), findsOneWidget);
    expect(find.text(_t('school.psych.start')), findsNothing);

    await _tap(tester, find.text(_t('school.psych.done')));
    await tester.pumpAndSettle();
    repo.failNext = const SchoolException(SchoolErrorCode.assignmentNotFound);
    await tester.tap(find.text(_openLabel));
    await tester.pumpAndSettle();

    expect(find.text(_t('school.psych.closedTitle')), findsOneWidget);
    expect(find.text(_t('school.errors.assignmentNotFound')), findsOneWidget);
  });

  testWidgets('tarmoq xatosi — javoblar saqlanadi, qayta yuboriladi', (
    tester,
  ) async {
    final repo = FakeSchoolRepository(psychTests: [_oneLikert]);
    await _openTest(tester, repo);
    await _tap(tester, find.text(_t('school.psych.start')));
    await _tap(tester, find.text(_t('school.psych.likert.5')));

    repo.failNext = const SchoolException(SchoolErrorCode.network);
    await _tap(tester, find.text(_t('school.psych.finish')));
    await tester.pump();

    expect(find.text(_t('school.psych.sendFailedTitle')), findsOneWidget);
    expect(find.text(_t('school.errors.network')), findsOneWidget);

    await _tap(tester, find.text(_t('common.retry')));
    await tester.pumpAndSettle();

    expect(find.text(_t('school.psych.doneTitle')), findsOneWidget);
    expect(repo.calls, ['loadPsychTest', 'submitPsychTest', 'submitPsychTest']);
    expect(encodePsychAnswers(_oneLikert, repo.submittedAnswers!), {'l1': 5});
  });

  testWidgets('yuborilayotganda "yuborilmoqda", yopish natijani kutadi', (
    tester,
  ) async {
    final hold = Completer<void>();
    final repo = FakeSchoolRepository(psychTests: [_oneLikert])
      ..holdNextSubmit = hold;
    await _openTest(tester, repo);
    await _tap(tester, find.text(_t('school.psych.start')));
    await _tap(tester, find.text(_t('school.psych.likert.3')));

    await _tap(tester, find.text(_t('school.psych.finish')));
    expect(find.text(_t('school.psych.sending')), findsOneWidget);

    await _tap(tester, find.byIcon(Icons.close_rounded));
    expect(find.text(_t('school.leave.testTitle')), findsNothing);

    hold.complete();
    await tester.pumpAndSettle();
    expect(find.text(_t('school.psych.doneTitle')), findsOneWidget);
  });

  testWidgets('yuklash xatosi — "Qayta urinish" bilan tiklanadi', (
    tester,
  ) async {
    final repo = FakeSchoolRepository(psychTests: [_oneLikert])
      ..failNext = const SchoolException(SchoolErrorCode.network);
    await _openTest(tester, repo);

    expect(find.text(_t('school.errors.network')), findsOneWidget);
    await _tap(tester, find.text(_t('common.retry')));
    await tester.pumpAndSettle();

    expect(find.text(_t('school.psych.start')), findsOneWidget);
  });

  testWidgets('boshlangan testdan chiqish — tasdiq; "Davom etish" qoldiradi', (
    tester,
  ) async {
    final repo = FakeSchoolRepository(psychTests: [_oneLikert]);
    await _openTest(tester, repo);
    await _tap(tester, find.text(_t('school.psych.start')));
    await _tap(tester, find.text(_t('school.psych.likert.1')));

    await _tap(tester, find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text(_t('school.leave.testTitle')), findsOneWidget);

    await tester.tap(find.text(_t('school.leave.stay')));
    await tester.pumpAndSettle();
    expect(find.text('Darsda diqqatim tez tarqaladi'), findsOneWidget);

    await _tap(tester, find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('school.leave.leave')));
    await tester.pumpAndSettle();

    expect(find.text(_openLabel), findsOneWidget);
    expect(repo.calls, ['loadPsychTest']);
  });

  testWidgets('kichik ekran va katta shriftda toshib ketmaydi', (tester) async {
    final repo = FakeSchoolRepository(psychTests: [_test()]);
    await _openTest(tester, repo, size: const Size(320, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);

    await _tap(tester, find.text(_t('school.psych.start')));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    expect(find.text('Qaysi raqam ko‘rsatildi?'), findsOneWidget);
  });
}
