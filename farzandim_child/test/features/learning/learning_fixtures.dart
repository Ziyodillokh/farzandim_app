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
  List<QuizAnswer> answers = const [],
}) => TestResult(
  id: id ?? '${subject.name}-${date.toIso8601String()}',
  subject: subject,
  topic: LocalizedText.same('Mavzu'),
  correct: correct,
  total: total,
  date: date,
  answers: answers,
);

QuizQuestion question(
  String id, {
  Subject subject = Subject.math,
  int difficulty = 1,
  int minGrade = 5,
  int maxGrade = 9,
  int answer = 0,
  String topic = 'Mavzu',
}) => QuizQuestion(
  id: id,
  subject: subject,
  difficulty: difficulty,
  minGrade: minGrade,
  maxGrade: maxGrade,
  topic: LocalizedText.same(topic),
  prompt: LocalizedText.same('Savol $id'),
  options: [for (var i = 0; i < 4; i++) LocalizedText.same('$id-$i')],
  answerIndex: answer,
  explanation: LocalizedText.same('Izoh'),
);
