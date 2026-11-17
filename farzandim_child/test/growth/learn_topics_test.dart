// U01 O'qish markazi, U02 bilim xaritasi va U03 mavzu: holatlar va o'tishlar.

import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/oqish/practice/practice_screen.dart';
import 'package:farzandim_child/growth/oqish/topics/topic_map_screen.dart';
import 'package:farzandim_child/growth/oqish/topics/topic_models.dart';
import 'package:farzandim_child/growth/oqish/topics/topic_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/learning/fake_learning_repository.dart';
import 'fake_topics_repository.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

const _profile = LearningProfile(
  grade: 6,
  subjects: [Subject.math, Subject.native],
);

FakeLearningRepository _learning() =>
    FakeLearningRepository(profile: _profile, clock: () => kG5Now);

final _topics = [
  topic(
    't1',
    'Natural sonlar',
    position: 1,
    mastery: TopicMastery.mastered,
    completedAttempts: 3,
  ),
  topic(
    't2',
    'Kasrlar',
    position: 2,
    mastery: TopicMastery.mastered,
    completedAttempts: 24,
    lastAssessedAt: DateTime(2026, 10, 28),
  ),
  topic('t3', 'Oʻnli kasrlar', position: 3, mastery: TopicMastery.practice),
  topic(
    't4',
    'Foizlar',
    position: 4,
    mastery: TopicMastery.practice,
    completedAttempts: 6,
    goal: 'Sonning foizini topishni oʻrganasan',
    lastResult: TopicResult(
      correct: 6,
      total: 10,
      completedAt: DateTime(2026, 11, 1),
    ),
  ),
  topic('t5', 'Nisbat va proporsiya', position: 5, available: false),
];

Future<FakeTopicsRepository> _pump(
  WidgetTester tester,
  String location, {
  List<LearningTopic>? topics,
}) async {
  final learning = _learning();
  final repo = FakeTopicsRepository(
    topics: topics ?? _topics,
    currentTopicId: 't4',
    learning: learning,
  );
  await pumpG5App(
    tester,
    routes: buildGrowthV5Routes(),
    initialLocation: location,
    overrides: g5Overrides(learning: learning, topics: repo),
  );
  return repo;
}

