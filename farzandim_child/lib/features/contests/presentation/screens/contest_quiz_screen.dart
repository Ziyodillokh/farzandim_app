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

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/data/models/quiz_state.dart';
import 'package:farzandim_child/features/contests/data/sound_service.dart';
import 'package:farzandim_child/features/contests/presentation/providers/quiz_provider.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

class ContestQuizScreen extends ConsumerStatefulWidget {
  const ContestQuizScreen({required this.contest, super.key});

  final ContestModel contest;

  @override
  ConsumerState<ContestQuizScreen> createState() =>
      _ContestQuizScreenState();
}

class _ContestQuizScreenState extends ConsumerState<ContestQuizScreen> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quizProvider(widget.contest));

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
          next.accuracy >= 0.8) {
        _confettiController.play();
        SoundService.playVictory();
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Stack(
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
                  AppColors.primary,
                  AppColors.catPinkRose,
                  AppColors.catLavenderDark,
                  AppColors.catOrangeWarm,
                  AppColors.catMint,
                ],
              ),
            ),
          ],
        ),
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
          onStart: () => ref
              .read(quizProvider(widget.contest).notifier)
              .startPlaying(),
        );
      case QuizStatus.playing:
      case QuizStatus.paused:
        return _QuestionScreen(
            contest: widget.contest, state: state);
      case QuizStatus.finished:
        return _ResultScreen(
            contest: widget.contest, state: state);
    }
  }
}

// ─── Loading ────────────────────────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.contest});

  final ContestModel contest;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: contest.placeholderColor,
              shape: BoxShape.circle,
            ),
            child: Icon(contest.placeholderIcon,
                color: Colors.white, size: 64),
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Savollar tayyorlanmoqda...',
            style: TextStyle(
                fontSize: 16, color: AppColors.textSecondary),
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
                      scale: 1.0 + (_pulse.value * 0.1),
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          // ignore: deprecated_member_use
                          color: AppColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.quiz,
                                color: Colors.black, size: 64),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Konkurs boshlanmoqda!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _StatRow(
                      icon: Icons.quiz, text: '10 ta savol'),
                  const SizedBox(height: 12),
                  const _StatRow(
                      icon: AppIcons.schedule,
                      text: 'Har savol uchun 40 sek'),
                  const SizedBox(height: 12),
                  _StatRow(
                    icon: AppIcons.star,
                    text: '${widget.contest.bonus} ball sovrin',
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text(
                  'BOSHLASH',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
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
    final question = state.currentQuestion;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _QuestionTopBar(
            currentIndex: state.currentIndex,
            onClose: () => _showPauseDialog(context, ref),
          ),
          const SizedBox(height: 16),
          if (state.currentStreak >= 3)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _StreakBadge(streak: state.currentStreak),
            ),
          _ScoreTimerRow(state: state),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    question.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  for (int i = 0; i < 4; i++)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 6),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          // ignore: deprecated_member_use
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              question.explanation!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                height: 1.4,
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

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.pause,
                  color: AppColors.warning, size: 56),
              const SizedBox(height: 16),
              const Text(
                "Konkursni to'xtatasizmi?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Chiqsangiz progress saqlanmaydi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref
                            .read(quizProvider(contest).notifier)
                            .quit();
                        Navigator.pop(ctx);
                        if (context.mounted) {
                          context.go('/contests');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        side:
                            const BorderSide(color: AppColors.error),
                      ),
                      child: const Text(
                        'Chiqish',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref
                            .read(quizProvider(contest).notifier)
                            .resume();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text(
                        'Davom etish',
                        style:
                            TextStyle(fontWeight: FontWeight.w600),
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
  const _QuestionTopBar(
      {required this.currentIndex, required this.onClose});

  final int currentIndex;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(AppIcons.close,
                color: AppColors.textPrimary),
            onPressed: onClose,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (currentIndex + 1) / 10,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary),
                ),
              ),
            ),
          ),
          Text(
            '${currentIndex + 1}/10',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.catOrangeLight, AppColors.catPinkRose],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.streak,
              color: Colors.white, size: 20),
          const SizedBox(width: 6),
          Text(
            'Streak: $streak',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
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
    final timeColor = state.timeRemaining <= 10
        ? AppColors.error
        : AppColors.textPrimary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(AppIcons.star,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              Text(
                '${state.totalScore}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: state.timeRemaining <= 10
                // ignore: deprecated_member_use
                ? AppColors.error.withOpacity(0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.timer, color: timeColor, size: 20),
              const SizedBox(width: 6),
              Text(
                '0:${state.timeRemaining.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: timeColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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
    Color bgColor = AppColors.surface;
    Color borderColor = AppColors.border;
    Color textColor = AppColors.textPrimary;
    Widget? trailingIcon;

    if (answerState != AnswerState.none) {
      if (isCorrect) {
        // ignore: deprecated_member_use
        bgColor = Colors.green.withOpacity(0.15);
        borderColor = Colors.green;
        textColor = Colors.green;
        trailingIcon = const Icon(AppIcons.success,
            color: Colors.green, size: 24);
      } else if (isSelected) {
        // ignore: deprecated_member_use
        bgColor = AppColors.error.withOpacity(0.15);
        borderColor = AppColors.error;
        textColor = AppColors.error;
        trailingIcon = const Icon(Icons.cancel,
            color: AppColors.error, size: 24);
      }
    }

    return GestureDetector(
      onTap: answerState == AnswerState.none ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: borderColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  color: textColor,
                  fontWeight: FontWeight.w500,
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

class _ResultScreen extends StatelessWidget {
  const _ResultScreen({required this.contest, required this.state});

  final ContestModel contest;
  final QuizState state;

  @override
  Widget build(BuildContext context) {
    final isWinner = state.accuracy >= 0.7;
    final percent = (state.accuracy * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: isWinner
                  ? AppColors.primary
                  // ignore: deprecated_member_use
                  : AppColors.warning.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isWinner ? AppIcons.trophy : Icons.psychology,
              color: isWinner ? Colors.black : AppColors.warning,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isWinner ? 'Tabriklaymiz!' : 'Yaxshi urinish!',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isWinner
                ? 'Konkursni muvaffaqiyatli yakunladingiz'
                : "Keyingi safar yanada yaxshi natija ko'rsatasiz",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _ResultStat(
                    label: "To'g'ri javoblar",
                    value: '${state.correctCount}/10',
                    color: AppColors.catMint),
                const Divider(color: AppColors.border, height: 24),
                _ResultStat(
                    label: 'Yiqqan ball',
                    value: '${state.totalScore}',
                    color: AppColors.primary),
                const Divider(color: AppColors.border, height: 24),
                _ResultStat(
                    label: 'Aniqlik',
                    value: '$percent%',
                    color: AppColors.catLavenderDark),
                const Divider(color: AppColors.border, height: 24),
                _ResultStat(
                    label: 'Maksimal streak',
                    value: '${state.maxStreak}',
                    color: AppColors.catOrangeLight),
                const Divider(color: AppColors.border, height: 24),
                _ResultStat(
                    label: 'Vaqt',
                    value: _formatDuration(state.totalElapsed),
                    color: AppColors.catPinkRose),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _onShare(context),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Ulashish'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => context.go('/contests'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Yopish',
                    style:
                        TextStyle(fontWeight: FontWeight.w600),
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
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
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
