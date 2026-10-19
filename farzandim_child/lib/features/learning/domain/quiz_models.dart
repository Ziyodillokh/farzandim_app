// Kunlik test modellari (server API shakli): savol (to'g'ri javobsiz),
// javob natijasi (to'g'ri javob + izoh), urinish va tahlil.

import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';

/// Bitta test savoli — to'g'ri javob javobdan keyin keladi.
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.difficulty,
    required this.topic,
    required this.prompt,
    required this.options,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final options = json['options'];
    if (json case {
      'id': final String id,
      'difficulty': final int difficulty,
    } when options is List && options.length >= 2) {
      return QuizQuestion(
        id: id,
        difficulty: difficulty,
        topic: LocalizedText.fromJson(json['topic']),
        prompt: LocalizedText.fromJson(json['prompt']),
        options: List.unmodifiable(options.map(LocalizedText.fromJson)),
      );
    }
    throw const FormatException('QuizQuestion: noto\'g\'ri JSON');
  }

  final String id;

  /// 1 — oson, 2 — o'rta, 3 — qiyin.
  final int difficulty;
  final LocalizedText topic;
  final LocalizedText prompt;
  final List<LocalizedText> options;
}

/// Javob natijasi (server tekshirgan).
class AnswerFeedback {
  const AnswerFeedback({
    required this.questionId,
    required this.selectedIndex,
    required this.isCorrect,
    required this.correctIndex,
    required this.explanation,
  });

  factory AnswerFeedback.fromJson(Map<String, dynamic> json) {
    if (json case {
      'questionId': final String questionId,
      'selectedIndex': final int selectedIndex,
      'isCorrect': final bool isCorrect,
      'correctIndex': final int correctIndex,
    }) {
      return AnswerFeedback(
        questionId: questionId,
        selectedIndex: selectedIndex,
        isCorrect: isCorrect,
        correctIndex: correctIndex,
        explanation: LocalizedText.fromJson(json['explanation']),
      );
    }
    throw const FormatException('AnswerFeedback: noto\'g\'ri JSON');
  }

  final String questionId;
  final int selectedIndex;
  final bool isCorrect;
  final int correctIndex;

  /// To'g'ri javob nima uchun to'g'ri.
  final LocalizedText explanation;
}

/// Boshlangan (yoki davom ettirilayotgan) urinish.
class QuizAttempt {
  const QuizAttempt({
    required this.id,
    required this.subject,
    required this.isDaily,
    required this.questions,
    required this.answers,
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    final subject = Subject.fromName(json['subject'] as String?);
    final questions = json['questions'];
    final answers = json['answers'];
    if (json case {
      'id': final String id,
      'isDaily': final bool isDaily,
    } when subject != null && questions is List && answers is List) {
      return QuizAttempt(
        id: id,
        subject: subject,
        isDaily: isDaily,
        questions: List.unmodifiable(
          questions.cast<Map<String, dynamic>>().map(QuizQuestion.fromJson),
        ),
        answers: List.unmodifiable(
          answers.cast<Map<String, dynamic>>().map(AnswerFeedback.fromJson),
        ),
      );
    }
    throw const FormatException('QuizAttempt: noto\'g\'ri JSON');
  }

  final String id;
  final Subject subject;

  /// Fan bo'yicha kunlik birinchi urinish (DON shunga beriladi).
  final bool isDaily;
  final List<QuizQuestion> questions;

  /// Allaqachon berilgan javoblar (davom ettirishda).
  final List<AnswerFeedback> answers;
}

/// Tahlildagi bitta savol.
class ReviewItem {
  const ReviewItem({
    required this.question,
    required this.correctIndex,
    required this.explanation,
    required this.selectedIndex,
    required this.isCorrect,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    final question = json['question'];
    if (question is Map<String, dynamic>) {
      return ReviewItem(
        question: QuizQuestion.fromJson(question),
        correctIndex: question['correctIndex'] as int,
        explanation: LocalizedText.fromJson(question['explanation']),
        selectedIndex: json['selectedIndex'] as int?,
        isCorrect: json['isCorrect'] == true,
      );
    }
    throw const FormatException('ReviewItem: noto\'g\'ri JSON');
  }

  final QuizQuestion question;
  final int correctIndex;
  final LocalizedText explanation;

  /// `null` — javob berilmagan.
  final int? selectedIndex;
  final bool isCorrect;
}

/// Yakunlangan urinish tahlili.
class AttemptReview {
  const AttemptReview({required this.result, required this.items});

  factory AttemptReview.fromJson(Map<String, dynamic> json) {
    final result = TestResult.tryFromJson(json['result']);
    final items = json['items'];
    if (result == null || items is! List) {
      throw const FormatException('AttemptReview: noto\'g\'ri JSON');
    }
    return AttemptReview(
      result: result,
      items: List.unmodifiable(
        items.cast<Map<String, dynamic>>().map(ReviewItem.fromJson),
      ),
    );
  }

  final TestResult result;
  final List<ReviewItem> items;
}
