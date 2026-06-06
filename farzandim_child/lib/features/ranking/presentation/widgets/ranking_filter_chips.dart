// ─────────────────────────────────────────────────────────────────────
// RankingFilterChips — Hudud / Yosh chip + bottom sheet pickers
// ─────────────────────────────────────────────────────────────────────
//
// Faqat tab Hudud yoki Yosh bo'lganda ko'rinadi. Tap → bottom sheet.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/constants/uzbekistan_regions.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/ranking/presentation/providers/ranking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RankingFilterChips extends ConsumerWidget {
  const RankingFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(rankingTabProvider);
    if (tab == RankingTab.umumiy) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (tab == RankingTab.hudud)
            Expanded(
              child: _FilterButton(
                icon: AppIcons.mapPin,
                text: ref.watch(selectedRegionProvider) ??
                    'Hududni tanlang',
                onTap: () => _openRegionPicker(context),
              ),
            ),
          if (tab == RankingTab.yoshGuruhi)
            Expanded(
              child: _FilterButton(
                icon: Icons.cake,
                text: ref.watch(selectedYoshGuruhiProvider) ??
                    'Yosh guruhini tanlang',
                onTap: () => _openYoshPicker(context),
              ),
            ),
        ],
      ),
    );
  }

  void _openRegionPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _RegionPicker(),
    );
  }

  void _openYoshPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _YoshPicker(),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.adaptive.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.adaptive.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.adaptive.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down,
                color: context.adaptive.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _RegionPicker extends ConsumerWidget {
  const _RegionPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedRegionProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Hududni tanlang',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: UzbekistanRegions.all.length,
                  separatorBuilder: (_, __) => const Divider(
                      color: AppColors.border, height: 1),
                  itemBuilder: (_, i) {
                    final region = UzbekistanRegions.all[i];
                    final isSelected = region == selected;

                    return ListTile(
                      title: Text(
                        region,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(AppIcons.check,
                              color: AppColors.primary)
                          : null,
                      onTap: () {
                        ref
                            .read(selectedRegionProvider.notifier)
                            .state = region;
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _YoshPicker extends ConsumerWidget {
  const _YoshPicker();

  static const List<String> _yoshGuruhlari = [
    '5-6',
    '7-9',
    '10-12',
    '13-15',
    '16-18',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedYoshGuruhiProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Yosh guruhi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            for (final yosh in _yoshGuruhlari)
              ListTile(
                title: Text(
                  '$yosh yosh',
                  style: const TextStyle(
                      color: AppColors.textPrimary),
                ),
                trailing: yosh == selected
                    ? const Icon(AppIcons.check,
                        color: AppColors.primary)
                    : null,
                onTap: () {
                  ref
                      .read(selectedYoshGuruhiProvider.notifier)
                      .state = yosh;
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
