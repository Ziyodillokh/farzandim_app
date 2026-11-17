// ─────────────────────────────────────────────────────────────────────
// KelajakSessionScreen — Kelajak testi (`/kelajak/session`, extra: tur)
// ─────────────────────────────────────────────────────────────────────
//
// Bugungi sessiya serverdan (`kelajakSessionProvider`): qayta ochilganda /
// ilova qayta ishga tushganda o'sha sessiya javoblari bilan, birinchi
// javobsiz savoldan davom etadi. Savollar bittadan; "Orqaga" javoblarni
// saqlaydi; majburiy savolda javobsiz "Keyingi" yopiq, ixtiyoriysida
// "O'tkazib yuborish". Ochiq matn "Keyingi" / "Orqaga" / chiqishda
// saqlanadi. Yakunlangach shu sahifada "Bugungi natijangiz". Yosh
// kiritilmagan bo'lsa — mavjud profil sahifasiga yo'naltirish.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_insights.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_run_state.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_session.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_display.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_navigation.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_session_provider.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_state_views.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/result/kelajak_result_view.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/session/kelajak_bottom_bar.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/session/kelajak_leave_dialog.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/session/kelajak_question_view.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/session/kelajak_top_bar.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_body.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_message_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

/// Natija kelmagan yakunlangan sessiya uchun (bo'sh bo'limlar).
const _emptyResult = KelajakResult(
  answered: 0,
  total: 0,
  categories: [],
  insights: KelajakInsights.empty,
);

/// Javobsiz o'tish mumkin: ixtiyoriy yoki javob berib bo'lmaydigan savol.
bool _isOptional(KelajakQuestion q) =>
    !(q.isRequired && (q.isChoice || q.isText));

class KelajakSessionScreen extends ConsumerStatefulWidget {
  const KelajakSessionScreen({super.key, required this.type});

  /// Test turi (`daily`, `career` …).
  final String type;

  @override
  ConsumerState<KelajakSessionScreen> createState() =>
      _KelajakSessionScreenState();
}

class _KelajakSessionScreenState extends ConsumerState<KelajakSessionScreen> {
  /// Ochiq savollar matni (savol id → maydon); "Orqaga"da ham saqlanadi.
  final _texts = <String, TextEditingController>{};

  AutoDisposeFamilyAsyncNotifierProvider<
    KelajakSessionNotifier,
    KelajakRunState,
    String
  >
  get _provider => kelajakSessionProvider(widget.type);

  KelajakSessionNotifier get _notifier => ref.read(_provider.notifier);

  KelajakRunState? get _current => ref.read(_provider).valueOrNull;

