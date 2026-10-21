// ─────────────────────────────────────────────────────────────────────
// CareSurveyScreen — "Bola ovozi" so'rovnomasi (`/school/survey`)
// ─────────────────────────────────────────────────────────────────────
//
// Maktab psixologi faollashtirgan so'rovnoma (bolaning yosh guruhi, uning
// tilida): har savolga 1–5 shkala bilan javob — hammasi majburiy, keyin
// "Yuborish" (bir marta). Javoblar anonim: maktab faqat kamida 5
// o'quvchilik guruh natijasini ko'radi. Server 409 (allaqachon javob
// berilgan) — javob berilgan deb ko'rsatiladi; 404 — so'rovnoma yakunlangan.
// Javoblar faqat xotirada (chiqishda tasdiq so'raladi).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/setup/setup_widgets.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/school_style.dart';
import 'package:farzandim_child/features/school/presentation/widgets/care/survey_question_card.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_dialogs.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_message_view.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_result_page.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_section.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/inner_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

class CareSurveyScreen extends ConsumerStatefulWidget {
  const CareSurveyScreen({super.key});

  @override
  ConsumerState<CareSurveyScreen> createState() => _CareSurveyScreenState();
}

/// So'rovnomaning yakuniy holati.
enum _Outcome {
  /// Javoblar yuborildi.
  sent,

  /// Server: allaqachon javob berilgan (409).
  alreadyAnswered,

  /// So'rovnoma yakunlangan (404).
  closed,
}

class _CareSurveyScreenState extends ConsumerState<CareSurveyScreen> {
  /// Savol id → baho (1..5), faqat xotirada.
  Map<String, int> _answers = const {};
  bool _sending = false;
  SchoolErrorCode? _sendError;
  _Outcome? _outcome;

  bool get _hasUnsentAnswers => _answers.isNotEmpty && _outcome == null;

  int _answeredCount(CareSurvey survey) =>
      survey.questions.where((q) => _answers.containsKey(q.id)).length;

  void _answer(String questionId, int value) {
    HapticFeedback.selectionClick();
    setState(() {
      _answers = Map.unmodifiable({..._answers, questionId: value});
      _sendError = null;
    });
  }

