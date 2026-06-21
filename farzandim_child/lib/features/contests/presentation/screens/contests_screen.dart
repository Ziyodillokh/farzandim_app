// ─────────────────────────────────────────────────────────────────────
// ContestsScreen — Konkurslar "Parvoz Premium" (Stitch dizayn, REAL data)
// ─────────────────────────────────────────────────────────────────────
//
// Deep navy fon, "Konkurslar" sarlavha + subtitle + "Reyting" link,
// Aktiv/Yakunlangan segmented tab, rasm-tepa glass kartalar.
// Backend (backendContestsProvider + active/finished) o'zi ulanib turadi.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/presentation/contests_theme.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/contest_card.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/contests_tabs.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ContestsScreen extends ConsumerWidget {
  const ContestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = CP(context.adaptive.isDark);
    final activeTab = ref.watch(contestsActiveTabProvider);
    final active = ref.watch(activeContestsProvider);
    final finished = ref.watch(finishedContestsProvider);
    final loading = ref.watch(contestsLoadingProvider);
    final hasError = ref.watch(contestsErrorProvider);

    return Scaffold(
      backgroundColor: p.bg,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Konkurslar', style: cjak(p, size: 26, weight: FontWeight.w800, spacing: -0.5)),
                        const SizedBox(height: 2),
                        Text('Bilimingni sina, sovrin yut',
                            style: cjak(p, size: 14, weight: FontWeight.w400, color: p.muted)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/ranking'),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: p.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: p.accent.withValues(alpha: 0.30)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.leaderboard_rounded, color: p.accent, size: 17),
                          const SizedBox(width: 5),
                          Text('Reyting', style: cjak(p, size: 13, weight: FontWeight.w700, color: p.accent)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const ContestsTabs(),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: loading
                  ? Center(child: CircularProgressIndicator(color: p.accent))
                  : hasError
                      ? _ErrorState(p: p, onRetry: () => ref.invalidate(backendContestsProvider))
                      : _List(p: p, contests: activeTab == 0 ? active : finished, isActive: activeTab == 0),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ChildBottomNavigation(),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.p, required this.contests, required this.isActive});
  final CP p;
  final List<ContestModel> contests;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    if (contests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.card,
                  border: Border.all(color: p.border),
                ),
                child: Icon(isActive ? Icons.emoji_events_rounded : Icons.history_rounded,
                    size: 38, color: p.accent.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 18),
              Text(
                isActive ? "Hozircha aktiv konkurs yo'q" : "Hozircha yakunlangan konkurs yo'q",
                textAlign: TextAlign.center,
                style: cjak(p, size: 15, weight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                isActive ? 'Tez orada yangi konkurslar qo\'shiladi' : 'Yangi konkurslarda qatnashing',
                textAlign: TextAlign.center,
                style: cjak(p, size: 13, weight: FontWeight.w400, color: p.muted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
      itemCount: contests.length,
      itemBuilder: (_, i) => ContestCard(contest: contests[i]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.p, required this.onRetry});
  final CP p;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: p.muted),
            const SizedBox(height: 16),
            Text("Konkurslarni yuklab bo'lmadi",
                textAlign: TextAlign.center, style: cjak(p, size: 15, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Internet aloqasini tekshiring',
                textAlign: TextAlign.center, style: cjak(p, size: 13, weight: FontWeight.w400, color: p.muted)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(99)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: p.onAccent, size: 18),
                    const SizedBox(width: 6),
                    Text('Qayta urinish', style: cjak(p, size: 14, weight: FontWeight.w700, color: p.onAccent)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
