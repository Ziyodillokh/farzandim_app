// Kelajak testini yechish holati — sof (immutable) holat mashinasi.
//
//   • Savollar bittadan ko'rsatiladi; "Orqaga" berilgan javoblarni saqlaydi.
//   • Majburiy savolda javobsiz "Keyingi" yopiq; ixtiyoriy savolni
//     (`career_lab_5`, ochiq matn) o'tkazib yuborish mumkin.
//   • Qayta ochilganda (yangilash / ilova qayta ishga tushishi) birinchi
//     javobsiz savoldan, hammasi javob berilgan bo'lsa — oxirgisidan davom
//     etadi.
//   • Yakunlash: barcha majburiy savollar, kamida bitta javob va saqlanayotgan
//     javob qolmagan bo'lsa.
//
// Server bilan ishlash (saqlash, qaytarish, eskirgan javoblar) —
// `KelajakSessionNotifier`da; bu yerda faqat qoidalar.

import 'package:farzandim_child/features/kelajak/domain/kelajak_error.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_insights.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_session.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';

class KelajakRunState {
  const KelajakRunState._({
    required this.session,
    required this.status,
    required this.answers,
    required this.index,
    this.saving = const {},
    this.isCompleting = false,
    this.error,
    this.completedResult,
  });

  /// Server sessiyasidan. [focusQuestionId] berilsa (yangilashda) — o'sha
  /// savolda qoladi, aks holda birinchi javobsiz savoldan davom etadi.
  factory KelajakRunState.fromSession(
    KelajakSession session, {
    String? focusQuestionId,
  }) {
    if (session.questions.isEmpty) {
      throw ArgumentError.value(session.id, 'session', 'savollar bo\'sh');
    }
    final answers = Map<String, KelajakAnswer>.unmodifiable({
      for (final a in session.answers) a.questionId: a,
    });
    final focus = session.questions.indexWhere((q) => q.id == focusQuestionId);
    return KelajakRunState._(
      session: session,
      status: session.status,
      answers: answers,
      index: focus >= 0 ? focus : resumeIndex(session.questions, answers),
    );
  }

  /// Birinchi javobsiz savol; hammasi javob berilgan bo'lsa — oxirgisi.
  static int resumeIndex(
    List<KelajakQuestion> questions,
    Map<String, KelajakAnswer> answers,
  ) {
    final next = questions.indexWhere((q) => !answers.containsKey(q.id));
    return next < 0 ? questions.length - 1 : next;
  }

  /// Ochilgan server sessiyasi (savollar, sarlavha).
  final KelajakSession session;
  final KelajakSessionStatus status;

  /// Savol id → javob (ekrandagi holat; saqlanayotgani ham).
  final Map<String, KelajakAnswer> answers;

  /// Joriy savol tartibi (0 dan).
  final int index;

  /// Javobi serverga yuborilayotgan savollar.
  final Set<String> saving;
  final bool isCompleting;

  /// Oxirgi xato (UI xabar ko'rsatadi).
  final KelajakException? error;

  /// Shu yerda yakunlangan sessiya natijasi.
  final KelajakResult? completedResult;

  String get sessionId => session.id;
  String get type => session.type;
  List<KelajakQuestion> get questions => session.questions;
  KelajakQuestion get current => questions[index];
  KelajakAnswer? get currentAnswer => answers[current.id];
  KelajakAnswer? answerFor(String questionId) => answers[questionId];
  int get total => questions.length;

  /// Ekrandagi tartib raqami (1 dan).
  int get position => index + 1;
  bool get isFirst => index == 0;
  bool get isLast => index == total - 1;
  int get answeredCount => answers.length;
  bool get isOpen => status.isOpen;
  bool get isCompleted => status == KelajakSessionStatus.completed;
  bool get isSaving => saving.isNotEmpty;
  bool isSavingQuestion(String questionId) => saving.contains(questionId);

  /// Javob tanlash / yozish mumkin.
  bool get isEditable => isOpen && !isCompleting;

  /// Yakunlangan sessiya natijasi.
  KelajakResult? get result =>
      isCompleted ? completedResult ?? session.result : null;

  /// Javobsiz majburiy savollar (savol tartibida).
  List<String> get missingRequired => List.unmodifiable([
    for (final q in questions)
      if (_needsAnswer(q) && !answers.containsKey(q.id)) q.id,
  ]);

  /// "Keyingi": majburiy savolga javob berilgan; ixtiyoriysi — har doim.
  bool get canGoNext =>
      !_needsAnswer(current) || answers.containsKey(current.id);
  bool get canGoBack => index > 0;

  bool get canComplete =>
      isEditable && !isSaving && answers.isNotEmpty && missingRequired.isEmpty;

  KelajakRunState next() =>
      canGoNext && !isLast ? _copy(index: index + 1) : this;

  KelajakRunState back() => canGoBack ? _copy(index: index - 1) : this;

  /// Shu savolga o'tish (masalan, javobsiz majburiy savolga).
  KelajakRunState goTo(String questionId) {
    final target = questions.indexWhere((q) => q.id == questionId);
    return target < 0 || target == index ? this : _copy(index: target);
  }

  /// Variant tanlash (faqat shu savol variantlaridan).
  KelajakRunState select(String questionId, int value) {
    final target = question(questionId);
    if (!isEditable ||
        target == null ||
        !target.isChoice ||
        !target.hasOption(value)) {
      return this;
    }
    return _put(KelajakAnswer(questionId: questionId, value: value));
  }

