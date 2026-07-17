// ─────────────────────────────────────────────────────────────────────
// LikedTestsScreen — "Sevimli testlar" (Testlar header ♡)
// ─────────────────────────────────────────────────────────────────────
//
// Sevimliga olingan testlar (lokal) 2 ustunli grid. Testni bosib turish →
// olib tashlaydi. Faol test → /contest-start, yakunlangan → snackbar.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/test_card.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/test_conditions_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LikedTestsScreen extends ConsumerWidget {
  const LikedTestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteContestsProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final ts = MediaQuery.textScalerOf(context);
    final cardExtent = (150 * ts.scale(1)).clamp(150.0, 214.0);

    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tGlass,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'contests.likedTestsTitle'.tr(),
                          maxLines: 1,
                          style: tUnb(20, w: FontWeight.w600, ls: -0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: favorites.isEmpty
                  ? _empty()
                  : GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + bottomInset),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: cardExtent,
                      ),
                      itemCount: favorites.length,
                      itemBuilder: (_, i) {
                        final c = favorites[i];
                        return TestCard(
                          contest: c,
                          onTap: () => _openTest(context, c),
                          onLongPress: () => _unfavorite(context, ref, c),
                          isFavorite: true,
                          onFavoriteTap: () => _unfavorite(context, ref, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tGlass,
              border: Border.all(color: tGlassBorder),
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              size: 38,
              color: tBlue.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'contests.likedTestsEmptyTitle'.tr(),
            textAlign: TextAlign.center,
            style: tUnb(17, w: FontWeight.w600, ls: -0.4),
          ),
          const SizedBox(height: 6),
          Text(
            'contests.likedTestsEmptySubtitle'.tr(),
            textAlign: TextAlign.center,
            style: tPop(13, c: tMuted),
          ),
        ],
      ),
    );
  }

  void _openTest(BuildContext context, ContestModel c) {
    if (c.isActive) {
      HapticFeedback.selectionClick();
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

  Future<void> _unfavorite(
    BuildContext context,
    WidgetRef ref,
    ContestModel c,
  ) async {
    await ref.read(favoriteContestsProvider.notifier).toggle(c);
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
            'Sevimlilardan olib tashlandi',
            style: tPop(13, w: FontWeight.w500),
          ),
        ),
      );
  }
}
