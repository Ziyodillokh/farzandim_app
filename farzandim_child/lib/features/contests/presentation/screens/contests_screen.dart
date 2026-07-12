// ─────────────────────────────────────────────────────────────────────
// ContestsScreen — "Testlar" (Parvoz dark redizayn, Figma "Testlar")
// ─────────────────────────────────────────────────────────────────────
//
// Header ("Testlar" + ♡ sevimlilar) + hero (featured test, "Batafsil") +
// 2 ustunli grid (soha ikoni + "N DON" + sarlavha + "N ta test"). Real
// backend (/api/content/olympiads). Kartani bosib turish → sevimlilarga.
// Faol test → /contest-start, yakunlangan → snackbar.

import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/test_banner_carousel.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/test_card.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/test_conditions_sheet.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ContestsScreen extends ConsumerWidget {
  const ContestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tests = ref.watch(allTestsProvider);
    // Tepadagi banner karuseli — faqat FAOL testlar (o'tib turadi).
    final activeTests = ref.watch(activeContestsProvider);
    // Sevimli ID'lar — kartadagi ♡ holatini reaktiv ko'rsatish uchun.
    final favIds = ref.watch(favoriteContestsProvider).map((c) => c.id).toSet();
    final loading = ref.watch(contestsLoadingProvider) && tests.isEmpty;
    final hasError = ref.watch(contestsErrorProvider) && tests.isEmpty;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final ts = MediaQuery.textScalerOf(context);
    final cardExtent = (150 * ts.scale(1)).clamp(150.0, 214.0);

    Widget content;
    if (loading) {
      content = const _ScrollCenter(
        child: CircularProgressIndicator(color: tBlue),
      );
    } else if (hasError) {
      content = _ScrollCenter(
        child: _EmptyBox(
          icon: Icons.wifi_off_rounded,
          title: "Testlarni yuklab bo'lmadi",
          subtitle: 'Internetni tekshirib, qayta torting',
        ),
      );
    } else if (tests.isEmpty) {
      content = const _ScrollCenter(
        child: _EmptyBox(
          icon: Icons.fact_check_outlined,
          title: "Hozircha test yo'q",
          subtitle: 'Tez orada yangi testlar qo\'shiladi',
        ),
      );
    } else {
      content = CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (activeTests.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 2, 0, 18),
                child: TestBannerCarousel(
                  tests: activeTests,
                  onTap: (t) => _openTest(context, t),
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 130 + bottomInset),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: cardExtent,
              ),
              delegate: SliverChildBuilderDelegate((_, i) {
                final c = tests[i];
                return TestCard(
                  contest: c,
                  onTap: () => _openTest(context, c),
                  onLongPress: () => _toggleFavorite(context, ref, c),
                  isFavorite: favIds.contains(c.id),
                  onFavoriteTap: () => _toggleFavorite(context, ref, c),
                );
              }, childCount: tests.length),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: tBg,
      extendBody: true,
      bottomNavigationBar: const ChildBottomNavigation(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Testlar',
                          maxLines: 1,
                          style: tUnb(28, w: FontWeight.w600, ls: -0.84),
                        ),
                      ),
                    ),
                  ),
                  _CircleIconButton(
                    icon: Icons.favorite_rounded,
                    onTap: () => context.push('/liked-tests'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                color: tBlue,
                backgroundColor: const Color(0xFF0E141C),
                onRefresh: () async {
                  ref.invalidate(backendContestsProvider);
                  await ref.read(backendContestsProvider.future);
                },
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTest(BuildContext context, ContestModel c) {
    if (c.isActive) {
      HapticFeedback.selectionClick();
      // "Konkurs shartlari" sheet → Boshlash → quiz (tanlangan qiyinlik bilan).
      showTestConditionsSheet(
        context,
        c,
        (contest) => context.push('/contest-quiz', extra: contest),
      );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF0E141C),
            duration: Duration(milliseconds: 1600),
            content: Text('Bu test yakunlangan — natijalar Reytingda'),
          ),
        );
    }
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    ContestModel c,
  ) async {
    final added = await ref.read(favoriteContestsProvider.notifier).toggle(c);
    await HapticFeedback.mediumImpact();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF0E141C),
          duration: const Duration(milliseconds: 1400),
          content: Text(
            added ? 'Sevimlilarga qo\'shildi' : 'Sevimlilardan olib tashlandi',
            style: tPop(13, w: FontWeight.w500),
          ),
        ),
      );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(color: tGlass, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

// ════════════ Bo'sh / xato holat (scroll qilinadigan) ════════════

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tGlass,
              border: Border.all(color: tGlassBorder),
            ),
            child: Icon(icon, size: 38, color: tBlue.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: tUnb(17, w: FontWeight.w600, ls: -0.4),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: tPop(13, c: tMuted),
          ),
        ],
      ),
    );
  }
}

class _ScrollCenter extends StatelessWidget {
  const _ScrollCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
