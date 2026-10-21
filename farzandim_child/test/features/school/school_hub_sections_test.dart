// "Maktabim" bo'limlari va bosh sahifa belgisi: psixologik testlar ro'yxati
// (bosilsa test ochiladi), "Bola ovozi" so'rovnoma kartasi, psixolog kartasi
// (yaqin suhbat bilan); bog'lanmagan bolada hech biri yo'q; sinfsiz
// o'quvchida psixolog va so'rovnoma yo'q; bo'lim yuklanmasa — qisqa xato va
// qayta urinish.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/iq/presentation/iq_display.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/presentation/care_display.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/screens/school_hub_screen.dart';
import 'package:farzandim_child/features/school/presentation/widgets/care_hub_cards.dart';
import 'package:farzandim_child/features/school/presentation/widgets/psych_assignments_section.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_section.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_today_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_school_repository.dart';
import 'school_fixtures.dart';
import 'school_test_app.dart';

String _t(String key, [Map<String, String>? args]) => key.tr(namedArgs: args);

final _assignment = PsychAssignmentSummary.tryFromJson(psychSummaryJson)!;
final _activeSurvey = CareSurveyStatus.tryFromJson(careSurveyJson)!;

Future<void> _pumpHub(
  WidgetTester tester,
  FakeSchoolRepository repo, {
  Size size = const Size(393, 852),
  double textScale = 1,
}) => pumpSchoolApp(
  tester,
  repository: repo,
  initialLocation: SchoolRoutes.hub,
  size: size,
  textScale: textScale,
  routes: [
    GoRoute(path: SchoolRoutes.hub, builder: (_, _) => const SchoolHubScreen()),
    GoRoute(
      path: SchoolRoutes.test,
      builder: (_, state) => Scaffold(body: Text('test:${state.extra}')),
    ),
    markerRoute(SchoolRoutes.checkIn),
    markerRoute(SchoolRoutes.survey),
    markerRoute(SchoolRoutes.newRequest),
    markerRoute(SchoolRoutes.requests),
    markerRoute(IqRoutes.hub),
  ],
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(setUpSchoolWidgetTests);

  group('"Maktabim" bo\'limlari', () {
    testWidgets('psixologik testlar: ro\'yxat, ma\'lumot va test ochiladi', (
      tester,
    ) async {
      final repo = FakeSchoolRepository(
        today: todayWith({}),
        psychAssignments: [_assignment],
      );
      await _pumpHub(tester, repo);

      expect(tester.takeException(), isNull);
      expect(find.byType(PsychAssignmentsSection), findsOneWidget);
      expect(find.text(_t('school.psych.title')), findsOneWidget);
      expect(find.text('Diqqat testi'), findsOneWidget);
      expect(find.text(_t('school.psych.kinds.attention')), findsOneWidget);
      // 13:00Z → 18:00 Toshkent, 25-oktabr.
      expect(
        find.text(
          '${'home.questions'.plural(3)} · '
          '${_t('school.psych.minutes', {'count': '10'})} · '
          '${_t('school.psych.until', {'date': '25-oktabr'})}',
        ),
        findsOneWidget,
      );

      await _tap(tester, find.text('Diqqat testi'));
      expect(find.text('test:assign-1'), findsOneWidget);
    });

    testWidgets(
      'Parvoz IQ topshirig\'i — IQ sahifasi ochiladi (maktab testi emas)',
      (tester) async {
        final iq = PsychAssignmentSummary.tryFromJson({
          ...psychSummaryJson,
          'assignmentId': 'assign-iq',
          'testId': 'parvoz-iq',
          'kind': 'IQ',
          'title': 'Parvoz IQ — mantiqiy fikrlash',
          'timeLimitMin': null,
        })!;
        expect(iq.kind, PsychKind.iq);
        final repo = FakeSchoolRepository(
          today: todayWith({}),
          psychAssignments: [iq],
        );
        await _pumpHub(tester, repo);
        expect(find.text(_t('school.psych.kinds.iq')), findsOneWidget);

        await _tap(tester, find.text('Parvoz IQ — mantiqiy fikrlash'));
        expect(find.text('page:${IqRoutes.hub}'), findsOneWidget);
        expect(find.textContaining('test:'), findsNothing);
      },
    );

    testWidgets('test bo\'lmasa — bo\'lim yo\'q', (tester) async {
      await _pumpHub(tester, FakeSchoolRepository(today: todayWith({})));

      expect(find.text(_t('school.psych.title')), findsNothing);
      expect(find.byType(SchoolSectionError), findsNothing);
    });

    testWidgets('faol so\'rovnoma — "Javob berish" so\'rovnomani ochadi', (
      tester,
    ) async {
      final repo = FakeSchoolRepository(
        today: todayWith({}),
        careSurvey: _activeSurvey,
      );
      await _pumpHub(tester, repo);

      expect(find.text(_t('school.survey.title')), findsOneWidget);
      expect(find.text('Haftalik so‘rovnoma'), findsOneWidget);
      expect(find.text(_t('school.survey.privacyShort')), findsOneWidget);

      await _tap(tester, find.text(_t('school.survey.answer')));
      expect(find.text('page:${SchoolRoutes.survey}'), findsOneWidget);
    });

    testWidgets('javob berilgan so\'rovnoma — rahmat, tugma yo\'q', (
      tester,
    ) async {
      final repo = FakeSchoolRepository(
        today: todayWith({}),
        careSurvey: const CareSurveyStatus(isEnrolled: true, isAnswered: true),
      );
      await _pumpHub(tester, repo);

      expect(find.text(_t('school.survey.answered')), findsOneWidget);
      expect(find.text(_t('school.survey.answer')), findsNothing);
    });

    testWidgets('psixolog kartasi: yozish, murojaatlarim va yaqin suhbat', (
      tester,
    ) async {
      final meetingAt = DateTime.now().toUtc().add(const Duration(days: 1));
      final repo = FakeSchoolRepository(
        today: todayWith({}),
        careRequests: [
          CareRequest(
            id: 'req-1',
            topic: CareTopic.peers,
            urgency: CareUrgency.normal,
            status: CareRequestStatus.scheduled,
            createdAt: DateTime.now().toUtc(),
            meetingAt: meetingAt,
          ),
        ],
      );
      await _pumpHub(tester, repo);

      expect(find.byType(CareHelpCard), findsOneWidget);
      expect(find.text(_t('school.requests.hubTitle')), findsOneWidget);
      expect(
        find.text(
          _t('school.requests.nextMeeting', {
            'date': tashkentDateTime(meetingAt),
          }),
        ),
        findsOneWidget,
      );

      await _tap(tester, find.text(_t('school.requests.write')));
      expect(find.text('page:${SchoolRoutes.newRequest}'), findsOneWidget);
    });

    testWidgets('sinfsiz o\'quvchi — psixolog va so\'rovnoma kartasi yo\'q', (
      tester,
    ) async {
      final repo = FakeSchoolRepository(
        today: todayWith({'className': null, 'shift': null}),
        careSurvey: _activeSurvey,
      );
      await _pumpHub(tester, repo);

      expect(tester.takeException(), isNull);
      expect(find.byType(CareHelpCard), findsNothing);
      expect(find.byType(CareSurveyCard), findsNothing);
      expect(find.text(_t('school.requests.write')), findsNothing);
      expect(repo.calls, isNot(contains('loadCareRequests')));
      expect(repo.calls, isNot(contains('loadCareSurvey')));
    });

    testWidgets('"Murojaatlarim" tugmasi ro\'yxatni ochadi', (tester) async {
      await _pumpHub(tester, FakeSchoolRepository(today: todayWith({})));

      await _tap(tester, find.text(_t('school.requests.title')));
      expect(find.text('page:${SchoolRoutes.requests}'), findsOneWidget);
    });

    testWidgets('bog\'lanmagan — bo\'limlar yo\'q va so\'rov yuborilmaydi', (
      tester,
    ) async {
      final repo = FakeSchoolRepository(
        psychAssignments: [_assignment],
        careSurvey: _activeSurvey,
      );
      await _pumpHub(tester, repo);

      expect(find.byType(PsychAssignmentsSection), findsNothing);
      expect(find.byType(CareSurveyCard), findsNothing);
      expect(find.byType(CareHelpCard), findsNothing);
      expect(repo.calls, ['loadToday']);
    });

    testWidgets('testlar yuklanmasa — qisqa xato, "Qayta urinish" tiklaydi', (
      tester,
    ) async {
      final repo =
          FakeSchoolRepository(
              today: todayWith({}),
              psychAssignments: [_assignment],
            )
            ..failOnce['loadPsychAssignments'] = const SchoolException(
              SchoolErrorCode.network,
            );
      await _pumpHub(tester, repo);

      expect(find.byType(SchoolSectionError), findsOneWidget);
      expect(find.text(_t('school.hub.sectionError')), findsOneWidget);

      await _tap(
        tester,
        find.descendant(
          of: find.byType(SchoolSectionError),
          matching: find.text(_t('common.retry')),
        ),
      );
      expect(find.byType(SchoolSectionError), findsNothing);
      expect(find.text('Diqqat testi'), findsOneWidget);
    });

    testWidgets('320pt ekran va katta shriftda toshib ketmaydi', (
      tester,
    ) async {
      final repo = FakeSchoolRepository(
        today: todayWith({}),
        psychAssignments: [_assignment],
        careSurvey: _activeSurvey,
      );
      await _pumpHub(tester, repo, size: const Size(320, 640), textScale: 1.3);

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byType(CareHelpCard),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('bosh sahifa belgisi', () {
    Future<void> pumpCard(WidgetTester tester, FakeSchoolRepository repo) =>
        pumpSchoolApp(
          tester,
          repository: repo,
          initialLocation: '/dashboard',
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [SchoolTodayCard()],
                ),
              ),
            ),
            markerRoute(SchoolRoutes.hub),
          ],
        );

    testWidgets('yechilmagan testlar soni ko\'rinadi, bosilsa "Maktabim"', (
      tester,
    ) async {
      final second = PsychAssignmentSummary.tryFromJson({
        ...psychSummaryJson,
        'assignmentId': 'assign-2',
      })!;
      final repo = FakeSchoolRepository(
        today: todayWith({}),
        psychAssignments: [_assignment, second],
      );
      await pumpCard(tester, repo);

      final badge = find.text(_t('school.psych.homeBadge', {'count': '2'}));
      expect(badge, findsOneWidget);

      await _tap(tester, badge);
      expect(find.text('page:${SchoolRoutes.hub}'), findsOneWidget);
    });

    testWidgets('test yo\'q — belgi yo\'q', (tester) async {
      await pumpCard(tester, FakeSchoolRepository(today: todayWith({})));

      expect(find.byType(SchoolTodayCard), findsOneWidget);
      expect(find.textContaining(_t('school.psych.title')), findsNothing);
    });
  });
}
