// Bosh sahifa — 3 ta stat karta: ketma-ket kunlar, yechilgan savollar, DON.
//
// Streak va DON — REAL (backend `ChildProfile`, WS orqali jonli). Yechilgan
// savollar — Daily Learning xulosasidan (hozircha preview, qarang
// `learning_providers.dart`).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

/// Minglik ajratgich bilan (1 250).
String formatHomeNumber(int value) {
  final s = value.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

class HomeStatCards extends ConsumerWidget {
  const HomeStatCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // DON/streak — haqiqiy manba backend (Firestore profili faqat zaxira).
    final backend = ref.watch(backendGamificationProvider).valueOrNull;
    final profile = ref.watch(gamificationProfileProvider).valueOrNull;
    final streak = backend?.streak ?? profile?.streak ?? 0;
    final don = backend?.don ?? profile?.don ?? 0;
    final solved = ref.watch(learningSummaryProvider).solvedQuestions;

    return GestureDetector(
      onTap: () => context.push('/statistics'),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              glow: HomeColors.amber,
              icon: SolarIconsBold.fire,
              iconColor: HomeColors.amber,
              value: 'statistics.daysCount'.tr(namedArgs: {'days': '$streak'}),
              label: 'home.streak'.tr(),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _StatCard(
              glow: HomeColors.blue,
              icon: SolarIconsBold.fileText,
              iconColor: HomeColors.blue,
              value: formatHomeNumber(solved),
              label: 'home.solved'.tr(),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _StatCard(
              glow: HomeColors.green,
              icon: SolarIconsBold.dollar,
              iconColor: HomeColors.green,
              value: formatHomeNumber(don),
              label: 'home.balance'.tr(),
              trailing: const DonBadge(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.glow,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.trailing,
  });

  final Color glow;
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Widget? trailing;

  /// Maketdagi balandlik (shrift masshtabi 1.0 da).
  static const _baseHeight = 90.0;

  /// Qiymat + yorliq matn bloki balandligi (masshtab 1.0 da): 16×1.1 + 3 +
  /// 10.2×1.2. Katta shrift masshtabida karta shu farqqa o'sadi.
  static const _textBlock = 17.5 * 1.1 + 3 + 12 * 1.2;

  @override
  Widget build(BuildContext context) {
    final scaled = MediaQuery.textScalerOf(context).scale(_textBlock);
    return Container(
      height: _baseHeight + (scaled - _textBlock).clamp(0, 60),
      clipBehavior: Clip.antiAlias,
      decoration: homeCardDecoration(radius: 18),
      child: Stack(
        children: [
          // Rangli glow: kuchli — pastki-o'ngda, yengil — ikon ortida.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.85, -0.9),
                  radius: 0.6,
                  colors: [
                    glow.withValues(alpha: 0.16),
                    glow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1.05, 1.15),
                  radius: 0.85,
                  colors: [
                    glow.withValues(alpha: 0.42),
                    glow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 25, color: iconColor),
                const Spacer(),
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          maxLines: 1,
                          style: homeDisplay(
                            17.5,
                            height: 1.1,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 5),
                      trailing!,
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                FitText(
                  label,
                  style: homeText(12, color: HomeColors.textDim, height: 1.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "DON" — ko'k pill belgi (balans va mukofotlar yonida).
class DonBadge extends StatelessWidget {
  const DonBadge({super.key, this.fontSize = 9.5});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.75,
        vertical: fontSize * 0.2,
      ),
      decoration: BoxDecoration(
        color: HomeColors.donBadge,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'DON',
        style: homeText(fontSize, weight: FontWeight.w800, height: 1.25),
      ),
    );
  }
}