  @override
  void dispose() {
    for (final controller in _texts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _textFor(KelajakRunState s, KelajakQuestion q) =>
      _texts.putIfAbsent(q.id, () {
        final controller = TextEditingController(
          text: s.answerFor(q.id)?.text ?? '',
        );
        // "Keyingi" holati va chiqish tasdig'i yozilgan matnga bog'liq.
        controller.addListener(() {
          if (mounted) setState(() {});
        });
        return controller;
      });

  String? _typedText(KelajakQuestion q) => q.isText ? _texts[q.id]?.text : null;

  bool _isAnswered(KelajakRunState s) => s.current.isText
      ? (_typedText(s.current) ?? '').trim().isNotEmpty
      : s.currentAnswer != null;

  /// Saqlangan yoki yozilgan javob bor (chiqishda tasdiq so'raladi).
  bool _hasProgress(KelajakRunState s) =>
      s.isOpen &&
      (s.answeredCount > 0 ||
          _texts.values.any((c) => c.text.trim().isNotEmpty));

  /// Joriy ochiq savol matnini saqlash (o'zgarmagan bo'lsa — so'rov yo'q).
  Future<void> _saveText(KelajakRunState s) async {
    final text = _typedText(s.current);
    if (text == null || !s.isEditable) return;
    await _notifier.saveText(s.current.id, text);
  }

  void _select(int value) {
    final s = _current;
    if (s == null) return;
    HapticFeedback.selectionClick();
    unawaited(_notifier.select(s.current.id, value));
  }

  void _next(KelajakRunState s) {
    if (s.isLast) {
      unawaited(_finish());
      return;
    }
    unawaited(_saveText(s));
    _notifier
      ..clearError()
      ..next();
  }

  void _back(KelajakRunState s) {
    unawaited(_saveText(s));
    _notifier
      ..clearError()
      ..back();
  }

  /// Ixtiyoriy savolni javobsiz o'tish (o'chirilgan matn ham saqlanadi).
  void _skip(KelajakRunState s) {
    HapticFeedback.selectionClick();
    unawaited(_saveText(s));
    _notifier
      ..clearError()
      ..next();
  }

  Future<void> _finish() async {
    final s = _current;
    if (s == null) return;
    await _saveText(s);
    final latest = _current;
    if (!mounted || latest == null) return;
    final missing = latest.missingRequired;
    if (missing.isNotEmpty) {
      HapticFeedback.heavyImpact();
      _notifier.goTo(missing.first);
      return;
    }
    HapticFeedback.mediumImpact();
    await _notifier.complete();
  }

  Future<void> _close() async {
    final s = _current;
    if (s != null && _hasProgress(s)) {
      if (!await confirmKelajakLeave(context)) return;
      unawaited(_saveText(s));
    }
    if (mounted) closeKelajakPage(context);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_provider);
    final s = async.valueOrNull;
    final running = s != null && s.isOpen;
    return PopScope(
      canPop: s == null || !_hasProgress(s),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: HomeColors.bg,
        body: DesignScale(
          child: Builder(
            builder: (context) => Padding(
              padding: EdgeInsets.only(top: growthTopInset(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: KelajakTopBar(
                      title:
                          s?.session.title?.inLocale(context) ??
                          'kelajak.title'.tr(),
                      onClose: _close,
                      current: running ? s.index : null,
                      answered: running
                          ? [
                              for (final q in s.questions)
                                s.answers.containsKey(q.id),
                            ]
                          : const [],
                    ),
                  ),
                  Expanded(child: _body(async)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(AsyncValue<KelajakRunState> async) {
    final s = async.valueOrNull;
    if (s != null) {
      if (s.isCompleted) return _result(s);
      if (!s.isOpen) return _closed();
      return _running(s);
    }
    if (async.isLoading) return const QuizStatus(loading: true);
    final code = kelajakCodeOf(async.error);
    final Widget view = switch (code) {
      KelajakErrorCode.ageRequired => const KelajakAgeRequiredView(),
      KelajakErrorCode.ageOutOfRange => KelajakOutOfRangeView(onClose: _close),
      _ => KelajakErrorView(
        code: code,
        onRetry: () => ref.invalidate(_provider),
        onClose: _close,
      ),
    };
    return Center(child: SingleChildScrollView(child: view));
  }

  Widget _running(KelajakRunState s) {
    final q = s.current;
    final optional = _isOptional(q);
    final answered = _isAnswered(s);
    final canFinish = answered || (optional && s.answers.isNotEmpty);
    final enabled = s.isLast ? canFinish : answered;
    final error = s.error;
    String? hint;
    if (!answered && !optional) {
      hint = 'kelajak.session.chooseHint'.tr();
    } else if (s.isLast && !canFinish) {
      hint = 'kelajak.session.needOneAnswer'.tr();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: KelajakQuestionView(
            question: q,
            answer: s.currentAnswer,
            isOptional: optional,
            enabled: s.isEditable,
            onSelect: _select,
            textController: q.isText ? _textFor(s, q) : null,
          ),
        ),
        KelajakBottomBar(
          primaryLabel:
              (s.isLast ? 'kelajak.session.finish' : 'kelajak.session.next')
                  .tr(),
          onPrimary: enabled ? () => _next(s) : null,
          busy: s.isCompleting || (s.isLast && s.isSaving),
          onBack: s.canGoBack ? () => _back(s) : null,
          onSkip: optional && !answered && !s.isLast && s.isEditable
              ? () => _skip(s)
              : null,
          hint: hint,
          error: error == null ? null : kelajakErrorKey(error.code).tr(),
          onDismissError: _notifier.clearError,
        ),
      ],
    );
  }

  Widget _result(KelajakRunState s) {
    return KelajakResultView(
      result: s.result ?? _emptyResult,
      testType: s.type,
      onOpenTest: (type) =>
          context.pushReplacement(KelajakRoutes.session, extra: type),
      onHub: () => returnToKelajakHub(context),
      onHome: () => context.go(KelajakRoutes.home),
    );
  }

  /// Sessiya yopilgan (o'tgan kunga tegishli) — bugungisini ochish.
  Widget _closed() {
    return Center(
      child: SingleChildScrollView(
        child: SchoolMessageView(
          icon: SolarIconsOutline.calendarMark,
          iconColor: HomeColors.blue,
          title: 'kelajak.session.closedTitle'.tr(),
          message: 'kelajak.session.closedBody'.tr(),
          actionLabel: 'kelajak.session.reload'.tr(),
          onAction: () => unawaited(_notifier.refresh()),
        ),
      ),
    );
  }
}
