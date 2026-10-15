// "So‘nggi natijalar" — ixcham qator: ikon, o'rtacha natija, bezak ustunlar.
// Bosilsa Rivojlanish sahifasi ochiladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_icons.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _rowBg = Color(0xFF0A1017);
const _squareTop = Color(0xFF0E3D7A);
const _squareBottom = Color(0xFF0A2A50);

/// Bezak ustunlari: balandlik (pt) va rang — chapdan o'ngga yorishadi.
const _bars = <(double, Color)>[
  (9, Color(0xFF0D2136)),
  (14, Color(0xFF102D4E)),
  (23, Color(0xFF10375F)),
  (16.5, Color(0xFF1C62AC)),
  (31, Color(0xFF2A84DF)),
];

class ResultsSummaryRow extends ConsumerWidget {
  const ResultsSummaryRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(learningSummaryProvider);
    if (!summary.hasResults) return const SizedBox.shrink();

    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => context.push('/progress'),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 66,
          padding: const EdgeInsets.only(left: 12, right: 11),
          decoration: BoxDecoration(
            color: _rowBg,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: HomeColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 43.5,
                height: 43.5,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1F7FB2FF)),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_squareTop, _squareBottom],
                  ),
                ),
                child: const HomeSvgIcon(homeBarsSvg, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'home.recentResults'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: homeDisplay(14.5, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'tests.averageResult'.tr(
                        namedArgs: {'percent': '${summary.averagePercent}'},
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: homeText(10.8, color: HomeColors.textDim),
                    ),
                  ],
                ),
              ),
              const _MiniBars(),
              const SizedBox(width: 22),
              const Icon(
                Icons.chevron_right_rounded,
                size: 26,
                color: HomeColors.chevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBars extends StatelessWidget {
  const _MiniBars();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _bars.length; i++) ...[
            if (i > 0) const SizedBox(width: 4.6),
            Container(
              width: 5,
              height: _bars[i].$1,
              decoration: BoxDecoration(
                color: _bars[i].$2,
                borderRadius: BorderRadius.circular(3),
                boxShadow: i == _bars.length - 1
                    ? [
                        BoxShadow(
                          color: _bars[i].$2.withValues(alpha: 0.6),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
