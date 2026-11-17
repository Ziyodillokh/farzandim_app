// Daily Learning testlari uchun umumiy yasovchilar.

import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';

TestResult result(
  Subject subject,
  int correct,
  DateTime date, {
  int total = 10,
  String? id,
  bool isDaily = true,
}) => TestResult(
  id: id ?? '${subject.name}-${date.toIso8601String()}',
  subject: subject,
  topic: LocalizedText.same('Mavzu'),
  correct: correct,
  total: total,
  date: date,
  isDaily: isDaily,
);

QuizQuestion question(
  String id, {
  int difficulty = 1,
  String topic = 'Mavzu',
}) => QuizQuestion(
  id: id,
  difficulty: difficulty,
  topic: LocalizedText.same(topic),
  prompt: LocalizedText.same('Savol $id'),
  options: [for (var i = 0; i < 4; i++) LocalizedText.same('$id-$i')],
);

AnswerFeedback feedback(
  String questionId, {
  required int selected,
  int correct = 0,
}) => AnswerFeedback(
  questionId: questionId,
  selectedIndex: selected,
  isCorrect: selected == correct,
  correctIndex: correct,
  explanation: LocalizedText.same('Izoh $questionId'),
);
