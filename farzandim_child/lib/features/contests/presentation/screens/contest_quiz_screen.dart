// ─────────────────────────────────────────────────────────────────────
// ContestQuizScreen — savol-javob to'liq tajriba (PDF p18+)
// ─────────────────────────────────────────────────────────────────────
//
// 4 ta sub-ekran (status'ga qarab):
//   loading  → _LoadingScreen
//   intro    → _IntroScreen
//   playing/paused → _QuestionScreen (+ pause dialog)
//   finished → _ResultScreen
//
// Yon UX:
//   - Confetti (streak 3, 6, 9... + final 80%+)
//   - Haptic feedback (light/heavy/medium)
//   - Sound effects (placeholder)
//   - Share natija
//
// Dizayn: "Parvoz Premium" (Stitch) — deep navy fon, glass kartalar,
// aqua aksent + glow. CP palitra + cjak() matn helper.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/data/models/quiz_state.dart';
import 'package:farzandim_child/features/contests/data/repositories/certificate_repository.dart';
import 'package:farzandim_child/features/contests/data/sound_service.dart';
import 'package:farzandim_child/features/contests/presentation/contests_theme.dart';
import 'package:farzandim_child/features/contests/presentation/providers/quiz_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

class ContestQuizScreen extends ConsumerStatefulWidget {
  const ContestQuizScreen({required this.contest, super.key});

  final ContestModel contest;

  @override
  ConsumerState<ContestQuizScreen> createState() => _ContestQuizScreenState();
}

class _ContestQuizScreenState extends ConsumerState<ContestQuizScreen> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quizProvider(widget.contest));
    final p = CP(true);

    ref.listen<QuizState>(quizProvider(widget.contest), (prev, next) {
      // Answer feedback hooks
      if (prev?.answerState != next.answerState) {
        if (next.answerState == AnswerState.correct) {
          HapticFeedback.lightImpact();
          SoundService.playCorrect();
          if (next.currentStreak >= 3 && next.currentStreak % 3 == 0) {
            _confettiController.play();
          }
        } else if (next.answerState == AnswerState.wrong) {
          HapticFeedback.heavyImpact();
          SoundService.playWrong();
        } else if (next.answerState == AnswerState.timeout) {
          HapticFeedback.mediumImpact();
          SoundService.playTimeout();
        }
      }
      // Final hook
      if (prev?.status != next.status &&
          next.status == QuizStatus.finished &&
          next.isWinner) {
        _confettiController.play();
        SoundService.playVictory();
      }
    });

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: [
          SafeArea(child: _buildContent(state)),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: math.pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.3,
              colors: const [
                AppColors.parvozGreen,
                AppColors.catPinkRose,
                AppColors.catLavenderDark,
                AppColors.catOrangeWarm,
                AppColors.catMint,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(QuizState state) {
    switch (state.status) {
      case QuizStatus.loading:
        return _LoadingScreen(contest: widget.contest);
      case QuizStatus.intro:
        return _IntroScreen(
          contest: widget.contest,
          onStart: () =>
              ref.read(quizProvider(widget.contest).notifier).startPlaying(),
        );
      case QuizStatus.playing:
      case QuizStatus.paused:
        return _QuestionScreen(contest: widget.contest, state: state);
      case QuizStatus.finished:
        return _ResultScreen(contest: widget.contest, state: state);
    }
  }
}

// ─── Loading ────────────────────────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.contest});

  final ContestModel contest;

  @override
  Widget build(BuildContext context) {
    final p = CP(true);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: p.card,
              shape: BoxShape.circle,
              border: Border.all(
                color: p.accent.withValues(alpha: 0.35),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: p.accent.withValues(alpha: 0.30),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: contest.placeholderColor.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  contest.placeholderIcon,
                  color: Colors.white,
                  size: 52,
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: p.accent,
              backgroundColor: p.border,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Savollar tayyorlanmoqda...',
            style: cjak(p, size: 15, weight: FontWeight.w600, color: p.muted),
          ),
        ],
      ),
    );
  }
}

// ─── Intro ──────────────────────────────────────────────────────────

class _IntroScreen extends StatefulWidget {
  const _IntroScreen({required this.contest, required this.onStart});

