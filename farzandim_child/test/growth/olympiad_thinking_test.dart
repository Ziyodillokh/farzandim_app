// 7-bosqich: U16 (tafakkur natijasi so'z bilan) va U17–U19 (olimpiada
// musobaqa rejimi: javob darhol saqlanadi, yakunlash va kvitansiya).

import 'package:farzandim_child/features/iq/domain/iq_models.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/olimpiada/olympiad_data.dart';
import 'package:farzandim_child/growth/tafakkur/thinking_result_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/learning/fake_learning_repository.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

final _olympiad = Olympiad(
  id: 'o1',
  title: 'Matematika olimpiadasi',
  subject: 'Matematika',
  phase: OlympiadPhase.active,
  startTime: kG5Now.subtract(const Duration(days: 1)),
  endTime: kG5Now.add(const Duration(days: 5)),
  durationMin: 40,
  questionCount: 2,
);

class _FakeOlympiads implements OlympiadRepository {
  final answered = <String>[];
  var finished = 0;

  @override
  Future<List<Olympiad>> list() async => [_olympiad];

  @override
  Future<OlympiadAttempt> start(String olympiadId) async =>
      OlympiadAttempt(id: 'a1', startedAt: DateTime.now(), finished: false);

  @override
  Future<List<OlympiadQuestion>> questions(String olympiadId) async => const [
    OlympiadQuestion(id: 'q1', text: '2 + 2 = ?', options: ['3', '4', '5']),
    OlympiadQuestion(id: 'q2', text: '3 · 3 = ?', options: ['6', '9', '12']),
  ];

  @override
  Future<void> answer({
    required String attemptId,
    required String questionId,
    required int selectedIndex,
  }) async => answered.add(questionId);

  @override
  Future<OlympiadReceipt> finish(String attemptId, {required int total}) async {
    finished++;
    return OlympiadReceipt(
      saved: answered.length,
      total: total,
      resultsAt: _olympiad.endTime,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(setUpG5WidgetTests);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('tafakkur: so\'z bilan baho; kam savol — ma\'lumot yetarli emas', () {
    IqDomainScore score(int right, int total) =>
        IqDomainScore(kind: IqItemKind.logic, right: right, total: total);
    expect(thinkingLevelOf(score(4, 4)), ThinkingLevel.strong);
    expect(thinkingLevelOf(score(2, 4)), ThinkingLevel.good);
    expect(thinkingLevelOf(score(1, 4)), ThinkingLevel.growing);
    expect(thinkingLevelOf(score(2, 2)), ThinkingLevel.notEnough);
    expect(thinkingLevelOf(null), ThinkingLevel.notEnough);
  });

  test('olimpiada: ro\'yxat elementi va kvitansiya', () {
    final o = Olympiad.tryFromJson({
      'id': 'o1',
      'title': 'Matematika',
      'lifecycle': 'scheduled',
      'startTime': '2026-11-25T05:00:00.000Z',
      'endTime': '2026-11-27T05:00:00.000Z',
      'durationMin': 40,
      'questionCount': 15,
    });
    expect(o?.phase, OlympiadPhase.scheduled);
    final r = OlympiadReceipt.fromJson({
      'answersSaved': 14,
      'questionsTotal': 15,
      'resultsAt': '2026-11-27T05:00:00.000Z',
    }, total: 15);
    expect(r.saved, 14);
    expect(r.resultsAt, isNotNull);
  });

  testWidgets('U18: javoblar saqlanadi, oxirgisidan keyin kvitansiya', (
    tester,
  ) async {
    final repo = _FakeOlympiads();
    await pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: GrowthV5Routes.olympiads,
      overrides: [
        ...g5Overrides(learning: FakeLearningRepository(clock: () => kG5Now)),
        olympiadRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.tap(find.text('Qatnashish'));
    await settleG5(tester);
    expect(find.text('2 + 2 = ?'), findsOneWidget);

    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('Keyingi savol'));
    await settleG5(tester);
    expect(find.text('3 · 3 = ?'), findsOneWidget);

    await tester.tap(find.text('9'));
    await tester.pump();
    await tester.tap(find.text('Keyingi savol'));
    await settleG5(tester);

    expect(repo.answered, ['q1', 'q2']);
    expect(repo.finished, 1);
    expect(find.text('Javoblaring topshirildi'), findsOneWidget);
    expect(find.text('2 tadan 2 ta javob saqlandi'), findsOneWidget);
  });

  testWidgets('U18: erta «Yakunlash» — tasdiqdan keyin', (tester) async {
    final repo = _FakeOlympiads();
    await pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: GrowthV5Routes.olympiads,
      overrides: [
        ...g5Overrides(learning: FakeLearningRepository(clock: () => kG5Now)),
        olympiadRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.tap(find.text('Qatnashish'));
    await settleG5(tester);

    await tester.tap(find.text('Yakunlash'));
    await settleG5(tester);
    expect(find.text('Yakunlaysanmi?'), findsOneWidget);
    await tester.tap(find.text('Yakunlash').last);
    await settleG5(tester);

    expect(repo.finished, 1);
    expect(find.text('2 tadan 0 ta javob saqlandi'), findsOneWidget);
  });
}
