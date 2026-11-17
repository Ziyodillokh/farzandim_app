// U04 savol → U06 tushuntirish → … → U08 natija; chiqishda U07 tasdig'i.
//
// Urinish serverdan (`quizAttemptProvider`): yarim qolgan mashq shu joydan
// davom etadi, javob serverda tekshiriladi, DON yakunda serverda beriladi.
// Holat mashinasi — mavjud `QuizSession` (immutable).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/data/learning_repository.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_session.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/growth/bugun/widgets/today_header.dart';
import 'package:farzandim_child/growth/common/learning_rules.dart';
import 'package:farzandim_child/growth/oqish/practice/kids_practice_parts.dart';
import 'package:farzandim_child/growth/oqish/practice/kids_question_view.dart';
import 'package:farzandim_child/growth/oqish/practice/practice_outcome.dart';
import 'package:farzandim_child/growth/oqish/practice/practice_panels.dart';
import 'package:farzandim_child/growth/oqish/practice/practice_parts.dart';
import 'package:farzandim_child/growth/oqish/practice/practice_result_view.dart';
import 'package:farzandim_child/growth/oqish/practice/unfinished_practice.dart';
import 'package:farzandim_child/growth/oqish/topics/topics_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key, required this.subject, this.topicId});

  final Subject subject;

  /// Mavzu bo'yicha mashq (U03 dan); `null` — fan bo'yicha aralash kunlik mashq.
  final String? topicId;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  QuizSession? _session;
  TestResult? _result;

  /// Natija kelguncha avvalgi (shu fandagi) natija — solishtirish uchun.
  TestResult? _previous;
  var _completing = false;
  var _completeFailed = false;
  String? _checkError;

  LearningRepository get _repository => ref.read(learningRepositoryProvider);

  AutoDisposeFutureProvider<QuizAttempt> get _attemptProvider {
    final topicId = widget.topicId;
    return topicId == null
        ? quizAttemptProvider(widget.subject)
        : topicAttemptProvider((subject: widget.subject, topicId: topicId));
  }

  String get _language => context.locale.languageCode;

  void _start(QuizAttempt attempt) {
    if (_session != null || attempt.questions.isEmpty) return;
    _session = QuizSession.fromAttempt(attempt);
  }

  /// Shu fandagi oxirgi (shu urinishdan oldingi) natija. Natijalar ro'yxati
  /// hali yuklanmagan bo'lsa kutiladi; oflaynda — solishtirishsiz.
  Future<TestResult?> _previousResult(String attemptId) async {
    List<TestResult> results;
    try {
      results = await ref.read(storedResultsProvider.future);
    } on LearningException {
      results = ref.read(learningResultsProvider);
    }
    for (final r in results) {
      if (r.subject == widget.subject && r.id != attemptId) return r;
    }
    return null;
  }

  bool get _hasUnfinishedProgress {
    final s = _session;
    return s != null &&
        _result == null &&
        s.hasProgress &&
        s.phase != QuizPhase.finished;
  }

  void _update(QuizSession next) => setState(() => _session = next);

  void _select(int option) {
    setState(() => _checkError = null);
    _update(_session!.select(option));
  }

  Future<void> _check() async {
    final checking = _session!.startCheck();
    if (identical(checking, _session)) return;
    _update(checking);
    try {
      final feedback = await _repository.submitAnswer(
        attemptId: checking.attemptId,
        questionId: checking.current.id,
        selectedIndex: checking.selectedIndex!,
      );
      if (!mounted) return;
      feedback.isCorrect
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact();
      _update(_session!.applyFeedback(feedback));
      _rememberProgress();
    } on LearningException catch (e) {
      if (!mounted) return;
      _update(_session!.cancelCheck());
      setState(() {
        _checkError =
            (e.code == LearningErrorCode.attemptClosed
                    ? 'g5.practice.attemptClosed'
                    : 'g5.practice.checkFailed')
                .tr();
      });
    }
  }

  Future<void> _next() async {
    if (_completing) return;
    final next = _session!.next();
    _update(next);
    if (next.phase == QuizPhase.finished) await _complete();
  }

  /// Yakunlash (server tomonida idempotent — qayta chaqirish xavfsiz).
  Future<void> _complete() async {
    setState(() {
      _completing = true;
      _completeFailed = false;
    });
    try {
      final attemptId = _session!.attemptId;
      final previous = await _previousResult(attemptId);
      final result = await _repository.completeAttempt(attemptId);
      _previous = previous;
      ref.read(storedResultsProvider.notifier).add(result);
      await ref.read(unfinishedPracticeProvider.notifier).clear();
      ref.invalidate(schoolAssignmentsProvider);
      if (mounted) setState(() => _result = result);
    } on LearningException catch (e) {
      debugPrint('[practice] yakunlanmadi: $e');
      if (mounted) setState(() => _completeFailed = true);
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  String _topicOf(QuizQuestion q) => q.topic.of(_language);

  /// U01 «Davom ettirish» kartasi uchun: nechta javob berilgani (shu kun).
  void _rememberProgress() {
    final s = _session;
    if (s == null) return;
    ref
        .read(unfinishedPracticeProvider.notifier)
        .save(
          UnfinishedPractice(
            subject: widget.subject,
            answered: s.answers.length,
            total: s.total,
            outcomes: s.outcomes,
            day: practiceDayKey(ref.read(learningClockProvider)()),
            topic: _commonTopic(s),
          ),
        );
  }

  String get _contextLine {
    final s = _session;
    final topic = s == null ? '' : _topicOf(s.current);
    return topic.isEmpty
        ? widget.subject.label
        : '${widget.subject.label} · $topic';
  }

  Future<void> _close() async {
    final s = _session;
    if (_hasUnfinishedProgress && s != null) {
      final leave = await confirmPracticeExit(
        context,
        savedAnswers: s.answers.length,
        context0: _contextLine,
      );
      if (!leave || !mounted) return;
      // Spec: «Saqlash va chiqish» → O'qish markazi (U01).
      GrowthLinks.learnTab(context);
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(GrowthV5Routes.today);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attempt = ref.watch(_attemptProvider);
    attempt.whenData(_start);
    final result = _result;
    if (result != null) return _resultView(result);
    return PopScope(
      canPop: !_hasUnfinishedProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: GColors.bg,
        body: _session == null
            ? _statusScreen(attempt)
            : _questionScreen(_session!),
      ),
    );
  }

  /// 1–4-sinf: U05/U20 (katta matn, javob shu ekranda tekshiriladi).
  bool get _isKids => isEarlyGrade(ref.watch(learningProfileProvider)?.grade);

  Widget _questionScreen(QuizSession s) {
    if (_isKids && s.phase != QuizPhase.finished) {
      return KidsQuestionView(
        subject: widget.subject,
        session: s,
        language: _language,
        checkError: _checkError,
        onClose: _close,
        onSelect: _select,
        onCheck: _check,
        onNext: _next,
      );
    }
    final question = s.current;
    final feedback = s.currentFeedback;
    final options = [for (final o in question.options) o.of(_language)];
    final top = PracticeTopBar(
      onClose: _close,
      outcomes: s.outcomes,
      current: s.index + 1,
    );
    final card = QuestionCard(
      subject: widget.subject,
      topic: _topicOf(question),
      prompt: question.prompt.of(_language),
    );
    final optionList = [
      for (var i = 0; i < options.length; i++)
        AnswerOption(
          index: i,
          text: options[i],
          look: optionLookFor(i, s, feedback),
          onTap: s.phase == QuizPhase.answering ? () => _select(i) : null,
        ),
    ];

    if (s.phase == QuizPhase.finished) {
      return GScreen(top: top, children: [_finishingStatus()]);
    }

    if (feedback != null) {
      // U06: savol va variantlar holati, pastda tushuntirish paneli.
      return GScreen(
        top: top,
        panel: ExplanationPanel(
          isCorrect: feedback.isCorrect,
          correctAnswer: options[feedback.correctIndex],
          explanation: feedback.explanation.of(_language),
          actionLabel: (s.isLast ? 'g5.practice.seeResult' : 'g5.practice.next')
              .tr(),
          onAction: _next,
        ),
        children: [card, ...optionList],
      );
    }

    // U04: tanlash va «Tekshirish».
    return GScreen(
      top: top,
      dock: GButton(
        label: 'g5.practice.check'.tr(),
        loading: s.phase == QuizPhase.checking,
        onPressed: s.selectedIndex == null ? null : _check,
      ),
      children: [
        card,
        Semantics(
          label: 'g5.practice.answersLabel'.tr(),
          container: true,
          child: Column(
            children: [
              for (var i = 0; i < optionList.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                optionList[i],
              ],
            ],
          ),
        ),
        if (_checkError != null)
          GNote(
            text: _checkError!,
            kind: GNoteKind.warn,
            icon: GIcons.wifiSlash,
          ),
      ],
    );
  }

  Widget _finishingStatus() {
    if (_completeFailed) {
      return GNote(
        text: 'g5.practice.completeFailed'.tr(),
        kind: GNoteKind.warn,
        icon: GIcons.wifiSlash,
        action: GLink(
          label: 'g5.common.retry'.tr(),
          onPressed: _completing ? null : _complete,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Semantics(
        liveRegion: true,
        child: Text(
          'g5.practice.finishing'.tr(),
          textAlign: TextAlign.center,
          style: GText.caption,
        ),
      ),
    );
  }

  Widget _statusScreen(AsyncValue<QuizAttempt> attempt) {
    final top = Align(
      alignment: Alignment.centerLeft,
      child: GTopBar.close(label: 'g5.common.close'.tr(), onPressed: _close),
    );
    if (attempt.isLoading || attempt.hasValue) {
      return GScreen(
        top: top,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Text(
              'g5.common.loading'.tr(),
              textAlign: TextAlign.center,
              style: GText.caption,
            ),
          ),
        ],
      );
    }
    final error = attempt.error;
    final code = error is LearningException ? error.code : null;
    final note = switch (code) {
      LearningErrorCode.noQuestions => GNote(
        text: 'g5.practice.noQuestions'.tr(),
        icon: GIcons.hourglassMedium,
      ),
      LearningErrorCode.profileRequired => GNote(
        text: 'g5.practice.profileRequired'.tr(),
        action: GLink(
          label: 'g5.practice.chooseSubjects'.tr(),
          onPressed: () => GrowthLinks.learningSetup(context),
        ),
      ),
      LearningErrorCode.subjectNotInGrade => GNote(
        text: 'g5.practice.subjectNotInGrade'.tr(),
        action: GLink(
          label: 'g5.practice.checkGrade'.tr(),
          onPressed: () => GrowthLinks.learningSetup(context),
        ),
      ),
      _ => GNote(
        text: 'g5.practice.loadError'.tr(),
        kind: GNoteKind.warn,
        icon: GIcons.wifiSlash,
        action: GLink(
          label: 'g5.common.retry'.tr(),
          onPressed: () => ref.invalidate(_attemptProvider),
        ),
      ),
    };
    return GScreen(top: top, children: [note]);
  }

  Widget _resultView(TestResult result) {
    final s = _session;
    final answers = <({String topic, bool isCorrect})>[
      if (s != null)
        for (final q in s.questions)
          if (s.feedbackFor(q.id) case final f?)
            (topic: _topicOf(q), isCorrect: f.isCorrect),
    ];
    final previous = _previous;
    final outcome = buildOutcome(
      correct: result.correct,
      total: result.total,
      previous: previous == null
          ? null
          : (correct: previous.correct, total: previous.total),
      answers: answers,
    );
    if (_isKids) {
      return Scaffold(
        backgroundColor: GColors.bg,
        body: KidsResultView(
          result: result,
          name: firstName(ref.read(pairingStateProvider).childName),
          topic: s == null || s.questions.isEmpty ? '' : _commonTopic(s),
          onHome: () => context.go(GrowthV5Routes.today),
        ),
      );
    }
    final plan = ref.read(dailyPlanProvider);
    final nextSubject = plan.nextItem?.subject;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: PracticeResultView(
        result: result,
        outcome: outcome,
        previous: previous,
        topic: s == null || s.questions.isEmpty ? '' : _commonTopic(s),
        onClose: () => context.go(GrowthV5Routes.today),
        onNextPractice: () {
          if (nextSubject != null) {
            context.pushReplacement(GrowthV5Routes.practice(nextSubject));
          } else {
            GrowthLinks.learnTab(context);
          }
        },
        // U02 Bilim xaritasi shu bosqichda quriladi — hozircha O'qish markazi.
        onKnowledgeMap: () => GrowthLinks.learnTab(context),
        onDonHistory: () => context.push('/don-history'),
      ),
    );
  }

  /// Hamma savol bitta mavzudan bo'lsa — o'sha mavzu (aralash mashqda bo'sh).
  String _commonTopic(QuizSession s) {
    final topics = {for (final q in s.questions) _topicOf(q)};
    return topics.length == 1 ? topics.first : '';
  }
}
