import 'package:farzandim_child/features/contests/data/models/quiz_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("savollar bo'sh bo'lsa namunaviy savollarga tushilmaydi", () {
    const state = QuizState(status: QuizStatus.error);
    expect(state.effectiveQuestions, isEmpty);
    expect(state.status, QuizStatus.error);
  });

  test('copyWith error holatini saqlaydi', () {
    final state = const QuizState().copyWith(status: QuizStatus.error);
    expect(state.status, QuizStatus.error);
    expect(state.attemptId, isNull);
  });
}