  /// Ochiq javob (bo'shliqlar olib tashlanadi; bo'sh matn — javobni
  /// o'chirish). Chegaradan uzun matn qabul qilinmaydi.
  KelajakRunState writeText(String questionId, String text) {
    final target = question(questionId);
    final value = text.trim();
    if (!isEditable ||
        target == null ||
        !target.isText ||
        value.length > target.textLimit) {
      return this;
    }
    if (value.isEmpty) return clear(questionId);
    return _put(KelajakAnswer(questionId: questionId, text: value));
  }

  /// Javobni olib tashlash.
  KelajakRunState clear(String questionId) {
    if (!isEditable || !answers.containsKey(questionId)) return this;
    return _copy(answers: _without(answers, [questionId]));
  }

  /// Server tasdiqlagan holatga qaytarish ([answer] `null` — javob yo'q).
  /// Sessiya yopilgan bo'lsa ham ishlaydi (saqlanmagan javob qolmasin).
  KelajakRunState restore(String questionId, KelajakAnswer? answer) {
    if (question(questionId) == null) return this;
    if (answer == null) {
      return answers.containsKey(questionId)
          ? _copy(answers: _without(answers, [questionId]))
          : this;
    }
    return answers[questionId] == answer
        ? this
        : _copy(answers: Map.unmodifiable({...answers, questionId: answer}));
  }

  KelajakRunState startSaving(String questionId) =>
      _copy(saving: Set.unmodifiable({...saving, questionId}));

  KelajakRunState finishSaving(String questionId) => saving.contains(questionId)
      ? _copy(saving: Set.unmodifiable({...saving}..remove(questionId)))
      : this;

  /// Server qaytargan sessiya holati (`STARTED` → `IN_PROGRESS`).
  KelajakRunState withStatus(KelajakSessionStatus next) =>
      next == KelajakSessionStatus.unknown || next == status
      ? this
      : _copy(status: next);

  KelajakRunState withError(KelajakException error) =>
      _copy(error: () => error);

  KelajakRunState clearError() =>
      error == null ? this : _copy(error: () => null);

  /// Sessiya serverda yopilgan (`SESSION_CLOSED`) — javob berib bo'lmaydi.
  KelajakRunState close() => isOpen
      ? _copy(status: KelajakSessionStatus.abandoned, isCompleting: false)
      : this;

  /// Yakunlash boshlandi (shartlar bajarilgan bo'lsa).
  KelajakRunState startCompleting() =>
      canComplete ? _copy(isCompleting: true, error: () => null) : this;

  /// Yakunlandi — natija bilan (savollar va tartib o'zgarmaydi).
  KelajakRunState completed(KelajakSession done) => _copy(
    status: done.status,
    isCompleting: false,
    error: () => null,
    completedResult: () => done.result,
  );

  /// Yakunlab bo'lmadi. `unanswered`: server javobsiz degan savollar
  /// ekrandan ham olib tashlanadi (server — haqiqat manbai) va birinchisiga
  /// o'tiladi; `sessionClosed`: sessiya yopiladi.
  KelajakRunState completeFailed(KelajakException failure) {
    final base = _copy(isCompleting: false, error: () => failure);
    if (failure.code == KelajakErrorCode.sessionClosed) return base.close();
    if (failure.code != KelajakErrorCode.unanswered) return base;
    final remaining = failure.remaining.toSet();
    final reconciled = base._copy(
      answers: _without(
        answers,
        questions
            .where((q) => remaining.contains(q.id) && _needsAnswer(q))
            .map((q) => q.id),
      ),
    );
    final missing = reconciled.missingRequired;
    return missing.isEmpty ? reconciled : reconciled.goTo(missing.first);
  }

  /// Sessiya savoli id bo'yicha (`null` — bu sessiyada yo'q).
  KelajakQuestion? question(String questionId) {
    for (final q in questions) {
      if (q.id == questionId) return q;
    }
    return null;
  }

  KelajakRunState _put(KelajakAnswer answer) =>
      answers[answer.questionId] == answer
      ? this
      : _copy(
          answers: Map.unmodifiable({...answers, answer.questionId: answer}),
        );

  /// Javob talab qilinadi: majburiy va javob berib bo'ladigan savol.
  static bool _needsAnswer(KelajakQuestion q) =>
      q.isRequired && (q.isChoice || q.isText);

  static Map<String, KelajakAnswer> _without(
    Map<String, KelajakAnswer> answers,
    Iterable<String> questionIds,
  ) {
    final removed = questionIds.toSet();
    return Map.unmodifiable({
      for (final entry in answers.entries)
        if (!removed.contains(entry.key)) entry.key: entry.value,
    });
  }

  KelajakRunState _copy({
    KelajakSessionStatus? status,
    Map<String, KelajakAnswer>? answers,
    int? index,
    Set<String>? saving,
    bool? isCompleting,
    KelajakException? Function()? error,
    KelajakResult? Function()? completedResult,
  }) => KelajakRunState._(
    session: session,
    status: status ?? this.status,
    answers: answers ?? this.answers,
    index: index ?? this.index,
    saving: saving ?? this.saving,
    isCompleting: isCompleting ?? this.isCompleting,
    error: error != null ? error() : this.error,
    completedResult: completedResult != null
        ? completedResult()
        : this.completedResult,
  );
}
