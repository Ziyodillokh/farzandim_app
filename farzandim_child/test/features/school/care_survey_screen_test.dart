// "Bola ovozi" so'rovnomasi: maxfiylik matni, 1–5 shkala, har savol
// majburiy, yuborish; 409 — javob berilgan deb ko'rsatiladi, 404 —
// yakunlangan, tarmoq xatosida javoblar saqlanadi; chiqishda tasdiq.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_header.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/screens/care_survey_screen.dart';
import 'package:farzandim_child/features/school/presentation/widgets/care/survey_question_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_school_repository.dart';
import 'school_fixtures.dart';
import 'school_test_app.dart';

const _openLabel = 'open-survey';

final _active = CareSurveyStatus.tryFromJson(careSurveyJson)!;

String _t(String key, [Map<String, String>? args]) => key.tr(namedArgs: args);

FakeSchoolRepository _repo([CareSurveyStatus? survey]) =>
    FakeSchoolRepository(today: todayWith({}), careSurvey: survey ?? _active);

Future<void> _openSurvey(
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
                onPressed: () => context.push(SchoolRoutes.survey),
                child: const Text(_openLabel),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: SchoolRoutes.survey,
        builder: (_, _) => const CareSurveyScreen(),
      ),
      markerRoute(SchoolRoutes.hub),
    ],
  );
  await tester.tap(find.text(_openLabel));
  await tester.pumpAndSettle();
}

/// [question]-savolga (0 dan) [value] baho.
Future<void> _rate(WidgetTester tester, int question, int value) async {
  final option = find.descendant(
    of: find.byType(SurveyQuestionCard).at(question),
    matching: find.text(_t('school.survey.scale.$value')),
  );
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.text(_t('school.survey.submit')));
  await tester.pump();
  await tester.pumpAndSettle();
}

String _progress(int done, int total) =>
    _t('school.survey.progress', {'done': '$done', 'total': '$total'});

void main() {
  setUpAll(setUpSchoolWidgetTests);

  testWidgets('maxfiylik, savollar va 1–5 shkala; hammasi majburiy', (
    tester,
  ) async {
    final repo = _repo();
    await _openSurvey(tester, repo);

    expect(tester.takeException(), isNull);
    expect(find.text(_t('school.survey.privacy')), findsOneWidget);
    expect(find.text('Haftalik so‘rovnoma'), findsOneWidget);
    expect(find.byType(SurveyQuestionCard), findsNWidgets(2));
    for (var v = 1; v <= 5; v++) {
      expect(find.text(_t('school.survey.scale.$v')), findsNWidgets(2));
    }
    expect(
      find.text('${_progress(0, 2)} · ${_t('school.survey.allRequired')}'),
      findsOneWidget,
    );

    // Bitta savolga javob — yuborilmaydi.
    await _rate(tester, 0, 2);
    await _submit(tester);
    expect(repo.calls, isNot(contains('submitCareSurvey')));

    await _rate(tester, 1, 5);
    expect(find.text(_progress(2, 2)), findsOneWidget);
    await _submit(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(_t('school.survey.doneTitle')), findsOneWidget);
    expect(find.text(_t('school.survey.doneBody')), findsOneWidget);
    expect(repo.submittedSurvey, {'q1': 2, 'q2': 5});

    await tester.tap(find.text(_t('school.survey.done')));
    await tester.pumpAndSettle();
    expect(find.text(_openLabel), findsOneWidget);
  });

  testWidgets('javobni o\'zgartirish mumkin — oxirgisi yuboriladi', (
    tester,
  ) async {
    final repo = _repo();
    await _openSurvey(tester, repo);

    await _rate(tester, 0, 1);
    await _rate(tester, 0, 4);
    await _rate(tester, 1, 3);
    await _submit(tester);

    expect(repo.submittedSurvey, {'q1': 4, 'q2': 3});
  });

  testWidgets('409 — javob berilgan deb ko\'rsatiladi', (tester) async {
    final repo = _repo();
    await _openSurvey(tester, repo);
    await _rate(tester, 0, 3);
    await _rate(tester, 1, 3);

    repo.failNext = const SchoolException(SchoolErrorCode.alreadyAnswered);
    await _submit(tester);

    expect(find.text(_t('school.survey.alreadyTitle')), findsOneWidget);
    expect(find.text(_t('school.errors.alreadyAnswered')), findsOneWidget);
    expect(find.text(_t('school.survey.sendFailedTitle')), findsNothing);
  });

  testWidgets('404 — so\'rovnoma yakunlangan', (tester) async {
    final repo = _repo();
    await _openSurvey(tester, repo);
    await _rate(tester, 0, 3);
    await _rate(tester, 1, 3);

    repo.failNext = const SchoolException(SchoolErrorCode.surveyNotFound);
    await _submit(tester);

    expect(find.text(_t('school.survey.closedTitle')), findsOneWidget);
    expect(find.text(_t('school.errors.surveyNotFound')), findsOneWidget);
  });

  testWidgets('tarmoq xatosi — javoblar saqlanadi, qayta yuboriladi', (
    tester,
  ) async {
    final repo = _repo();
    await _openSurvey(tester, repo);
    await _rate(tester, 0, 5);
    await _rate(tester, 1, 4);

    repo.failNext = const SchoolException(SchoolErrorCode.network);
    await _submit(tester);

    expect(
      find.text(
        '${_t('school.survey.sendFailedTitle')}. '
        '${_t('school.errors.network')}',
      ),
      findsOneWidget,
    );
    expect(find.text(_progress(2, 2)), findsOneWidget);

    await _submit(tester);
    expect(find.text(_t('school.survey.doneTitle')), findsOneWidget);
    expect(repo.submittedSurvey, {'q1': 5, 'q2': 4});
  });

  testWidgets('faol so\'rovnoma yo\'q va javob berilgan holatlar', (
    tester,
  ) async {
    await _openSurvey(
      tester,
      _repo(const CareSurveyStatus(isEnrolled: true, isAnswered: false)),
    );
    expect(find.text(_t('school.survey.noneTitle')), findsOneWidget);
    expect(find.text(_t('school.survey.submit')), findsNothing);
  });

  testWidgets('javob berilgan — rahmat, shkala yo\'q', (tester) async {
    await _openSurvey(
      tester,
      _repo(const CareSurveyStatus(isEnrolled: true, isAnswered: true)),
    );
    expect(find.text(_t('school.survey.answered')), findsOneWidget);
    expect(find.byType(SurveyQuestionCard), findsNothing);
  });

  testWidgets('javob belgilangach chiqishda tasdiq so\'raladi', (tester) async {
    final repo = _repo();
    await _openSurvey(tester, repo);
    await _rate(tester, 0, 2);

    await tester.tap(find.byType(HeaderIconButton).first);
    await tester.pumpAndSettle();
    expect(find.text(_t('school.leave.surveyTitle')), findsOneWidget);

    await tester.tap(find.text(_t('school.leave.leave')));
    await tester.pumpAndSettle();
    expect(find.text(_openLabel), findsOneWidget);
    expect(repo.calls, isNot(contains('submitCareSurvey')));
  });

  testWidgets('320pt ekran va katta shriftda toshib ketmaydi', (tester) async {
    await _openSurvey(
      tester,
      _repo(),
      size: const Size(320, 640),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await _rate(tester, 1, 4);
    expect(tester.takeException(), isNull);
  });
}
