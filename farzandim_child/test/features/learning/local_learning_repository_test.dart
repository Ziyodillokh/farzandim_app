// Lokal manba: profil va natijalar saqlanadi/tiklanadi, savollar bankdan.

import 'dart:convert';

import 'package:farzandim_child/features/learning/data/local_learning_repository.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'learning_fixtures.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);

  final Map<String, String> files;
  int loads = 0;

  @override
  Future<ByteData> load(String key) async {
    loads++;
    final text = files[key];
    if (text == null) throw FlutterError('topilmadi: $key');
    return ByteData.sublistView(utf8.encode(text));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final data = await load(key);
    return utf8.decode(data.buffer.asUint8List());
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('profil saqlanadi va tiklanadi; buzilgan qiymat — null', () async {
    final repo = LocalLearningRepository(bundle: _FakeBundle({}));
    expect(await repo.loadProfile(), isNull);

    await repo.saveProfile(
      const LearningProfile(grade: 6, subjects: [Subject.physics]),
    );
    final restored = await repo.loadProfile();
    expect(restored?.grade, 6);
    expect(restored?.subjects, [Subject.physics]);

    SharedPreferences.setMockInitialValues({kLearningProfileKey: '{oops'});
    expect(await repo.loadProfile(), isNull);
  });

  test('noto\'g\'ri profil saqlanmaydi', () async {
    final repo = LocalLearningRepository(bundle: _FakeBundle({}));
    expect(
      () => repo.saveProfile(const LearningProfile(grade: 7, subjects: [])),
      throwsArgumentError,
    );
  });

  test('natijalar yangisi birinchi, id takrorlanmaydi', () async {
    final repo = LocalLearningRepository(bundle: _FakeBundle({}));
    await repo.saveResult(
      result(Subject.math, 5, DateTime(2026, 10, 14), id: 'a'),
    );
    await repo.saveResult(
      result(Subject.math, 8, DateTime(2026, 10, 15), id: 'b'),
    );
    await repo.saveResult(
      result(Subject.math, 9, DateTime(2026, 10, 15, 1), id: 'a'),
    );

    final results = await repo.loadResults();
    expect(results.map((r) => (r.id, r.correct)), [('a', 9), ('b', 8)]);
  });

  test('buzilgan natijalar ro\'yxati — bo\'sh', () async {
    SharedPreferences.setMockInitialValues({kLearningResultsKey: 'nope'});
    final repo = LocalLearningRepository(bundle: _FakeBundle({}));
    expect(await repo.loadResults(), isEmpty);
  });

  test(
    'savollar bankdan o\'qiladi va keshlanadi; bank yo\'q — bo\'sh',
    () async {
      final bundle = _FakeBundle({
        'assets/learning/questions/math.json': jsonEncode({
          'subject': 'math',
          'questions': [
            {
              'id': 'math-01',
              'difficulty': 1,
              'grades': [5, 9],
              'topic': 'Kasrlar',
              'question': '1 + 1 = ?',
              'options': ['1', '2', '3', '4'],
              'answer': 1,
              'explanation': '1 + 1 = 2',
            },
          ],
        }),
      });
      final repo = LocalLearningRepository(bundle: bundle);

      final questions = await repo.loadQuestions(Subject.math);
      expect(
        questions.single.options[questions.single.answerIndex].of('en'),
        '2',
      );
      await repo.loadQuestions(Subject.math);
      expect(bundle.loads, 1);

      expect(await repo.loadQuestions(Subject.history), isEmpty);
    },
  );
}
