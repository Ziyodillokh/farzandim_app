// Psixologik test sessiyasi — sof (immutable) holat mashinasi. Oqim maktab
// panelidagi telefon ko'rinishi (`phone-runner.tsx`) bilan bir xil:
// kirish → (stimul: "Eslab qoling!" + soniyalar) → savol → … → yakun.
//
//   • Faqat oldinga: oldingi savolga yoki stimulga qaytish yo'q.
//   • "Keyingi" javob tanlanmaguncha yopiq; MULTI'da bo'sh tanlov ham javob
//     (`[]` — "hech biri mos emas").
//   • Vaqt chegarasi bo'lsa — "Boshlash"dan teskari sanoq; vaqt tugasa test
//     yakunlanadi va shu paytgacha belgilangan javoblar yuboriladi.
//   • Javoblar faqat xotirada (hech qayerga saqlanmaydi).
//
// Joriy vaqt tashqaridan beriladi (`now`) — testlarda soxta soat.

import 'package:farzandim_child/features/school/domain/psych_answer.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';

/// Test yechish bosqichi.
enum PsychStage {
  /// Test haqida ma'lumot va "Boshlash" (vaqt hali ketmaydi).
  intro,

  /// Savoldan oldin eslab qolinadigan matn — teskari sanoq.
  stimulus,

  /// Savol va javob variantlari.
  question,

  /// Savollar tugadi yoki vaqt tugadi — javoblar yuboriladi.
  finished,
}

class PsychSession {
  const PsychSession._({
    required this.test,
    required this.stage,
    required this.index,
    required this.answers,
    this.startedAt,
    this.stimulusEndsAt,
    this.finishedAt,
    this.isTimedOut = false,
  });

  /// Kirish bosqichi: test haqida, vaqt hali boshlanmagan.
  factory PsychSession.intro(PsychTest test) => PsychSession._(
    test: test,
    stage: PsychStage.intro,
    index: 0,
    answers: const {},
  );

  final PsychTest test;
  final PsychStage stage;

  /// Joriy savol tartibi (0 dan).
  final int index;

  /// Savol id → javob (faqat xotirada).
  final Map<String, PsychAnswer> answers;

  /// "Boshlash" bosilgan lahza — vaqt chegarasi va davomiylik shundan.
  final DateTime? startedAt;

  /// Stimul ko'rsatilishi tugaydigan lahza.
  final DateTime? stimulusEndsAt;

  /// Test yakunlangan lahza.
  final DateTime? finishedAt;

  /// Vaqt tugagani uchun yakunlandi.
  final bool isTimedOut;

  PsychItem get current => test.items[index];
  int get total => test.items.length;
  bool get isLast => index >= total - 1;
  PsychAnswer? get currentAnswer => answers[current.id];
  bool get hasAnswers => answers.isNotEmpty;

  /// Vaqt ketyapti: stimul yoki savol ko'rsatilmoqda.
  bool get isRunning =>
      stage == PsychStage.stimulus || stage == PsychStage.question;

  /// "Keyingi" bosiladimi: savol bosqichida va javob tanlangan (MULTI —
  /// har doim, bo'sh tanlov ham javob).
  bool get canAdvance =>
      stage == PsychStage.question &&
      (current is PsychMultiItem || currentAnswer != null);

  /// Progress 0..1 (panel bilan bir xil: stimulda yarim qadam).
  double get progress => switch (stage) {
    PsychStage.intro => 0,
    PsychStage.stimulus => (index + 0.5) / total,
    PsychStage.question => (index + 1) / total,
    PsychStage.finished => 1,
  };

  /// Vaqt chegarasi (`null` — cheklanmagan).
  Duration? get timeLimit {
    final minutes = test.timeLimitMin;
    return minutes == null ? null : Duration(minutes: minutes);
  }

  /// Vaqt tugaydigan lahza (boshlangandan keyin, chegara bo'lsa).
  DateTime? get deadline {
    final start = startedAt;
    final limit = timeLimit;
    return start == null || limit == null ? null : start.add(limit);
  }