void main() {
  setUpAll(setUpG5WidgetTests);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('U01', () {
    testWidgets('sarlavha, bugungi mashq va fanlar', (tester) async {
      await _pump(tester, GrowthV5Routes.learn);

      expect(find.text('6-sinf · 2 ta fan'), findsOneWidget);
      expect(find.text('BUGUNGI MASHQ'), findsOneWidget);
      expect(find.text('Matematika'), findsWidgets);
      expect(find.text('Ona tili'), findsWidgets);
      // 6 ta fan: tanlangan ikkitasi + sinfdagi asosiy fanlar tartibda.
      for (final label in ['Ingliz tili', 'Fizika', 'Biologiya', 'Tarix']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Geografiya'), findsNothing);
      expect(find.text('Olimpiada'), findsOneWidget);
      expect(find.text('Tafakkur'), findsOneWidget);
      // Kutubxona va oflayn — vaqtincha yashirin.
      expect(find.text('Kutubxona'), findsNothing);
      expect(find.text('Oflayn'), findsNothing);
    });

    testWidgets('«Barcha fanlar» sinfdagi hamma fanni ko\'rsatadi', (
      tester,
    ) async {
      await _pump(tester, GrowthV5Routes.learn);
      await tester.tap(find.text('Barcha fanlar'));
      await settleG5(tester);

      expect(find.text('6-sinf · 9 ta fan'), findsOneWidget);
      for (final label in ['Geografiya', 'Informatika', 'Rus tili']) {
        await tester.scrollUntilVisible(find.text(label), 200);
        expect(find.text(label), findsOneWidget);
      }
      // Kimyo 7-sinfdan.
      expect(find.text('Kimyo'), findsNothing);
    });

    testWidgets('tugallanmagan mashq «Davom ettirish» kartasida', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'g5_unfinished_practice_v1@child-1':
            '{"subject":"math","answered":4,"total":10,"outcomes":[true,true,false,true],"day":"2026-11-05","topic":"Foizlar"}',
      });
      await _pump(tester, GrowthV5Routes.learn);

      expect(find.text('TUGALLANMAGAN MASHQ'), findsOneWidget);
      expect(find.text('Matematika · Foizlar'), findsOneWidget);
      expect(find.text('Davom ettirish'), findsOneWidget);
    });

    testWidgets('boshqa akkauntning tugallanmagan mashqi ko\'rinmaydi', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        // Eski qurilma-umumiy kalit va shu qurilmadagi boshqa bola.
        'g5_unfinished_practice_v1':
            '{"subject":"math","answered":4,"total":10,"outcomes":[],"day":"2026-11-05","topic":"Foizlar"}',
        'g5_unfinished_practice_v1@child-2':
            '{"subject":"math","answered":4,"total":10,"outcomes":[],"day":"2026-11-05","topic":"Foizlar"}',
      });
      await _pump(tester, GrowthV5Routes.learn);

      expect(find.text('TUGALLANMAGAN MASHQ'), findsNothing);
      expect(find.text('BUGUNGI MASHQ'), findsOneWidget);
    });

    testWidgets('kechagi tugallanmagan mashq ko\'rsatilmaydi', (tester) async {
      SharedPreferences.setMockInitialValues({
        'g5_unfinished_practice_v1@child-1':
            '{"subject":"math","answered":4,"total":10,"outcomes":[],"day":"2026-11-04","topic":""}',
      });
      await _pump(tester, GrowthV5Routes.learn);

      expect(find.text('TUGALLANMAGAN MASHQ'), findsNothing);
      expect(find.text('BUGUNGI MASHQ'), findsOneWidget);
    });

    testWidgets('fan plitasi bilim xaritasini ochadi', (tester) async {
      await _pump(tester, GrowthV5Routes.learn);

      await tester.tap(find.bySemanticsLabel('Bilim xaritasi: Ona tili'));
      await settleG5(tester);

      expect(
        tester.widget<TopicMapScreen>(find.byType(TopicMapScreen)).subject,
        Subject.native,
      );
    });
  });

  group('U02', () {
    testWidgets('mavzular holati, joriy mavzu va «tez orada»', (tester) async {
      await _pump(tester, GrowthV5Routes.subjectMap(Subject.math));

      expect(find.text('6-sinf · 5 ta mavzu'), findsOneWidget);
      expect(find.text('Oʻzlashtirilgan'), findsNWidgets(2));
      expect(find.text('Mashq kerak'), findsNWidgets(2));
      expect(find.text('Joriy mavzu'), findsOneWidget);
      expect(find.text('Savollar tez orada'), findsOneWidget);
      expect(find.text('28-oktabr · 24 ta topshiriq'), findsOneWidget);
    });

    testWidgets('mavzu bosilsa U03 ochiladi', (tester) async {
      await _pump(tester, GrowthV5Routes.subjectMap(Subject.math));

      await tester.tap(find.text('Foizlar'));
      await settleG5(tester);

      expect(
        tester.widget<TopicScreen>(find.byType(TopicScreen)).topicId,
        't4',
      );
    });

    testWidgets('katalog yo\'q: aralash mashq taklifi', (tester) async {
      await _pump(
        tester,
        GrowthV5Routes.subjectMap(Subject.math),
        topics: const [],
      );

      expect(find.text('Mavzular xaritasi tez orada'), findsOneWidget);
      await tester.tap(find.text('Aralash mashq'));
      await settleG5(tester);
      expect(
        tester.widget<PracticeScreen>(find.byType(PracticeScreen)).topicId,
        isNull,
      );
    });
  });

  group('U03', () {
    testWidgets('maqsad, oldingi natija va boshlash mavzu mashqini ochadi', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        GrowthV5Routes.topic(Subject.math, 't4'),
      );

      expect(find.text('Sonning foizini topishni oʻrganasan'), findsOneWidget);
      expect(find.text('6/10 · 1-noyabr'), findsOneWidget);
      expect(find.text('Foizlar · yangi mavzu'), findsOneWidget);
      expect(find.text('Oʻnli kasrlar · takror'), findsOneWidget);

      await tester.tap(find.text('Boshlash'));
      await settleG5(tester);

      expect(
        tester.widget<PracticeScreen>(find.byType(PracticeScreen)).topicId,
        't4',
      );
      expect(repo.startedTopics, ['t4']);
    });

    testWidgets('tugallanmagan urinish: «Davom ettirish (4/10)»', (
      tester,
    ) async {
      await _pump(
        tester,
        GrowthV5Routes.topic(Subject.math, 't4'),
        topics: [
          topic(
            't4',
            'Foizlar',
            mastery: TopicMastery.practice,
            inProgress: (id: 'a1', answered: 4, total: 10),
          ),
        ],
      );

      expect(find.text('Davom ettirish (4/10)'), findsOneWidget);
    });

    testWidgets('savollari yetarli bo\'lmagan mavzu boshlanmaydi', (
      tester,
    ) async {
      await _pump(tester, GrowthV5Routes.topic(Subject.math, 't5'));

      expect(
        find.text('Bu mavzuda savollar tez orada qoʻshiladi.'),
        findsOneWidget,
      );
      expect(find.text('Boshlash'), findsNothing);
    });
  });
}
