// "Maktabim" — maktab topshiriqlari: tarjima qilingan nom, muddat va
// "Bajarildi", bajarilmaganlar birinchi; test — shu fanning kunlik testi,
// audiokitob — kitob sahifasi (topilmasa — ro'yxat va izoh). "Bugungi
// testlar" plitkalarida "Maktab topshirig'i" belgisi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/core/utils/tashkent_time.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_series.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/today_tests_card.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/presentation/learning_navigation.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/subject_icon.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/features/school/presentation/assignment_navigation.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/screens/school_hub_screen.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_assignments_section.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_section.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_task_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_school_repository.dart';
import 'school_fixtures.dart';
import 'school_test_app.dart';

String _t(String key, [Map<String, String>? args]) => key.tr(namedArgs: args);

/// Toshkent kunidan [offset] kun keyingi sana (`YYYY-MM-DD`).
String _day(int offset) {
  final now = tashkentNow();
  final day = DateTime(now.year, now.month, now.day + offset);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${day.year}-${two(day.month)}-${two(day.day)}';
}

SchoolAssignment _assignment(Map<String, Object?> changes) =>
    SchoolAssignment.tryFromJson({...schoolAssignmentJson, ...changes})!;

final _mathTomorrow = _assignment({
  'id': 'math',
  'done': false,
  'dueDate': _day(1),
});
final _physicsDone = _assignment({
  'id': 'physics',
  'subject': 'PHYSICS',
  'title': 'Kunlik test: Fizika',
  'done': true,
  'note': '',
});
final _bookToday = _assignment({
  'id': 'book',
  'kind': 'AUDIOBOOK',
  'materialId': 'audiobook:p2',
  'title': 'Mehrobdan chayon 2 — Abdulla Qodiriy',
  'subject': null,
  'done': null,
  'note': '',
  'dueDate': _day(0),
});

AudiobookModel _book(String id, String title) => AudiobookModel(
  id: id,
  title: title,
  author: 'Abdulla Qodiriy',
  description: '',
  coverUrl: '',
  audioUrl: '',
  durationSeconds: 600,
  duration: '10:00',
  category: 'Adabiyot',
  hashtags: const [],
  listenCount: 0,
  coverColor: const Color(0xFF000000),
);

class _Books extends AudiobooksNotifier {
  _Books(this._load);

  final Future<List<AudiobookModel>> Function() _load;

  @override
  Future<List<AudiobookModel>> build() => _load();
}

Override _books(Future<List<AudiobookModel>> Function() load) =>
    backendAudiobooksProvider.overrideWith(() => _Books(load));