  final ContestModel contest;
  final VoidCallback onStart;

  @override
  State<_IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<_IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = CP(true);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Transform.scale(
                      scale: 1.0 + (_pulse.value * 0.08),
                      child: Container(
                        width: 168,
                        height: 168,
                        decoration: BoxDecoration(
                          color: p.accent.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: p.accent.withValues(
                                alpha: 0.18 + _pulse.value * 0.22,
                              ),
                              blurRadius: 48,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [p.accentSoft, p.accent],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.quiz_rounded,
                              color: p.onAccent,
                              size: 60,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'Konkurs boshlanmoqda!',
                    textAlign: TextAlign.center,
                    style: cjak(
                      p,
                      size: 28,
                      weight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: p.border),
                    ),
                    child: Column(
                      children: [
                        const _StatRow(
                          icon: Icons.quiz_rounded,
                          text: '10 ta savol',
                        ),
                        const SizedBox(height: 14),
                        const _StatRow(
                          icon: AppIcons.schedule,
                          text: 'Har savol uchun 40 sek',
                        ),
                        const SizedBox(height: 14),
                        _StatRow(
                          icon: AppIcons.star,
                          text: '${widget.contest.bonus} ball sovrin',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: p.accent.withValues(alpha: 0.34),
                      blurRadius: 26,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: widget.onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: p.onAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    'BOSHLASH',
                    style: cjak(
                      p,
                      size: 18,
                      weight: FontWeight.w800,
                      color: p.onAccent,
                      spacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = CP(true);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: p.accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: p.accent, size: 18),
        ),
        const SizedBox(width: 12),
        Text(text, style: cjak(p, size: 15, weight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Question ───────────────────────────────────────────────────────

class _QuestionScreen extends ConsumerWidget {
  const _QuestionScreen({required this.contest, required this.state});

  final ContestModel contest;
  final QuizState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = CP(true);
    final question = state.currentQuestion;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _QuestionTopBar(
            currentIndex: state.currentIndex,
            onClose: () => _showPauseDialog(context, ref),
          ),
          const SizedBox(height: 14),
          if (state.currentStreak >= 3)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StreakBadge(streak: state.currentStreak),
            ),
          _ScoreTimerRow(state: state),
          const SizedBox(height: 22),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: p.border),
                    ),
                    child: Text(
                      question.text,
                      textAlign: TextAlign.center,
                      style: cjak(
                        p,
                        size: 20,
                        weight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Variantlar soni bo'yicha (avval qat'iy `i < 4` edi — savolda
                  // 4 tadan kam variant bo'lsa options[i] RangeError berardi).
                  for (int i = 0; i < question.options.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _OptionCard(
                        letter: String.fromCharCode(65 + i),
                        text: question.options[i],
                        isSelected: state.selectedAnswer == i,
                        isCorrect: i == question.correctIndex,
                        answerState: state.answerState,
                        onTap: () => ref
                            .read(quizProvider(contest).notifier)
                            .selectAnswer(i),
                      ),
                    ),
                  if (state.answerState != AnswerState.none &&
                      question.explanation != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: p.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: p.accent.withValues(alpha: 0.32),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_rounded,
                            color: p.accent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              question.explanation!,
                              style: cjak(
                                p,
                                size: 13,
                                weight: FontWeight.w500,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPauseDialog(BuildContext context, WidgetRef ref) {
    ref.read(quizProvider(contest).notifier).pause();

    final p = CP(true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: p.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: p.warn.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(AppIcons.pause, color: p.warn, size: 38),
              ),
              const SizedBox(height: 18),
              Text(
                "Konkursni to'xtatasizmi?",
                textAlign: TextAlign.center,
                style: cjak(p, size: 18, weight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Chiqsangiz progress saqlanmaydi',
                textAlign: TextAlign.center,
                style: cjak(
                  p,
                  size: 13,
                  weight: FontWeight.w500,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(quizProvider(contest).notifier).quit();
                        Navigator.pop(ctx);
                        if (context.mounted) {
                          context.go('/contests');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.danger,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        side: BorderSide(
                          color: p.danger.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Text(
                        'Chiqish',
                        style: cjak(
                          p,
                          size: 14,
                          weight: FontWeight.w700,
                          color: p.danger,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(quizProvider(contest).notifier).resume();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: p.accent,
                        foregroundColor: p.onAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        'Davom etish',
                        style: cjak(
                          p,
                          size: 14,
                          weight: FontWeight.w700,
                          color: p.onAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionTopBar extends StatelessWidget {
  const _QuestionTopBar({required this.currentIndex, required this.onClose});

  final int currentIndex;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = CP(true);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Material(
            color: p.card,
            shape: CircleBorder(side: BorderSide(color: p.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Icon(AppIcons.close, color: p.text, size: 22),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (currentIndex + 1) / 10,
                  minHeight: 8,
                  backgroundColor: p.border,
                  valueColor: AlwaysStoppedAnimation<Color>(p.accent),
                ),
              ),
            ),
          ),
          Text(
            '${currentIndex + 1}/10',
            style: cjak(p, size: 14, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final p = CP(true);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.catOrangeLight, AppColors.catPinkRose],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.catOrangeLight.withValues(alpha: 0.40),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.streak, color: Colors.white, size: 20),
          const SizedBox(width: 7),
          Text(
            'Streak: $streak',
            style: cjak(
              p,
              size: 14,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreTimerRow extends StatelessWidget {
  const _ScoreTimerRow({required this.state});

  final QuizState state;

  @override
  Widget build(BuildContext context) {
    final p = CP(true);
    final isLow = state.timeRemaining <= 10;
    final timeColor = isLow ? p.danger : p.text;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Icon(AppIcons.star, color: p.accent, size: 20),
              const SizedBox(width: 7),
              Text(
                '${state.totalScore}',
                style: cjak(p, size: 16, weight: FontWeight.w800),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isLow ? p.danger.withValues(alpha: 0.15) : p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLow ? p.danger.withValues(alpha: 0.45) : p.border,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.timer_rounded, color: timeColor, size: 20),
              const SizedBox(width: 7),
              Text(
                '0:${state.timeRemaining.toString().padLeft(2, '0')}',
                style: cjak(
                  p,
                  size: 16,
                  weight: FontWeight.w800,
                  color: timeColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.letter,
    required this.text,
    required this.isSelected,
    required this.isCorrect,
    required this.answerState,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool isSelected;
  final bool isCorrect;
  final AnswerState answerState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = CP(true);
    final correctColor = AppColors.catMint;

    Color bgColor = p.card;
    Color borderColor = p.border;
    Color textColor = p.text;
    Color badgeColor = p.accent;
    Widget? trailingIcon;

    if (answerState != AnswerState.none) {
      if (isCorrect) {
        bgColor = correctColor.withValues(alpha: 0.14);
        borderColor = correctColor;
        textColor = correctColor;
        badgeColor = correctColor;
        trailingIcon = Icon(AppIcons.success, color: correctColor, size: 24);
      } else if (isSelected) {
        bgColor = p.danger.withValues(alpha: 0.14);
        borderColor = p.danger;
        textColor = p.danger;
        badgeColor = p.danger;
        trailingIcon = Icon(Icons.cancel_rounded, color: p.danger, size: 24);
      } else {
        textColor = p.muted;
        badgeColor = p.muted;
      }
    }

    return GestureDetector(
      onTap: answerState == AnswerState.none ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: badgeColor.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: cjak(
                    p,
                    size: 15,
                    weight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                text,
                style: cjak(
                  p,
                  size: 15,
                  weight: FontWeight.w600,
                  color: textColor,
                  height: 1.3,
                ),
              ),
            ),
            if (trailingIcon != null) trailingIcon,
          ],
        ),
      ),
    );
  }
}

// ─── Result ─────────────────────────────────────────────────────────

class _ResultScreen extends ConsumerWidget {
  const _ResultScreen({required this.contest, required this.state});

  final ContestModel contest;
  final QuizState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = CP(true);
    final isWinner = state.isWinner;
    final percent = (state.accuracy * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              gradient: isWinner
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [p.accentSoft, p.accent],
                    )
                  : null,
              color: isWinner ? null : p.warn.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: isWinner
                  ? null
                  : Border.all(
                      color: p.warn.withValues(alpha: 0.5),
                      width: 1.4,
                    ),
              boxShadow: [
                BoxShadow(
                  color: (isWinner ? p.accent : p.warn).withValues(alpha: 0.34),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              isWinner ? AppIcons.trophy : Icons.psychology_rounded,
              color: isWinner ? p.onAccent : p.warn,
              size: 62,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isWinner ? 'Tabriklaymiz!' : 'Yaxshi urinish!',
            style: cjak(p, size: 32, weight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            isWinner
                ? 'Konkursni muvaffaqiyatli yakunladingiz'
                : "Keyingi safar yanada yaxshi natija ko'rsatasiz",
            textAlign: TextAlign.center,
            style: cjak(p, size: 14, weight: FontWeight.w500, color: p.muted),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: Column(
              children: [
                _ResultStat(
                  label: "To'g'ri javoblar",
                  value: '${state.correctCount}/10',
                  color: AppColors.catMint,
                ),
                _ResultDivider(p: p),
                _ResultStat(
                  label: 'Yiqqan ball',
                  value: '${state.totalScore}',
                  color: p.accent,
                ),
                _ResultDivider(p: p),
                _ResultStat(
                  label: 'Aniqlik',
                  value: '$percent%',
                  color: AppColors.catLavenderDark,
                ),
                _ResultDivider(p: p),
                _ResultStat(
                  label: 'Maksimal streak',
                  value: '${state.maxStreak}',
                  color: AppColors.catOrangeLight,
                ),
                _ResultDivider(p: p),
                _ResultStat(
                  label: 'Vaqt',
                  value: _formatDuration(state.totalElapsed),
                  color: AppColors.catPinkRose,
                ),
              ],
            ),
          ),
          const Spacer(),
          // Sertifikat (#56) — faqat g'olib (chegaradan yuqori) va real
          // attempt bo'lsa. Tugma bosilganda backend haqdorligini tekshiradi.
          if (isWinner && state.attemptId != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openCertificate(context, ref),
                icon: Icon(
                  Icons.workspace_premium_rounded,
                  size: 20,
                  color: p.onAccent,
                ),
                label: Text(
                  'Sertifikat',
                  style: cjak(
                    p,
                    size: 15,
                    weight: FontWeight.w800,
                    color: p.onAccent,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.gold,
                  foregroundColor: p.onAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _onShare(context),
                  icon: Icon(Icons.share_rounded, size: 18, color: p.text),
                  label: Text(
                    'Ulashish',
                    style: cjak(p, size: 14, weight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.text,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    side: BorderSide(color: p.border),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => context.go('/contests'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: p.onAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    'Yopish',
                    style: cjak(
                      p,
                      size: 15,
                      weight: FontWeight.w800,
                      color: p.onAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _onShare(BuildContext context) async {
    final text =
        "Men Parvoz ilovasida '${contest.title}' konkursida "
        "${state.correctCount}/10 to'g'ri javob berdim! 🏆\n"
        'Yiqqan ball: ${state.totalScore}\n\n'
        'Sen ham qatnash!';
    await Share.share(text);
  }

  /// Sertifikat ma'lumotini backend'dan oladi (haqdorlikni tekshiradi) va
  /// sertifikat ekranini ochadi. Haqli bo'lmasa — xabar.
  Future<void> _openCertificate(BuildContext context, WidgetRef ref) async {
    final attemptId = state.attemptId;
    if (attemptId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final data = await ref.read(certificateRepositoryProvider).fetch(attemptId);
    if (!context.mounted) return;
    if (data == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sertifikat hozircha mavjud emas.')),
      );
      return;
    }
    if (context.mounted) {
      context.push('/certificate', extra: data);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _ResultDivider extends StatelessWidget {
  const _ResultDivider({required this.p});

  final CP p;

  @override
  Widget build(BuildContext context) {
    return Divider(color: p.border, height: 24, thickness: 1);
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = CP(true);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            label,
            style: cjak(p, size: 14, weight: FontWeight.w500, color: p.muted),
          ),
        ),
        Text(value, style: cjak(p, size: 16, weight: FontWeight.w800)),
      ],
    );
  }
}
