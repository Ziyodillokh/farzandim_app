// Test yakuni: natija halqasi, sarlavha (darajaga qarab), to'g'ri / xato /
// vaqt, DON mukofoti, "Javoblarni ko'rish" va keyingi qadam (keyingi fan
// yoki "Natijalarim").

import 'package:confetti/confetti.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_header.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_stat_cards.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/presentation/learning_navigation.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_palette.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/score_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class QuizResultView extends ConsumerStatefulWidget {
  const QuizResultView({super.key, required this.result});

  final TestResult result;

  @override
  ConsumerState<QuizResultView> createState() => _QuizResultViewState();
}

class _QuizResultViewState extends ConsumerState<QuizResultView> {
  late final _confetti = ConfettiController(
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.result.level == ScoreLevel.good) _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _close() => context.canPop() ? context.pop() : context.go('/dashboard');

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final plan = ref.watch(dailyPlanProvider);
    // Joriy fan "keyingi" deb taklif qilinmaydi (amaliyot urinishida ham).
    DailyPlanItem? next;
    for (final item in plan.items) {
      if (!item.isDone && item.subject != r.subject) {
        next = item;
        break;
      }
    }
    final planComplete =
        !plan.isEmpty &&
        next == null &&
        plan.items.every((i) => i.isDone || i.subject == r.subject);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            growthTopInset(context),
            16,
            bottomInset + 24,
          ),
          children: [
            Row(
              children: [
                HeaderIconButton(
                  semanticLabel: 'learn.close'.tr(),
                  onTap: _close,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FitText(
                    r.subject.labelKey.tr(),
                    style: homeText(16.5, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: ScoreRing(
                percent: r.percent,
                size: 156,
                stroke: 12,
                // Matn halqa ichida qolsin (katta shriftda ham).
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FitText(
                          '${r.percent}%',
                          style: homeDisplay(34, height: 1.1),
                        ),
                        const SizedBox(height: 4),
                        FitText(
                          'learn.resultOf'.tr(
                            namedArgs: {
                              'correct': '${r.correct}',
                              'total': '${r.total}',
                            },
                          ),
                          style: homeText(13, color: HomeColors.textDim),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              switch (r.level) {
                ScoreLevel.good => 'learn.resultGreat',
                ScoreLevel.medium => 'learn.resultGood',
                ScoreLevel.low => 'learn.resultLow',
              }.tr(),
              textAlign: TextAlign.center,
              style: homeDisplay(22, letterSpacing: -0.3, height: 1.25),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: SolarIconsBold.checkCircle,
                    color: QuizColors.good,
                    value: '${r.correct}',
                    label: 'learn.correctLabel'.tr(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    icon: SolarIconsBold.closeCircle,
                    color: QuizColors.bad,
                    value: '${r.total - r.correct}',
                    label: 'learn.wrongLabel'.tr(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    icon: Icons.timer_rounded,
                    color: HomeColors.blue,
                    value: formatDuration(r.durationSeconds),
                    label: 'learn.timeLabel'.tr(),
                  ),
                ),
              ],
            ),
            if (r.donEarned > 0) ...[
              const SizedBox(height: 10),
              _RewardCard(don: r.donEarned),
            ],
            if (!r.isDaily) ...[
              const SizedBox(height: 10),
              const _PracticeNote(),
            ],
            const SizedBox(height: 18),
            if (planComplete) ...[
              const _PlanDoneBanner(),
              const SizedBox(height: 14),
            ],
            if (next != null)
              _PrimaryButton(
                label: 'learn.nextSubject'.tr(
                  namedArgs: {'subject': next.subject.labelKey.tr()},
                ),
                onTap: () => context.pushReplacement(
                  LearningRoutes.quiz,
                  extra: next!.subject,
                ),
              )
            else
              _PrimaryButton(
                label: 'learn.toResults'.tr(),
                onTap: () => context.go('/progress'),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SecondaryButton(
                    label: 'learn.reviewAnswers'.tr(),
                    onTap: () => openResultReview(context, r),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SecondaryButton(
                    label: 'learn.toHome'.tr(),
                    onTap: () => context.go('/dashboard'),
                  ),
                ),
              ],
            ),
          ],
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirection: 1.5708,
            emissionFrequency: 0.06,
            numberOfParticles: 22,
            maxBlastForce: 18,
            minBlastForce: 7,
            gravity: 0.3,
            colors: const [
              HomeColors.primary,
              HomeColors.blue,
              QuizColors.good,
              HomeColors.amber,
            ],
          ),
        ),
      ],
    );
  }
}

/// "2:35" — daqiqa:soniya.
String formatDuration(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: homeCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 8),
          FitText(value, style: homeDisplay(20)),
          const SizedBox(height: 2),
          FitText(label, style: homeText(12.5, color: HomeColors.textDim)),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.don});

  final int don;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: homeCardDecoration(),
      child: Row(
        children: [
          Image.asset('assets/icons/ic_don.png', width: 34, height: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'learn.reward'.tr(),
                  style: homeText(12.5, color: HomeColors.textDim),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('+$don', style: homeDisplay(20)),
                    const SizedBox(width: 6),
                    const DonBadge(fontSize: 10.5),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanDoneBanner extends StatelessWidget {
  const _PlanDoneBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: QuizColors.goodBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: QuizColors.goodBorder),
      ),
      child: Row(
        children: [
          const Icon(SolarIconsBold.cupStar, size: 26, color: QuizColors.good),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'learn.planDone'.tr(),
                  style: homeText(15, weight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'learn.planDoneHint'.tr(),
                  style: homeText(13, color: HomeColors.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Amaliyot urinishi — DON faqat fan bo'yicha kunlik birinchi testga.
class _PracticeNote extends StatelessWidget {
  const _PracticeNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: homeCardDecoration(),
      child: Row(
        children: [
          const Icon(
            SolarIconsOutline.infoCircle,
            size: 22,
            color: HomeColors.textDim,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'learn.practiceNote'.tr(),
              style: homeText(13.5, color: HomeColors.textDim, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeColors.primary,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
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

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeColors.card,
      shape: const StadiumBorder(
        side: BorderSide(color: HomeColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FitText(
                label,
                style: homeText(14, weight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
