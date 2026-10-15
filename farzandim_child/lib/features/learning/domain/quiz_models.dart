// Savollar banki modellari — bitta savol (4 variant, to'g'ri javob, izoh).

import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';

/// Savol qiyinligi chegaralari.
const kMinDifficulty = 1;
const kMaxDifficulty = 3;

/// Bitta test savoli.
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.subject,
    required this.difficulty,
    required this.minGrade,
    required this.maxGrade,
    required this.topic,
    required this.prompt,
    required this.options,
    required this.answerIndex,
    required this.explanation,
  });

  /// Bank JSON'idagi bitta yozuv; noto'g'ri bo'lsa [FormatException].
  factory QuizQuestion.fromJson(Subject subject, Object? json) {
    if (json case {
      'id': final String id,
      'difficulty': final int difficulty,
      'grades': [final int minGrade, final int maxGrade],
      'options': final List<Object?> rawOptions,
      'answer': final int answer,
    }) {
      final options = [for (final o in rawOptions) LocalizedText.fromJson(o)];
      if (difficulty < kMinDifficulty ||
          difficulty > kMaxDifficulty ||
          minGrade > maxGrade ||
          options.length < 2 ||
          answer < 0 ||
          answer >= options.length) {
        throw FormatException('QuizQuestion $id: noto\'g\'ri qiymatlar');
      }
      return QuizQuestion(
        id: id,
        subject: subject,
        difficulty: difficulty,
        minGrade: minGrade,
        maxGrade: maxGrade,
        topic: LocalizedText.fromJson(json['topic']),
        prompt: LocalizedText.fromJson(json['question']),
        options: List.unmodifiable(options),
        answerIndex: answer,
        explanation: LocalizedText.fromJson(json['explanation']),
      );
    }
    throw const FormatException('QuizQuestion: maydonlar yetishmaydi');
  }

  final String id;
  final Subject subject;

  /// 1 — oson, 2 — o'rta, 3 — qiyin.
  final int difficulty;

  /// Mos sinflar oralig'i.
  final int minGrade;
  final int maxGrade;

  final LocalizedText topic;
  final LocalizedText prompt;
  final List<LocalizedText> options;
  final int answerIndex;

  /// To'g'ri javob nima uchun to'g'ri — javobdan keyin ko'rsatiladi.
  final LocalizedText explanation;

  bool fitsGrade(int grade) => grade >= minGrade && grade <= maxGrade;

  /// Sinf oralig'idan qancha uzoq (0 — mos).
  int gradeDistance(int grade) {
    if (grade < minGrade) return minGrade - grade;
    if (grade > maxGrade) return grade - maxGrade;
    return 0;
  }
}

/// Fan savollari banki JSON'i (`{"subject": "...", "questions": [...]}`).
List<QuizQuestion> parseQuestionBank(Subject subject, Object? json) {
  if (json case {'questions': final List<Object?> questions}) {
    return [for (final q in questions) QuizQuestion.fromJson(subject, q)];
  }
  throw FormatException('Savollar banki (${subject.name}): noto\'g\'ri JSON');
}
