// Test kartalari gridi (fan sahifasi va qidiruv uchun) — mavjud `TestCard`.
// Faol test → "Konkurs shartlari" → quiz; yakunlangan → xabar.
// ♡ / uzoq bosish → sevimlilar.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/test_card.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/test_conditions_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _snackBg = Color(0xFF0E141C);

/// Sliver ko'rinishidagi test gridi.
class SliverTestsGrid extends ConsumerWidget {
  const SliverTestsGrid({super.key, required this.tests});

  final List<ContestModel> tests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favIds = ref.watch(favoriteContestsProvider).map((c) => c.id).toSet();
    final ts = MediaQuery.textScalerOf(context);
    final extent = (150 * ts.scale(1)).clamp(150.0, 214.0);
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: extent,
      ),
      delegate: SliverChildBuilderDelegate((context, i) {
        final c = tests[i];
        return TestCard(
          contest: c,
          onTap: () => openTest(context, c),
          onLongPress: () => toggleFavoriteTest(context, ref, c),
          isFavorite: favIds.contains(c.id),
          onFavoriteTap: () => toggleFavoriteTest(context, ref, c),
        );
      }, childCount: tests.length),
    );
  }
}

/// Testni ochish: faol → shartlar oynasi → quiz; yakunlangan → xabar.
void openTest(BuildContext context, ContestModel c) {
  if (c.isActive) {
    HapticFeedback.selectionClick();
    showTestConditionsSheet(
      context,
      c,
      (contest) => context.push('/contest-quiz', extra: contest),
    );
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _snackBg,
        duration: const Duration(milliseconds: 1600),
        content: Text('contests.finishedSnack'.tr()),
      ),
    );
}

/// Sevimlilarga qo'shish/olib tashlash + xabar.
Future<void> toggleFavoriteTest(
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
        backgroundColor: _snackBg,
        duration: const Duration(milliseconds: 1400),
        content: Text(
          added ? 'contests.favAdded'.tr() : 'contests.favRemoved'.tr(),
        ),
      ),
    );
}
