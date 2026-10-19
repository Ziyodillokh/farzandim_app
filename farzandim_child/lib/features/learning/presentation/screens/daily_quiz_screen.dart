// ─────────────────────────────────────────────────────────────────────
// DailyQuizScreen — kunlik test (`/learn/quiz`, extra: Subject)
// ─────────────────────────────────────────────────────────────────────
//
// Urinish serverdan (`quizAttemptProvider`): savollar adaptiv tanlangan,
// yarim qolgan test shu joydan davom etadi. Oqim: variant tanlash →
// "Tekshirish" (server: to'g'ri/xato + izoh) → "Keyingi savol" → yakunda
// server natija va DON'ni hisoblaydi → natija sahifasi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/data/learning_repository.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_session.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/learning/presentation/learning_navigation.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_body.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_result_view.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class DailyQuizScreen extends ConsumerStatefulWidget {
  const DailyQuizScreen({super.key, required this.subject});

  final Subject subject;

  @override
  ConsumerState<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends ConsumerState<DailyQuizScreen> {
  QuizSession? _session;
  TestResult? _result;
  bool _completing = false;
  bool _completeFailed = false;

  LearningRepository get _repository => ref.read(learningRepositoryProvider);

  void _start(QuizAttempt attempt) {
    if (_session != null || attempt.questions.isEmpty) return;
    _session = QuizSession.fromAttempt(attempt);
  }

  /// Javob berilgan, lekin yakunlanmagan test (chiqishda tasdiq so'raladi).
  bool get _hasUnfinishedProgress {
    final s = _session;
    return s != null &&
        _result == null &&
        s.hasProgress &&
        s.phase != QuizPhase.finished;
  }

  void _update(QuizSession next) => setState(() => _session = next);

  void _select(int option) {
    HapticFeedback.selectionClick();
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
      if (feedback.isCorrect) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
      _update(_session!.applyFeedback(feedback));
    } on LearningException catch (e) {
      if (!mounted) return;
      _update(_session!.cancelCheck());
      _snack(
        (e.code == LearningErrorCode.attemptClosed
                ? 'learn.attemptClosed'
                : 'learn.checkFailed')
            .tr(),
      );
    }
  }

  Future<void> _next() async {
    if (_completing) return;
    final next = _session!.next();
    _update(next);
    if (next.phase == QuizPhase.finished) await _complete();
  }

  /// Yakunlash (idempotent — xatodan keyin qayta chaqirish xavfsiz).
  Future<void> _complete() async {
    setState(() {
      _completing = true;
      _completeFailed = false;
    });
    try {
      final result = await _repository.completeAttempt(_session!.attemptId);
      ref.read(storedResultsProvider.notifier).add(result);
      if (mounted) setState(() => _result = result);
    } on LearningException catch (e) {
      debugPrint('[learning] yakunlanmadi: $e');
      if (mounted) setState(() => _completeFailed = true);
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _close() async {
    if (!_hasUnfinishedProgress || await _confirmExit()) {
      if (!mounted) return;
      context.canPop() ? context.pop() : context.go('/dashboard');
    }
  }

  Future<bool> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: HomeColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: HomeColors.cardBorder),
        ),
        title: Text(
          'learn.exitTitle'.tr(),
          style: homeText(18, weight: FontWeight.w800),
        ),
        content: Text(
          'learn.exitBody'.tr(),
          style: homeText(14, color: HomeColors.textDim, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'learn.exitLeave'.tr(),
              style: homeText(
                14.5,
                weight: FontWeight.w600,
                color: HomeColors.textDim,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HomeColors.primary,
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'learn.exitStay'.tr(),
              style: homeText(14.5, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final attempt = ref.watch(quizAttemptProvider(widget.subject));
    attempt.whenData(_start);
    final session = _session;
    final result = _result;

    return PopScope(
      canPop: !_hasUnfinishedProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: HomeColors.bg,
        body: DesignScale(
          child: Builder(
            builder: (context) {
              if (result != null) return QuizResultView(result: result);
              return Padding(
                padding: EdgeInsets.only(top: growthTopInset(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: QuizTopBar(
                        subject: widget.subject,
                        onClose: _close,
                        current: session == null ? null : session.index + 1,
                        total: session?.total,
                        outcomes: session?.outcomes ?? const [],
                      ),
                    ),
                    Expanded(child: _body(attempt, session)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _body(AsyncValue<QuizAttempt> attempt, QuizSession? session) {
    if (session != null && session.phase == QuizPhase.finished) {
      return _completeFailed
          ? QuizStatus(
              message: 'learn.completeFailed'.tr(),
              actionLabel: 'common.retry'.tr(),
              onAction: _complete,
            )
          : QuizStatus(loading: true, message: 'learn.finishing'.tr());
    }
    if (session != null) {
      return QuizBody(
        session: session,
        onSelect: _select,
        onCheck: _check,
        onNext: _next,
      );
    }
    if (attempt.isLoading) return const QuizStatus(loading: true);
    final error = attempt.error;
    final code = error is LearningException ? error.code : null;
    return switch (code) {
      LearningErrorCode.noQuestions => QuizStatus(
        icon: SolarIconsOutline.hourglass,
        message: 'learn.noQuestions'.tr(),
      ),
      LearningErrorCode.profileRequired => QuizStatus(
        icon: SolarIconsOutline.notebookBookmark,
        message: 'learn.profileRequired'.tr(),
        actionLabel: 'learn.setupCtaButton'.tr(),
        onAction: () => context.pushReplacement(LearningRoutes.setup),
      ),
      _ => QuizStatus(
        message: 'learn.loadError'.tr(),
        actionLabel: 'common.retry'.tr(),
        onAction: () => ref.invalidate(quizAttemptProvider(widget.subject)),
      ),
    };
  }
}
