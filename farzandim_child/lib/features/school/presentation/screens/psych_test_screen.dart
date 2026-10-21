// ─────────────────────────────────────────────────────────────────────
// PsychTestScreen — psixologik test (`/school/test`, extra: topshiriq id)
// ─────────────────────────────────────────────────────────────────────
//
// Maktab panelidagi telefon ko'rinishi (`phone-runner.tsx`) bilan bir xil
// oqim: kirish → stimul (bo'lsa) → savol → … → "Rahmat!". Faqat oldinga;
// "Keyingi" javobsiz yopiq (MULTI — bo'sh tanlov ham javob). Vaqt chegarasi
// bo'lsa — teskari sanoq va vaqt tugaganda avtomatik yuborish; har doim
// `durationSec` yuboriladi. Javoblar faqat xotirada: sahifadan chiqilsa
// yo'qoladi (chiqishda tasdiq so'raladi). Server "allaqachon topshirilgan"
// (409) desa — test bajarilgan deb ko'rsatiladi; yopilgan test (404) —
// tushuntirish.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_body.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/setup/setup_widgets.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/domain/psych_session.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/features/school/presentation/psych_display.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/widgets/psych/psych_intro_view.dart';
import 'package:farzandim_child/features/school/presentation/widgets/psych/psych_question_view.dart';
import 'package:farzandim_child/features/school/presentation/widgets/psych/psych_stimulus_view.dart';
import 'package:farzandim_child/features/school/presentation/widgets/psych/psych_top_bar.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_dialogs.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_message_view.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_result_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

/// Teskari sanoq va stimulni tekshirish oralig'i.
const _tickInterval = Duration(milliseconds: 250);

class PsychTestScreen extends ConsumerStatefulWidget {
  const PsychTestScreen({
    super.key,
    required this.assignmentId,
    this.clock = DateTime.now,
  });

  final String assignmentId;

  /// Joriy vaqt (testda — soxta soat).
  final DateTime Function() clock;

  @override
  ConsumerState<PsychTestScreen> createState() => _PsychTestScreenState();
}

/// Testning yakuniy holati.
enum _Outcome {
  /// Javoblar yuborildi.
  sent,

  /// Server: avval topshirilgan (409) — bajarilgan deb ko'rsatiladi.
  alreadySubmitted,

  /// Vaqt tugadi, birorta javob yo'q — hech narsa yuborilmadi.
  timeUpEmpty,

  /// Test yopilgan yoki muddati o'tgan (404).
  closed,
}

SchoolErrorCode _codeOf(Object? error) =>
    error is SchoolException ? error.code : SchoolErrorCode.unknown;

/// Qayta urinish ma'nosiz xatolar (faqat yopish).
bool _isFinal(SchoolErrorCode code) =>
    code == SchoolErrorCode.notEnrolled || code == SchoolErrorCode.validation;

class _PsychTestScreenState extends ConsumerState<PsychTestScreen> {
  /// "Boshlash"dan keyingi holat (`null` — kirish bosqichi).
  PsychSession? _session;
  Timer? _ticker;
  bool _sending = false;
  SchoolErrorCode? _sendError;
  _Outcome? _outcome;

  /// Oxirgi chizilgan sanoq — faqat o'zgarganda qayta chiziladi.
  (String?, int) _shown = (null, 0);

  DateTime get _now => widget.clock();

  /// Yuborilmagan javoblar bor (chiqishda tasdiq so'raladi).
  bool get _hasUnsentAnswers => _session != null && _outcome == null;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _update(PsychSession next) {
    final justFinished =
        next.stage == PsychStage.finished &&
        _session?.stage != PsychStage.finished;
    setState(() => _session = next);
    _syncTicker();
    if (justFinished) unawaited(_submit());
  }

  void _start(PsychTest test) {
    HapticFeedback.selectionClick();
    _update(PsychSession.intro(test).begin(_now));
  }

  void _choose(String key) {
    HapticFeedback.selectionClick();
    _update(_session!.choose(key));
  }

  void _rate(int value) {
    HapticFeedback.selectionClick();
    _update(_session!.rate(value));
  }

  void _next() {
    final session = _session;
    if (session == null || !session.canAdvance) return;
    _update(session.next(_now));
  }

  void _showQuestion() => _update(_session!.showQuestion());