Future<void> _pumpHub(
  WidgetTester tester,
  FakeSchoolRepository repo, {
  List<Override> overrides = const [],
}) => pumpSchoolApp(
  tester,
  repository: repo,
  initialLocation: SchoolRoutes.hub,
  overrides: overrides,
  routes: [
    GoRoute(path: SchoolRoutes.hub, builder: (_, _) => const SchoolHubScreen()),
    GoRoute(
      path: LearningRoutes.quiz,
      builder: (_, state) =>
          Scaffold(body: Text('quiz:${(state.extra! as Subject).name}')),
    ),
    GoRoute(
      path: AssignmentMaterialRoutes.audiobookDetail,
      builder: (_, state) => Scaffold(
        body: Text('book:${(state.extra! as AudiobookSeries).title}'),
      ),
    ),
    markerRoute(AssignmentMaterialRoutes.audiobooks),
    markerRoute(AssignmentMaterialRoutes.videos),
  ],
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(setUpSchoolWidgetTests);

  group('"Maktabim" — maktab topshiriqlari', () {
    testWidgets('nom, muddat, izoh va "Bajarildi"; bajarilmaganlar birinchi', (
      tester,
    ) async {
      final repo = FakeSchoolRepository(
        today: todayWith({}),
        assignments: [_physicsDone, _mathTomorrow, _bookToday],
      );
      await _pumpHub(tester, repo);

      expect(tester.takeException(), isNull);
      expect(find.text(_t('school.assignments.title')), findsOneWidget);
      // Faqat bajarilmaganlar sanaladi.
      expect(
        find.descendant(
          of: find.byType(SchoolAssignmentsSection),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      // Test nomi ilovada tarjima qilinadi; kitob nomi — serverdan.
      final math = _t('school.assignments.testTitle', {
        'subject': _t('subjects.math'),
      });
      final physics = _t('school.assignments.testTitle', {
        'subject': _t('subjects.physics'),
      });
      expect(find.text(math), findsOneWidget);
      expect(find.text('Mehrobdan chayon 2 — Abdulla Qodiriy'), findsOneWidget);
      expect(
        find.text(_t('school.assignments.kinds.audiobook')),
        findsOneWidget,
      );
      expect(find.text(_t('school.assignments.due.tomorrow')), findsOneWidget);
      expect(find.text(_t('school.assignments.due.today')), findsOneWidget);
      expect(find.text('Juma kunigacha'), findsOneWidget);
      expect(find.text(_t('school.assignments.done')), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(physics)).dy,
        greaterThan(tester.getTopLeft(find.text(math)).dy),
      );
    });

    testWidgets('muddati o\'tgan — sana bilan', (tester) async {
      final overdue = _assignment({
        'done': false,
        'overdue': true,
        'dueDate': _day(-2),
      });
      await _pumpHub(
        tester,
        FakeSchoolRepository(today: todayWith({}), assignments: [overdue]),
      );

      final date = localizedDayMonth(DateTime.parse(_day(-2)));
      expect(
        find.text('${_t('school.assignments.due.overdue')} · $date'),
        findsOneWidget,
      );
    });

    testWidgets('topshiriq yo\'q — bo\'lim yo\'q', (tester) async {
      final repo = FakeSchoolRepository(today: todayWith({}));
      await _pumpHub(tester, repo);

      expect(repo.calls, contains('loadAssignments'));
      expect(find.text(_t('school.assignments.title')), findsNothing);
      expect(find.byType(SchoolSectionError), findsNothing);
    });

    testWidgets('yuklanmasa — qisqa xato, qayta urinish ro\'yxatni ochadi', (
      tester,
    ) async {
      final repo =
          FakeSchoolRepository(
              today: todayWith({}),
              assignments: [_mathTomorrow],
            )
            ..failOnce['loadAssignments'] = const SchoolException(
              SchoolErrorCode.network,
            );
      await _pumpHub(tester, repo);

      expect(find.byType(SchoolSectionError), findsOneWidget);
      await _tap(
        tester,
        find.descendant(
          of: find.byType(SchoolSectionError),
          matching: find.text(_t('common.retry')),
        ),
      );
      expect(find.byType(SchoolSectionError), findsNothing);
      expect(find.text(_t('school.assignments.title')), findsOneWidget);
    });

    testWidgets('test — shu fanning kunlik testi ochiladi', (tester) async {
      await _pumpHub(
        tester,
        FakeSchoolRepository(
          today: todayWith({}),
          assignments: [_mathTomorrow],
        ),
      );

      await _tap(
        tester,
        find.text(
          _t('school.assignments.testTitle', {'subject': _t('subjects.math')}),
        ),
      );
      expect(find.text('quiz:math'), findsOneWidget);
    });

    testWidgets('audiokitob — qismi bor butun kitob sahifasi', (tester) async {
      await _pumpHub(
        tester,
        FakeSchoolRepository(today: todayWith({}), assignments: [_bookToday]),
        overrides: [
          _books(
            () async => [
              _book('p1', 'Mehrobdan chayon 1'),
              _book('p2', 'Mehrobdan chayon 2'),
            ],
          ),
        ],
      );

      await _tap(tester, find.text('Mehrobdan chayon 2 — Abdulla Qodiriy'));
      expect(find.text('book:Mehrobdan chayon'), findsOneWidget);
    });

    testWidgets('kitob ro\'yxatda yo\'q — audiokitoblar ro\'yxati va izoh', (
      tester,
    ) async {
      await _pumpHub(
        tester,
        FakeSchoolRepository(today: todayWith({}), assignments: [_bookToday]),
        overrides: [
          _books(() async => [_book('other', 'Shum bola')]),
        ],
      );

      await _tap(tester, find.text('Mehrobdan chayon 2 — Abdulla Qodiriy'));
      expect(
        find.text('page:${AssignmentMaterialRoutes.audiobooks}'),
        findsOneWidget,
      );
      expect(find.text(_t('school.assignments.bookNotFound')), findsOneWidget);
    });

    testWidgets('kitoblar yuklanmasa — audiokitoblar ro\'yxati', (
      tester,
    ) async {
      await _pumpHub(
        tester,
        FakeSchoolRepository(today: todayWith({}), assignments: [_bookToday]),
        overrides: [_books(() async => throw Exception('oflayn'))],
      );

      await _tap(tester, find.text('Mehrobdan chayon 2 — Abdulla Qodiriy'));
      expect(
        find.text('page:${AssignmentMaterialRoutes.audiobooks}'),
        findsOneWidget,
      );
    });
  });

  group('"Bugungi testlar" — "Maktab topshirig\'i" belgisi', () {
    const plan = DailyPlan(
      items: [
        DailyPlanItem(subject: Subject.math, questionCount: 5),
        DailyPlanItem(subject: Subject.physics, questionCount: 5),
        DailyPlanItem(subject: Subject.english, questionCount: 5),
      ],
    );

    Future<void> pumpCard(WidgetTester tester, FakeSchoolRepository repo) =>
        pumpSchoolApp(
          tester,
          repository: repo,
          initialLocation: '/dashboard',
          overrides: [
            dailyPlanProvider.overrideWithValue(plan),
            needsLearningSetupProvider.overrideWithValue(false),
          ],
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [TodayTestsCard()],
                ),
              ),
            ),
          ],
        );

    Finder badgedSubject(Subject subject) => find.ancestor(
      of: find.byWidgetPredicate(
        (w) => w is SubjectIcon && w.subject == subject,
      ),
      matching: find.byWidgetPredicate((w) => w is SchoolTaskBadge && w.show),
    );

    testWidgets('faqat maktab bergan, hali yechilmagan test fanida', (
      tester,
    ) async {
      final repo = FakeSchoolRepository(
        today: todayWith({}),
        assignments: [_mathTomorrow, _physicsDone, _bookToday],
      );
      await pumpCard(tester, repo);

      expect(tester.takeException(), isNull);
      expect(badgedSubject(Subject.math), findsOneWidget);
      expect(badgedSubject(Subject.physics), findsNothing);
      expect(badgedSubject(Subject.english), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp(_t('school.assignments.badge'))),
        findsOneWidget,
      );
    });

    testWidgets('bog\'lanmagan bola — belgi yo\'q, so\'rov yo\'q', (
      tester,
    ) async {
      final repo = FakeSchoolRepository(assignments: [_mathTomorrow]);
      await pumpCard(tester, repo);

      expect(badgedSubject(Subject.math), findsNothing);
      expect(repo.calls, isNot(contains('loadAssignments')));
    });
  });
}
