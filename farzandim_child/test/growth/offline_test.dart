// U10 · Oflayn to'plam: saqlash/o'qish, oflayn mashq navbatga tushadi,
// yuborish natijalari (qabul, rad, keyinroq) va ekran oqimi.

import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/oflayn/offline_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/learning/fake_learning_repository.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

Map<String, Object?> _text(String v) => {'uz': v, 'ru': v, 'en': v};

Map<String, Object?> _packJson() => {
  'packId': 'p1',
  'version': 1,
  'issuedAt': DateTime.now().toUtc().toIso8601String(),
  'expiresAt': DateTime.now()
      .add(const Duration(days: 7))
      .toUtc()
      .toIso8601String(),
  'sets': [
    {
      'subject': 'math',
      'signature': 'a' * 64,
      'questions': [
        for (var i = 0; i < 2; i++)
          {
            'id': 'q$i',
            'prompt': _text('$i + 1 = ?'),
            'options': [_text('${i + 1}'), _text('${i + 5}')],
            'correctIndex': 0,
            'explanation': _text('izoh'),
          },
      ],
    },
  ],
};

class _FakeOffline implements OfflineRepository {
  _FakeOffline(this.outcome);

  UploadOutcome outcome;
  final uploaded = <String>[];

  @override
  Future<OfflinePack?> download() async => OfflinePack.tryFromJson(_packJson());

  @override
  Future<(UploadOutcome, int?)> upload(OfflineAttempt attempt) async {
    uploaded.add(attempt.id);
    return (outcome, outcome == UploadOutcome.accepted ? 10 : null);
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

  test('to\'plam: JSON orqali saqlanadi va qayta o\'qiladi', () {
    final pack = OfflinePack.tryFromJson(_packJson())!;
    final again = OfflinePack.tryFromJson(pack.toJson())!;
    expect(again.packId, 'p1');
    expect(again.sets.single.questions.length, 2);
    expect(again.sets.single.questions.first.explanation?.of('uz'), 'izoh');
    expect(pack.isExpired(DateTime.now()), isFalse);
  });

  test('oflayn mashq navbatga tushadi; yuborish natijalari', () async {
    final repo = _FakeOffline(UploadOutcome.retryLater);
    final container = ProviderContainer(
      overrides: [
        ...g5Overrides(learning: FakeLearningRepository(clock: () => kG5Now)),
        offlineRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(offlineProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(offlineProvider.future);
    final notifier = container.read(offlineProvider.notifier);

    await notifier.download();
    final pack = container.read(offlineProvider).value!.pack!;
    final attempt = await notifier.record(
      pack: pack,
      set: pack.sets.single,
      answers: {'q0': 0, 'q1': 1},
    );
    expect(attempt.correct, 1);
    expect(attempt.toUpload()['questionIds'], ['q0', 'q1']);

    await notifier.sync();
    expect(container.read(offlineProvider).value!.pending, hasLength(1));

    repo.outcome = UploadOutcome.accepted;
    await notifier.sync();
    final state = container.read(offlineProvider).value!;
    expect(state.pending, isEmpty);
    expect(state.queue.single.state, OfflineUploadState.accepted);
    expect(state.queue.single.don, 10);
    expect(repo.uploaded, [attempt.id, attempt.id]);
  });

  testWidgets('U10: yuklab olish → oflayn mashq → navbatda', (tester) async {
    final repo = _FakeOffline(UploadOutcome.retryLater);
    await pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: GrowthV5Routes.offline,
      overrides: [
        ...g5Overrides(learning: FakeLearningRepository(clock: () => kG5Now)),
        offlineRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.tap(find.text('Yuklab olish'));
    await settleG5(tester);
    expect(find.text('Qurilmada saqlandi'), findsOneWidget);

    await tester.tap(find.text('Matematika'));
    await settleG5(tester);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('${i + 1}'));
      await tester.pump();
      await tester.tap(find.text('Tekshirish'));
      await tester.pump();
      expect(find.textContaining('Toʻgʻri!'), findsOneWidget);
      await tester.tap(
        find.text(i == 0 ? 'Keyingi savol' : 'Natijani koʻrish'),
      );
      await settleG5(tester);
    }
    expect(find.text('2 tadan 2 ta toʻgʻri'), findsOneWidget);

    await tester.tap(find.text('Toʻplamga qaytish'));
    await settleG5(tester);
    expect(find.text('Kutilmoqda'), findsOneWidget);
  });
}