  Future<void> _submit(CareSurvey survey) async {
    if (_sending || _answeredCount(survey) != survey.questions.length) return;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      await container.read(schoolRepositoryProvider).submitCareSurvey(
        survey.id,
        {for (final q in survey.questions) q.id: _answers[q.id]!},
      );
      container.invalidate(careSurveyProvider);
      _complete(_Outcome.sent);
    } on SchoolException catch (e) {
      final outcome = switch (e.code) {
        SchoolErrorCode.alreadyAnswered => _Outcome.alreadyAnswered,
        SchoolErrorCode.surveyNotFound => _Outcome.closed,
        _ => null,
      };
      if (outcome != null) {
        container.invalidate(careSurveyProvider);
        _complete(outcome);
      } else {
        _fail(e.code);
      }
    } catch (e, stack) {
      debugPrint('[school] so\'rovnoma: $e\n$stack');
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
    // Yuborilmoqda — natijani kutamiz (bir necha soniya).
    if (_sending) return;
    if (_hasUnsentAnswers &&
        !await confirmSchoolLeave(
          context,
          titleKey: 'school.leave.surveyTitle',
          bodyKey: 'school.leave.surveyBody',
        )) {
      return;
    }
    if (mounted) closeSchoolPage(context);
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome;
    if (outcome != null) {
      return _OutcomePage(
        outcome: outcome,
        onDone: () => closeSchoolPage(context),
      );
    }
    final state = ref.watch(careSurveyProvider);
    final survey = state.valueOrNull?.survey;
    final surveyTitle = survey?.title.trim() ?? '';

    return PopScope(
      canPop: !_hasUnsentAnswers,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: HomeColors.bg,
        body: DesignScale(
          child: Builder(
            builder: (context) => Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      growthTopInset(context),
                      16,
                      24,
                    ),
                    children: [
                      InnerPageHeader(
                        title: 'school.survey.title'.tr(),
                        subtitle: surveyTitle.isEmpty ? null : surveyTitle,
                        fallbackRoute: SchoolRoutes.hub,
                        onBack: _close,
                      ),
                      const SizedBox(height: 16),
                      if (survey != null)
                        ..._questions(survey)
                      else
                        _status(state),
                    ],
                  ),
                ),
                if (survey != null) _bottomBar(survey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _questions(CareSurvey survey) {
    final total = survey.questions.length;
    return [
      SchoolNote(
        icon: SolarIconsOutline.lockKeyhole,
        color: SchoolColors.accent,
        iconColor: SchoolColors.accent,
        text: 'school.survey.privacy'.tr(),
      ),
      const SizedBox(height: 10),
      Text(
        'school.survey.intro'.tr(),
        style: homeText(13.5, color: HomeColors.textDim, height: 1.4),
      ),
      for (var i = 0; i < total; i++) ...[
        const SizedBox(height: 12),
        SurveyQuestionCard(
          number: i + 1,
          total: total,
          text: survey.questions[i].text,
          value: _answers[survey.questions[i].id],
          onChanged: (value) => _answer(survey.questions[i].id, value),
        ),
      ],
    ];
  }

  Widget _bottomBar(CareSurvey survey) {
    final total = survey.questions.length;
    final answered = _answeredCount(survey);
    final isComplete = answered == total;
    final error = _sendError;
    final progress = 'school.survey.progress'.tr(
      namedArgs: {'done': '$answered', 'total': '$total'},
    );
    return SchoolBottomBar(
      children: [
        if (error != null) ...[
          Text(
            '${'school.survey.sendFailedTitle'.tr()}. ${error.messageKey.tr()}',
            textAlign: TextAlign.center,
            style: homeText(13, color: HomeColors.orange, height: 1.35),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          isComplete
              ? progress
              : '$progress · ${'school.survey.allRequired'.tr()}',
          textAlign: TextAlign.center,
          style: homeText(12.5, color: HomeColors.textDim, height: 1.35),
        ),
        const SizedBox(height: 8),
        SetupButton(
          label: 'school.survey.submit'.tr(),
          busy: _sending,
          onTap: isComplete ? () => _submit(survey) : null,
        ),
      ],
    );
  }

  /// So'rovnoma yo'q: yuklanmoqda, xato, bog'lanmagan, javob berilgan yoki
  /// faol so'rovnoma yo'q.
  Widget _status(AsyncValue<CareSurveyStatus> state) {
    final status = state.valueOrNull;
    if (status == null || state.isLoading || state.hasError) {
      if (state.isLoading || !state.hasError) {
        return const Padding(
          padding: EdgeInsets.only(top: 96),
          child: Center(
            child: CircularProgressIndicator(color: HomeColors.primary),
          ),
        );
      }
      final error = state.error;
      final code = error is SchoolException
          ? error.code
          : SchoolErrorCode.unknown;
      return SchoolMessageView(
        icon: code == SchoolErrorCode.network
            ? Icons.wifi_off_rounded
            : SolarIconsOutline.dangerCircle,
        message: code.messageKey.tr(),
        actionLabel: 'common.retry'.tr(),
        onAction: () => ref.invalidate(careSurveyProvider),
      );
    }
    if (!status.isEnrolled) {
      return SchoolMessageView(
        icon: SolarIconsOutline.squareAcademicCap,
        iconColor: HomeColors.blue,
        title: 'school.hub.notLinkedTitle'.tr(),
        message: 'school.hub.notLinkedBody'.tr(),
      );
    }
    if (status.isAnswered) {
      return SchoolMessageView(
        icon: SolarIconsOutline.checkCircle,
        iconColor: HomeColors.green,
        title: 'school.survey.alreadyTitle'.tr(),
        message: 'school.survey.answered'.tr(),
      );
    }
    return SchoolMessageView(
      icon: SolarIconsOutline.chatRoundLike,
      iconColor: SchoolColors.accent,
      title: 'school.survey.noneTitle'.tr(),
      message: 'school.survey.noneBody'.tr(),
    );
  }
}

/// Yakun: rahmat, allaqachon javob berilgan yoki so'rovnoma yakunlangan.
class _OutcomePage extends StatelessWidget {
  const _OutcomePage({required this.outcome, required this.onDone});

  final _Outcome outcome;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final (icon, color, titleKey, bodyKey) = switch (outcome) {
      _Outcome.sent => (
        Icons.check_rounded,
        HomeColors.green,
        'school.survey.doneTitle',
        'school.survey.doneBody',
      ),
      _Outcome.alreadyAnswered => (
        Icons.check_rounded,
        HomeColors.blue,
        'school.survey.alreadyTitle',
        'school.errors.alreadyAnswered',
      ),
      _Outcome.closed => (
        SolarIconsBold.calendarMark,
        HomeColors.orange,
        'school.survey.closedTitle',
        'school.errors.surveyNotFound',
      ),
    };
    return SchoolResultPage(
      key: ValueKey('survey-outcome-${outcome.name}'),
      icon: icon,
      color: color,
      title: titleKey.tr(),
      actions: [SetupButton(label: 'school.survey.done'.tr(), onTap: onDone)],
      children: [SchoolResultNote(bodyKey.tr())],
    );
  }
}
