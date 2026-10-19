// Kunlik test sessiyasi — sof (immutable) holat mashinasi:
// javob tanlash → tekshirish (server) → natija + izoh → keyingi → yakun.
// Javoblar serverda saqlanadi: yarim qolgan test keyin shu joydan davom
// ettiriladi (`QuizSession.fromAttempt`).

import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';

enum QuizPhase {
  /// Javob tanlanmoqda.
  answering,

  /// Javob serverga yuborildi — natija kutilmoqda.
  checking,

  /// Natija keldi — to'g'ri javob va izoh ko'rsatiladi.
  checked,

  /// Barcha savollar tugadi.
  finished,
}

class QuizSession {
  const QuizSession._({
    required this.attemptId,
    required this.subject,
    required this.isDaily,
    required this.questions,
    required this.index,
    required this.selectedIndex,
    required this.answers,
    required this.phase,
  });

  /// Server urinishidan: javob berilganlari o'tkaziladi, hammasi javob
  /// berilgan bo'lsa — oxirgi savol natijasi bilan (yakunlashga tayyor).
  factory QuizSession.fromAttempt(QuizAttempt attempt) {
    if (attempt.questions.isEmpty) {
      throw ArgumentError.value(attempt, 'attempt', 'savollar bo\'sh');
    }
    final answered = {for (final a in attempt.answers) a.questionId};
    final next = attempt.questions.indexWhere((q) => !answered.contains(q.id));
    final allAnswered = next < 0;
    return QuizSession._(
      attemptId: attempt.id,
      subject: attempt.subject,
      isDaily: attempt.isDaily,
      questions: attempt.questions,
      index: allAnswered ? attempt.questions.length - 1 : next,
      selectedIndex: null,
      answers: attempt.answers,
      phase: allAnswered ? QuizPhase.checked : QuizPhase.answering,
    );
  }

  final String attemptId;
  final Subject subject;
  final bool isDaily;
  final List<QuizQuestion> questions;

  /// Joriy savol tartibi (0 dan).
  final int index;

  /// Tanlangan variant (`null` — hali tanlanmagan).
  final int? selectedIndex;

  /// Berilgan javoblar (server natijalari).
  final List<AnswerFeedback> answers;
  final QuizPhase phase;

  QuizQuestion get current => questions[index];
  int get total => questions.length;
  bool get isLast => index == questions.length - 1;
  int get correctCount => answers.where((a) => a.isCorrect).length;
  bool get hasProgress => answers.isNotEmpty;

  /// Joriy savol natijasi (tekshirilgandan keyin).
  AnswerFeedback? get currentFeedback =>
      phase == QuizPhase.checked ? feedbackFor(current.id) : null;

  AnswerFeedback? feedbackFor(String questionId) {
    for (final a in answers) {
      if (a.questionId == questionId) return a;
    }
    return null;
  }

  /// Progress chizig'i uchun: savol tartibida natija (`null` — javobsiz).
  List<bool?> get outcomes => [
    for (final q in questions) feedbackFor(q.id)?.isCorrect,
  ];

  QuizSession _copy({
    int? index,
    int? Function()? selectedIndex,
    List<AnswerFeedback>? answers,
    QuizPhase? phase,
  }) => QuizSession._(
    attemptId: attemptId,
    subject: subject,
    isDaily: isDaily,
    questions: questions,
    index: index ?? this.index,
    selectedIndex: selectedIndex != null ? selectedIndex() : this.selectedIndex,
    answers: answers ?? this.answers,
    phase: phase ?? this.phase,
  );

  /// Variant tanlash — faqat javob berish bosqichida.
  QuizSession select(int option) {
    if (phase != QuizPhase.answering) return this;
    if (option < 0 || option >= current.options.length) return this;
    return _copy(selectedIndex: () => option);
  }

  /// Tekshirish boshlandi (server so'rovi yuborildi).
  QuizSession startCheck() {
    if (phase != QuizPhase.answering || selectedIndex == null) return this;
    return _copy(phase: QuizPhase.checking);
  }

  /// Server javobi — faqat joriy savol uchun.
  QuizSession applyFeedback(AnswerFeedback feedback) {
    if (phase != QuizPhase.checking || feedback.questionId != current.id) {
      return this;
    }
    return _copy(
      answers: List.unmodifiable([...answers, feedback]),
      selectedIndex: () => feedback.selectedIndex,
      phase: QuizPhase.checked,
    );
  }

  /// Tekshirib bo'lmadi (tarmoq) — tanlov saqlanadi, qayta urinish mumkin.
  QuizSession cancelCheck() {
    if (phase != QuizPhase.checking) return this;
    return _copy(phase: QuizPhase.answering);
  }

  /// Keyingi savol yoki yakun.
  QuizSession next() {
    if (phase != QuizPhase.checked) return this;
    if (isLast) return _copy(phase: QuizPhase.finished);
    return _copy(
      index: index + 1,
      selectedIndex: () => null,
      phase: QuizPhase.answering,
    );
  }
}
