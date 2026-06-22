// ─────────────────────────────────────────────────────────────────────
// ContestStartScreen — 3 qadamli konkurs boshlash (Parvoz Premium)
// ─────────────────────────────────────────────────────────────────────
//
// PageView (NeverScrollable — faqat tugma bilan o'tish):
//   1. Info  — konkurs ma'lumoti, stats
//   2. Rules — 5 ta qoida glass card
//   3. Ready — pulsing trophy + glow, BOSHLASH tugma, 3..2..1 countdown
//
// Top bar: back + 3 step indicator (aqua faol). Step 1'da back → Konkurslar.
// Dizayn tizimi: contests_theme.dart (CP palitra + cjak + SubjectBadge).

import 'dart:async';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/presentation/contests_theme.dart';
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
    final p = CP(true);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(currentStep: _currentStep, onBack: _prevStep),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
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
    final p = CP(true);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
      child: Row(
        children: [
          _GlassIconButton(
            icon: AppIcons.back,
            onTap: onBack,
            p: p,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: List.generate(3, (i) {
                final isActive = i <= currentStep;
                final isCurrent = i == currentStep;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: isActive ? p.accent : p.border,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: p.accent.withValues(alpha: 0.55),
                                blurRadius: 10,
                                spreadRadius: -1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: p.border),
            ),
            child: Text(
              '${currentStep + 1}/3',
              style: cjak(p, size: 12, weight: FontWeight.w700, color: p.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    required this.p,
  });

  final IconData icon;
  final VoidCallback onTap;
  final CP p;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: Icon(icon, color: p.text, size: 24),
        ),
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
    final p = CP(true);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Stack(
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
                      // Pastdan navy gradient — matn yaqinligida chuqurlik.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  p.bg.withValues(alpha: 0.45),
                                ],
                                stops: const [0.55, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: SubjectBadge(
                          label: contest.soha,
                          color: contest.placeholderColor,
                          icon: contest.placeholderIcon,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    contest.title,
                    style: cjak(p,
                        size: 26,
                        weight: FontWeight.w800,
                        color: p.text,
                        height: 1.15),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    contest.description,
                    style: cjak(p,
                        size: 14, color: p.muted, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  _StatGroup(
                    p: p,
                    rows: [
                      _StatData(AppIcons.star, 'Sovrin',
                          '${contest.bonus} ball', p.gold),
                      _StatData(Icons.help_outline_rounded, 'Savollar soni',
                          '${contest.savollarSoni} ta', p.accent),
                      _StatData(AppIcons.schedule, 'Vaqt chegarasi',
                          '${contest.vaqtChegarasiDaq} daqiqa', p.warn),
                      _StatData(Icons.people_alt_rounded, 'Ishtirokchilar',
                          '${contest.ishtirokchilarSoni} ta', p.accentSoft),
                      _StatData(Icons.event_rounded, 'Tugash vaqti',
                          contest.remainingFormatted, p.danger),
                    ],
                  ),
                  const SizedBox(height: 28),
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  contest.placeholderColor,
                  contest.placeholderColor.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ),
        Center(
          child: Icon(
            contest.placeholderIcon,
            color: Colors.white.withValues(alpha: 0.9),
            size: 80,
          ),
        ),
      ],
    );
  }
}

class _StatData {
  const _StatData(this.icon, this.label, this.value, this.color);
  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

/// Stat qatorlari — bitta glass kartada, ichida nozik ajratgich.
class _StatGroup extends StatelessWidget {
  const _StatGroup({required this.p, required this.rows});

  final CP p;
  final List<_StatData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _statRow(rows[i]),
            if (i != rows.length - 1)
              Divider(color: p.border, height: 1, thickness: 1),
          ],
        ],
      ),
    );
  }

  Widget _statRow(_StatData d) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: d.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(d.icon, color: d.color, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              d.label,
              style: cjak(p, size: 14, color: p.muted),
            ),
          ),
          Text(
            d.value,
            style: cjak(p, size: 15, weight: FontWeight.w700, color: p.text),
          ),
        ],
      ),
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
      description: "Halol javob bering, boshqalardan yordam so'ramang",
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
    final p = CP(true);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Konkurs qoidalari',
                    style: cjak(p,
                        size: 26, weight: FontWeight.w800, color: p.text),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Konkurs boshlanishidan oldin qoidalar bilan tanishib chiqing',
                    style: cjak(p, size: 14, color: p.muted, height: 1.5),
                  ),
                  const SizedBox(height: 22),
                  for (final rule in _rules) _RuleCard(rule: rule, p: p),
                  const SizedBox(height: 28),
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
  const _RuleCard({required this.rule, required this.p});

  final _Rule rule;
  final CP p;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: rule.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(rule.icon, color: rule.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.title,
                  style: cjak(p,
                      size: 16, weight: FontWeight.w700, color: p.text),
                ),
                const SizedBox(height: 4),
                Text(
                  rule.description,
                  style: cjak(p, size: 13, color: p.muted, height: 1.45),
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

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    final p = CP(true);
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
                      final t = _pulseController.value;
                      final scale = 1.0 + (t * 0.08);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: p.accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: p.accent.withValues(alpha: 0.30),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 124,
                              height: 124,
                              decoration: BoxDecoration(
                                color: p.accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: p.accent
                                        .withValues(alpha: 0.35 + t * 0.25),
                                    blurRadius: 30 + t * 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                AppIcons.trophy,
                                color: p.onAccent,
                                size: 62,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Tayyormisiz?',
                    style: cjak(p,
                        size: 34, weight: FontWeight.w800, color: p.text),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Konkurs boshlangach to'xtatib bo'lmaydi.\nMuvaffaqiyat tilaymiz!",
                      textAlign: TextAlign.center,
                      style: cjak(p, size: 15, color: p.muted, height: 1.55),
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
    final p = CP(true);
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
              decoration: BoxDecoration(
                color: p.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: p.accent.withValues(alpha: 0.45),
                    blurRadius: 48,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$countdown',
                  style: cjak(p,
                      size: 100, weight: FontWeight.w800, color: p.onAccent),
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
    final p = CP(true);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: p.accent.withValues(alpha: big ? 0.45 : 0.30),
                blurRadius: big ? 24 : 16,
                spreadRadius: -2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: big ? 19 : 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Text(
              label,
              style: cjak(p,
                  size: big ? 18 : 16,
                  weight: big ? FontWeight.w800 : FontWeight.w700,
                  color: p.onAccent,
                  spacing: big ? 1.4 : 0.2),
            ),
          ),
        ),
      ),
    );
  }
}
