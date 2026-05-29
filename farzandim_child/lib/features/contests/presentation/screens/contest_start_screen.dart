// ─────────────────────────────────────────────────────────────────────
// ContestStartScreen — 3 qadamli konkurs boshlash (PDF p15-17)
// ─────────────────────────────────────────────────────────────────────
//
// PageView (NeverScrollable — faqat tugma bilan o'tish):
//   1. Info  — konkurs ma'lumoti, stats
//   2. Rules — 5 ta qoida card
//   3. Ready — pulsing trophy, BOSHLASH tugma, 3..2..1 countdown
//
// Top bar: back + 3 step indicator. Step 1'da back → Konkurslar ekrani.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'dart:async';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ContestStartScreen extends StatefulWidget {
  const ContestStartScreen({required this.contest, super.key});

  final ContestModel contest;

  @override
  State<ContestStartScreen> createState() => _ContestStartScreenState();
}

class _ContestStartScreenState extends State<ContestStartScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(currentStep: _currentStep, onBack: _prevStep),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) =>
                      setState(() => _currentStep = i),
                  children: [
                    _ContestInfoStep(
                      contest: widget.contest,
                      onContinue: _nextStep,
                    ),
                    _ContestRulesStep(onContinue: _nextStep),
                    _ContestReadyStep(contest: widget.contest),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Top bar ─────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.currentStep, required this.onBack});

  final int currentStep;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(AppIcons.back,
                color: AppColors.textPrimary),
            onPressed: onBack,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(3, (i) {
                  final isActive = i <= currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin:
                          const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ─── Step 1: Info ────────────────────────────────────────────────────

class _ContestInfoStep extends StatelessWidget {
  const _ContestInfoStep({
    required this.contest,
    required this.onContinue,
  });

  final ContestModel contest;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: contest.imageUrl.isNotEmpty
                          ? Image.network(
                              contest.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _placeholderImage(),
                            )
                          : _placeholderImage(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: contest.placeholderColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      contest.soha,
                      style: TextStyle(
                        color: contest.placeholderColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    contest.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    contest.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _statRow(AppIcons.star, 'Sovrin',
                      '${contest.bonus} ball', AppColors.primary),
                  const Divider(color: AppColors.border, height: 24),
                  _statRow(Icons.help_outline, 'Savollar soni',
                      '${contest.savollarSoni} ta',
                      AppColors.catLavenderDark),
                  const Divider(color: AppColors.border, height: 24),
                  _statRow(AppIcons.schedule, 'Vaqt chegarasi',
                      '${contest.vaqtChegarasiDaq} daqiqa',
                      AppColors.catOrangeWarm),
                  const Divider(color: AppColors.border, height: 24),
                  _statRow(Icons.people, 'Ishtirokchilar',
                      '${contest.ishtirokchilarSoni} ta',
                      AppColors.catMint),
                  const Divider(color: AppColors.border, height: 24),
                  _statRow(Icons.event, 'Tugash vaqti',
                      contest.remainingFormatted,
                      AppColors.catPinkRose),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          _ContinueButton(label: 'Davom etish', onPressed: onContinue),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  contest.placeholderColor,
                  // ignore: deprecated_member_use
                  contest.placeholderColor.withOpacity(0.7),
                ],
              ),
            ),
          ),
        ),
        Center(
          child: Icon(
            contest.placeholderIcon,
            // ignore: deprecated_member_use
            color: Colors.white.withOpacity(0.9),
            size: 80,
          ),
        ),
      ],
    );
  }

  Widget _statRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── Step 2: Rules ───────────────────────────────────────────────────

class _Rule {
  const _Rule({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
}

class _ContestRulesStep extends StatelessWidget {
  const _ContestRulesStep({required this.onContinue});

  final VoidCallback onContinue;

  static const List<_Rule> _rules = [
    _Rule(
      icon: AppIcons.schedule,
      title: 'Vaqt chegarasi',
      description: 'Har savol uchun cheklangan vaqt bor',
      color: AppColors.catOrangeWarm,
    ),
    _Rule(
      icon: Icons.undo,
      title: "Qaytarish yo'q",
      description: "Javob berilgan savolga qaytib bo'lmaydi",
      color: AppColors.catPinkRose,
    ),
    _Rule(
      icon: Icons.wifi,
      title: 'Internet aloqasi',
      description: "Konkurs davomida internet barqaror bo'lishi shart",
      color: AppColors.catMint,
    ),
    _Rule(
      icon: Icons.handshake,
      title: 'Halol javob',
      description:
          "Halol javob bering, boshqalardan yordam so'ramang",
      color: AppColors.catLavender,
    ),
    _Rule(
      icon: AppIcons.trophy,
      title: 'Bonus ballar',
      description: "To'g'ri javoblar uchun bonus ballar to'planadi",
      color: AppColors.catLimeBright,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Konkurs qoidalari',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Konkurs boshlanishidan oldin qoidalar bilan tanishib chiqing',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final rule in _rules) _RuleCard(rule: rule),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          _ContinueButton(label: 'Davom etish', onPressed: onContinue),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule});

  final _Rule rule;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: rule.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(rule.icon, color: rule.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rule.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 3: Ready ──────────────────────────────────────────────────

class _ContestReadyStep extends StatefulWidget {
  const _ContestReadyStep({required this.contest});

  final ContestModel contest;

  @override
  State<_ContestReadyStep> createState() => _ContestReadyStepState();
}

class _ContestReadyStepState extends State<_ContestReadyStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isCountingDown = false;
  int _countdown = 3;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _isCountingDown = true;
      _countdown = 3;
    });

    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _onContestStart();
      }
    });
  }

  void _onContestStart() {
    if (!mounted) return;
    // Start screen'ni quiz bilan almashtirish — back tugma /contests'ga olib boradi.
    context.pushReplacement('/contest-quiz', extra: widget.contest);
  }

  @override
  Widget build(BuildContext context) {
    if (_isCountingDown) return _Countdown(countdown: _countdown);

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
                    animation: _pulseController,
                    builder: (_, __) {
                      final scale = 1.0 + (_pulseController.value * 0.1);
                      return Transform.scale(
                        scale: scale,
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
                              child: const Icon(
                                AppIcons.trophy,
                                color: Colors.black,
                                size: 64,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Tayyormisiz?',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      "Konkurs boshlangach to'xtatib bo'lmaydi.\nMuvaffaqiyat tilaymiz!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _ContinueButton(
            label: 'BOSHLASH',
            onPressed: _startCountdown,
            big: true,
          ),
        ],
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.countdown});

  final int countdown;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(countdown),
        tween: Tween(begin: 0.5, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (_, scale, __) {
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$countdown',
                  style: const TextStyle(
                    fontSize: 100,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Continue button (shared) ────────────────────────────────────────

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.label,
    required this.onPressed,
    this.big = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            padding:
                EdgeInsets.symmetric(vertical: big ? 20 : 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: big ? 18 : 16,
              fontWeight: big ? FontWeight.bold : FontWeight.w600,
              letterSpacing: big ? 1.5 : 0,
            ),
          ),
        ),
      ),
    );
  }
}