  /// Qolgan vaqt (`null` — cheklanmagan yoki hali boshlanmagan).
  Duration? remaining(DateTime now) {
    final end = deadline;
    if (end == null) return null;
    final left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Vaqt tugadi (test hali yakunlanmagan bo'lsa).
  bool isTimeUp(DateTime now) {
    final end = deadline;
    return isRunning && end != null && !now.isBefore(end);
  }

  /// Stimulning qolgan soniyalari (yuqoriga yaxlitlangan; 0 — tugadi).
  int stimulusSecondsLeft(DateTime now) {
    final end = stimulusEndsAt;
    if (stage != PsychStage.stimulus || end == null) return 0;
    final ms = end.difference(now).inMilliseconds;
    return ms <= 0 ? 0 : (ms + 999) ~/ 1000;
  }

  /// Stimul vaqti tugadi — savol ko'rsatiladi.
  bool isStimulusOver(DateTime now) =>
      stage == PsychStage.stimulus && stimulusSecondsLeft(now) == 0;

  /// Yechish davomiyligi (soniya) — yakunlangandan keyin.
  int? get durationSec {
    final start = startedAt;
    final end = finishedAt;
    if (start == null || end == null) return null;
    final seconds = end.difference(start).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  /// "Boshlash" — vaqt ketadi, birinchi savol (yoki uning stimuli).
  PsychSession begin(DateTime now) {
    if (stage != PsychStage.intro) return this;
    return _open(0, now, startedAt: now);
  }

  /// Stimuldan savolga (vaqt tugadi yoki bola o'zi o'tdi).
  PsychSession showQuestion() {
    if (stage != PsychStage.stimulus) return this;
    return PsychSession._(
      test: test,
      stage: PsychStage.question,
      index: index,
      answers: answers,
      startedAt: startedAt,
    );
  }

  /// Variant: SINGLE — tanlash, MULTI — qo'shish / olib tashlash.
  PsychSession choose(String key) {
    if (stage != PsychStage.question) return this;
    final item = current;
    final PsychAnswer answer;
    switch (item) {
      case PsychSingleItem():
        answer = PsychSingleAnswer(key);
      case PsychMultiItem(:final options):
        if (!options.any((option) => option.key == key)) return this;
        final picked = switch (currentAnswer) {
          PsychMultiAnswer(:final keys) => keys.toSet(),
          _ => const <String>{},
        };
        final toggled = picked.contains(key)
            ? picked.difference({key})
            : picked.union({key});
        // Variantlar tartibida (bosilgan tartibdan qat'i nazar).
        answer = PsychMultiAnswer([
          for (final option in options)
            if (toggled.contains(option.key)) option.key,
        ]);
      case PsychLikertItem():
        return this;
    }
    return answer.fits(item) ? _answer(answer) : this;
  }

  /// LIKERT bahosi (1..5).
  PsychSession rate(int value) {
    if (stage != PsychStage.question) return this;
    final answer = PsychLikertAnswer(value);
    return answer.fits(current) ? _answer(answer) : this;
  }

  /// Keyingi savol yoki yakun. MULTI'da hech narsa tanlanmagan bo'lsa —
  /// bo'sh javob ("hech biri") yoziladi.
  PsychSession next(DateTime now) {
    if (!canAdvance) return this;
    final answered = currentAnswer == null
        ? _answer(PsychMultiAnswer(const []))
        : this;
    if (isLast) return answered._finish(now);
    return answered._open(index + 1, now);
  }

  /// Vaqt tugadi — test yakunlanadi; davomiylik — vaqt chegarasi.
  PsychSession timeUp(DateTime now) {
    final end = deadline;
    if (!isRunning || end == null || now.isBefore(end)) return this;
    return _finish(end, isTimedOut: true);
  }

  PsychSession _open(int at, DateTime now, {DateTime? startedAt}) {
    final item = test.items[at];
    final stimulus = item is PsychSingleItem ? item.stimulus : null;
    return PsychSession._(
      test: test,
      stage: stimulus == null ? PsychStage.question : PsychStage.stimulus,
      index: at,
      answers: answers,
      startedAt: startedAt ?? this.startedAt,
      stimulusEndsAt: stimulus == null
          ? null
          : now.add(Duration(seconds: stimulus.showSec)),
    );
  }

  PsychSession _answer(PsychAnswer answer) => PsychSession._(
    test: test,
    stage: stage,
    index: index,
    answers: Map.unmodifiable({...answers, current.id: answer}),
    startedAt: startedAt,
    stimulusEndsAt: stimulusEndsAt,
  );

  PsychSession _finish(DateTime at, {bool isTimedOut = false}) =>
      PsychSession._(
        test: test,
        stage: PsychStage.finished,
        index: index,
        answers: answers,
        startedAt: startedAt,
        finishedAt: at,
        isTimedOut: isTimedOut,
      );
}
