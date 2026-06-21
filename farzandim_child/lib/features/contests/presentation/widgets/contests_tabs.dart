// ─────────────────────────────────────────────────────────────────────
// ContestsTabs — Aktiv/Yakunlangan segmented control (Stitch "Parvoz")
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/contests/presentation/contests_theme.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ContestsTabs extends ConsumerWidget {
  const ContestsTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = CP(context.adaptive.isDark);
    final activeTab = ref.watch(contestsActiveTabProvider);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.tabBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(child: _Tab(p: p, index: 0, label: 'Aktiv', active: activeTab == 0)),
          Expanded(child: _Tab(p: p, index: 1, label: 'Yakunlangan', active: activeTab == 1)),
        ],
      ),
    );
  }
}

class _Tab extends ConsumerWidget {
  const _Tab({required this.p, required this.index, required this.label, required this.active});
  final CP p;
  final int index;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(contestsActiveTabProvider.notifier).state = index;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? p.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: active
              ? [BoxShadow(color: p.accent.withValues(alpha: 0.35), blurRadius: 16, spreadRadius: -2)]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: cjak(p, size: 13.5, weight: FontWeight.w700, color: active ? p.onAccent : p.muted),
        ),
      ),
    );
  }
}
