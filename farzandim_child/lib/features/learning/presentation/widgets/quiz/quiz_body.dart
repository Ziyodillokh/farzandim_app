// Test tanasi: savol kartasi, variantlar, izoh va pastdagi asosiy tugma
// ("Tekshirish" → "Keyingi savol" / "Natijani ko'rish").

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/domain/quiz_session.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_feedback_card.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_option_tile.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_question_card.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class QuizBody extends StatefulWidget {
  const QuizBody({
    super.key,
    required this.session,
    required this.onSelect,
    required this.onCheck,
    required this.onNext,
  });

  final QuizSession session;
  final ValueChanged<int> onSelect;
  final VoidCallback onCheck;
  final VoidCallback onNext;

  @override
  State<QuizBody> createState() => _QuizBodyState();
}

class _QuizBodyState extends State<QuizBody> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(QuizBody old) {
    super.didUpdateWidget(old);
    final s = widget.session;
    if (s.index != old.session.index && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    // Izoh paydo bo'lganda — ko'rinadigan joyga suriladi.
    if (s.phase == QuizPhase.checked &&
        old.session.phase != QuizPhase.checked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  OptionState _stateOf(int i) {
    final s = widget.session;
    final feedback = s.currentFeedback;
    if (feedback == null) {
      return s.selectedIndex == i ? OptionState.selected : OptionState.idle;
    }
    if (i == feedback.correctIndex) return OptionState.correct;
    if (i == feedback.selectedIndex) return OptionState.wrong;
    return OptionState.dimmed;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final lang = context.locale.languageCode;
    final q = s.current;
    final feedback = s.currentFeedback;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            children: [
              QuizQuestionCard(
                topic: q.topic.of(lang),
                text: q.prompt.of(lang),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < q.options.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                QuizOptionTile(
                  index: i,
                  text: q.options[i].of(lang),
                  state: _stateOf(i),
                  onTap: s.phase == QuizPhase.answering
                      ? () => widget.onSelect(i)
                      : null,
                ),
              ],
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: feedback == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: QuizFeedbackCard(
                          isCorrect: feedback.isCorrect,
                          explanation: feedback.explanation.of(lang),
                          correctAnswer: feedback.isCorrect
                              ? null
                              : q.options[feedback.correctIndex].of(lang),
                        ),
                      ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset + 14),
          decoration: const BoxDecoration(
            color: HomeColors.bg,
            border: Border(top: BorderSide(color: Color(0x0FFFFFFF))),
          ),
          child: _MainButton(
            label: switch (s.phase) {
              QuizPhase.answering || QuizPhase.checking => 'learn.check'.tr(),
              _ when s.isLast => 'learn.seeResult'.tr(),
              _ => 'learn.nextQuestion'.tr(),
            },
            busy: s.phase == QuizPhase.checking,
            enabled: s.phase == QuizPhase.checked || s.selectedIndex != null,
            onTap: s.phase == QuizPhase.answering
                ? widget.onCheck
                : widget.onNext,
          ),
        ),
      ],
    );
  }
}

class _MainButton extends StatelessWidget {
  const _MainButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  /// Server javobi kutilmoqda — spinner, bosilmaydi.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled || busy ? 1 : 0.45,
      child: Material(
        color: HomeColors.primary,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled && !busy ? onTap : null,
          child: SizedBox(
            height: 52,
            child: busy
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FitText(
                          label,
                          style: homeText(15.5, weight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        SolarIconsOutline.arrowRight,
                        size: 19,
                        color: Colors.white,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Savollar yuklanmoqda / natija hisoblanmoqda / xabar (+ tugma).
class QuizStatus extends StatelessWidget {
  const QuizStatus({
    super.key,
    this.loading = false,
    this.message,
    this.icon = SolarIconsOutline.dangerCircle,
    this.actionLabel,
    this.onAction,
  });

  final bool loading;

  /// Yuklanayotganda — izoh (masalan "Natija hisoblanmoqda…").
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const CircularProgressIndicator(color: HomeColors.primary)
            else
              Icon(icon, size: 44, color: HomeColors.textDim),
            if (message != null) ...[
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: homeText(15, color: HomeColors.textDim, height: 1.4),
              ),
            ],
            if (!loading && actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: HomeColors.primary,
                  shape: const StadiumBorder(),
                ),
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: homeText(14.5, weight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