  /// Soat faqat stimulda yoki vaqt chegarasi bo'lganda kerak.
  void _syncTicker() {
    final s = _session;
    final needsTicker =
        s != null &&
        s.isRunning &&
        (s.stage == PsychStage.stimulus || s.deadline != null);
    if (!needsTicker) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(_tickInterval, (_) => _onTick());
  }

  void _onTick() {
    final s = _session;
    if (!mounted || s == null) return;
    final now = _now;
    if (s.isTimeUp(now)) {
      HapticFeedback.heavyImpact();
      _update(s.timeUp(now));
      return;
    }
    if (s.isStimulusOver(now)) {
      _update(s.showQuestion());
      return;
    }
    final remaining = s.remaining(now);
    final shown = (
      remaining == null ? null : formatCountdown(remaining),
      s.stimulusSecondsLeft(now),
    );
    if (shown != _shown) setState(() => _shown = shown);
  }

  Future<void> _submit() async {
    final s = _session;
    if (s == null || s.stage != PsychStage.finished || _sending) return;
    // Sahifa yopilsa ham ro'yxat yangilanadi (bosh sahifa belgisi, Maktabim).
    final container = ProviderScope.containerOf(context, listen: false);
    if (!s.hasAnswers) {
      _complete(_Outcome.timeUpEmpty);
      return;
    }
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      await container
          .read(schoolRepositoryProvider)
          .submitPsychTest(
            s.test,
            answers: s.answers,
            durationSec: s.durationSec,
          );
      container.invalidate(psychAssignmentsProvider);
      _complete(_Outcome.sent);
    } on SchoolException catch (e) {
      final outcome = switch (e.code) {
        SchoolErrorCode.alreadySubmitted => _Outcome.alreadySubmitted,
        SchoolErrorCode.assignmentNotFound => _Outcome.closed,
        _ => null,
      };
      if (outcome != null) {
        container.invalidate(psychAssignmentsProvider);
        _complete(outcome);
      } else {
        _fail(e.code);
      }
    } catch (e, stack) {
      // Kutilmagan xato — "yuborilmoqda"da qotib qolmasin.
      debugPrint('[school] psixologik test: $e\n$stack');
      _fail(SchoolErrorCode.unknown);
    }
  }

  void _complete(_Outcome outcome) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _sending = false;
      _outcome = outcome;
    });
  }

  void _fail(SchoolErrorCode code) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _sending = false;
      _sendError = code;
    });
  }

  Future<void> _close() async {
    // Javoblar yuborilmoqda — natijani kutamiz (bir necha soniya).
    if (_sending) return;
    if (_hasUnsentAnswers &&
        !await confirmSchoolLeave(
          context,
          titleKey: 'school.leave.testTitle',
          bodyKey: 'school.leave.testBody',
        )) {
      return;
    }
    if (mounted) closeSchoolPage(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = psychTestProvider(widget.assignmentId);
    // Yopilgan / topshirilgan test ro'yxatdan ham olib tashlanadi.
    ref.listen(provider, (_, next) {
      final code = next.hasError ? _codeOf(next.error) : null;
      if (code == SchoolErrorCode.alreadySubmitted ||
          code == SchoolErrorCode.assignmentNotFound) {
        ref.invalidate(psychAssignmentsProvider);
      }
    });
    final testState = ref.watch(provider);
    final session = _session;
    final outcome =
        _outcome ?? (session == null ? _loadOutcome(testState) : null);
    if (outcome != null) {
      return _OutcomePage(
        outcome: outcome,
        isTimedOut: session?.isTimedOut ?? false,
        onDone: () => closeSchoolPage(context),
      );
    }
    final test = session?.test ?? testState.valueOrNull;
    final title = test?.title.trim() ?? '';
    final now = _now;

    return PopScope(
      canPop: !_hasUnsentAnswers,
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
                    child: PsychTopBar(
                      title: title.isEmpty ? 'school.psych.title'.tr() : title,
                      onClose: _close,
                      current: session == null ? null : session.index + 1,
                      total: session?.total,
                      progress: session?.progress,
                      remaining: session != null && session.isRunning
                          ? session.remaining(now)
                          : null,
                    ),
                  ),
                  Expanded(
                    child: session == null
                        ? _intro(testState)
                        : _running(session, now),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Yuklash natijasi yakuniy holat bo'lsa (409 — topshirilgan, 404 —
  /// yopilgan).
  static _Outcome? _loadOutcome(AsyncValue<PsychTest> state) {
    if (!state.hasError || state.isLoading) return null;
    return switch (_codeOf(state.error)) {
      SchoolErrorCode.alreadySubmitted => _Outcome.alreadySubmitted,
      SchoolErrorCode.assignmentNotFound => _Outcome.closed,
      _ => null,
    };
  }

  Widget _intro(AsyncValue<PsychTest> testState) {
    final test = testState.valueOrNull;
    if (test != null) {
      return PsychIntroView(test: test, onStart: () => _start(test));
    }
    if (testState.isLoading) return const QuizStatus(loading: true);
    final code = _codeOf(testState.error);
    return _Problem(
      code: code,
      onRetry: _isFinal(code)
          ? null
          : () => ref.invalidate(psychTestProvider(widget.assignmentId)),
      onClose: _close,
    );
  }

  Widget _running(PsychSession session, DateTime now) {
    final item = session.current;
    final stimulus = item is PsychSingleItem ? item.stimulus : null;
    switch (session.stage) {
      case PsychStage.stimulus when stimulus != null:
        return PsychStimulusView(
          text: stimulus.text,
          secondsLeft: session.stimulusSecondsLeft(now),
          onSkip: _showQuestion,
        );
      case PsychStage.intro || PsychStage.stimulus || PsychStage.question:
        return PsychQuestionView(
          session: session,
          onChoose: _choose,
          onRate: _rate,
          onNext: _next,
        );
      case PsychStage.finished:
        final error = _sendError;
        if (error == null) {
          return QuizStatus(
            loading: true,
            message: 'school.psych.sending'.tr(),
          );
        }
        return _Problem(
          code: error,
          titleKey: 'school.psych.sendFailedTitle',
          onRetry: _isFinal(error) ? null : _submit,
          onClose: _close,
        );
    }
  }
}

/// Yuklash / yuborish xatosi: xabar va "Qayta urinish" (yoki "Yopish").
class _Problem extends StatelessWidget {
  const _Problem({
    required this.code,
    required this.onClose,
    this.onRetry,
    this.titleKey,
  });

  final SchoolErrorCode code;
  final VoidCallback onClose;
  final VoidCallback? onRetry;
  final String? titleKey;

  @override
  Widget build(BuildContext context) {
    final onRetry = this.onRetry;
    return Center(
      child: SingleChildScrollView(
        child: SchoolMessageView(
          icon: code == SchoolErrorCode.network
              ? Icons.wifi_off_rounded
              : SolarIconsOutline.dangerCircle,
          title: titleKey?.tr(),
          message: code.messageKey.tr(),
          actionLabel: (onRetry == null ? 'common.close' : 'common.retry').tr(),
          onAction: onRetry ?? onClose,
        ),
      ),
    );
  }
}

/// Yakun: rahmat, allaqachon topshirilgan, vaqt tugadi yoki test yopilgan.
class _OutcomePage extends StatelessWidget {
  const _OutcomePage({
    required this.outcome,
    required this.isTimedOut,
    required this.onDone,
  });

  final _Outcome outcome;
  final bool isTimedOut;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final (icon, color, titleKey, bodyKey) = switch (outcome) {
      _Outcome.sent when isTimedOut => (
        SolarIconsBold.stopwatch,
        HomeColors.green,
        'school.psych.timeUpTitle',
        'school.psych.timeUpBody',
      ),
      _Outcome.sent => (
        Icons.check_rounded,
        HomeColors.green,
        'school.psych.doneTitle',
        'school.psych.doneBody',
      ),
      _Outcome.alreadySubmitted => (
        Icons.check_rounded,
        HomeColors.blue,
        'school.psych.doneTitle',
        'school.errors.alreadySubmitted',
      ),
      _Outcome.timeUpEmpty => (
        SolarIconsBold.hourglass,
        HomeColors.amber,
        'school.psych.timeUpTitle',
        'school.psych.timeUpEmptyBody',
      ),
      _Outcome.closed => (
        SolarIconsBold.calendarMark,
        HomeColors.orange,
        'school.psych.closedTitle',
        'school.errors.assignmentNotFound',
      ),
    };
    return SchoolResultPage(
      key: ValueKey('psych-outcome-${outcome.name}'),
      icon: icon,
      color: color,
      title: titleKey.tr(),
      actions: [SetupButton(label: 'school.psych.done'.tr(), onTap: onDone)],
      children: [SchoolResultNote(bodyKey.tr())],
    );
  }
}
