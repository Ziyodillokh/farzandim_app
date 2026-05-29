// ─────────────────────────────────────────────────────────────────────
// VideoFilterBottomSheet — 4 ta sectionli filter modal
// ─────────────────────────────────────────────────────────────────────
//
// Soha / Yo'nalish / Fan — multi-select chip'lar.
// Yosh — single-select chip (qayta bossa olib tashlanadi).
// "Tozalash" — local state'ni reset, "Qo'llash" — provider'ga yozadi.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/videos/data/filter_options.dart';
import 'package:farzandim_child/features/videos/data/models/filter_state.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VideoFilterBottomSheet extends ConsumerStatefulWidget {
  const VideoFilterBottomSheet({super.key});

  @override
  ConsumerState<VideoFilterBottomSheet> createState() =>
      _VideoFilterBottomSheetState();
}

class _VideoFilterBottomSheetState
    extends ConsumerState<VideoFilterBottomSheet> {
  late VideoFilterState _localFilter;

  @override
  void initState() {
    super.initState();
    _localFilter = ref.read(videoFilterProvider);
  }

  void _toggleMulti(List<String> currentList, String item,
      VideoFilterState Function(List<String>) build) {
    final list = [...currentList];
    if (list.contains(item)) {
      list.remove(item);
    } else {
      list.add(item);
    }
    setState(() => _localFilter = build(list));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'videos.filter.title'.tr(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(AppIcons.close,
                          color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _section(
                      title: 'videos.filter.soha'.tr(),
                      options: FilterOptions.sohalar,
                      selected: _localFilter.sohalar,
                      onToggle: (item) => _toggleMulti(
                        _localFilter.sohalar,
                        item,
                        (list) =>
                            _localFilter.copyWith(sohalar: list),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _section(
                      title: 'videos.filter.yonalish'.tr(),
                      options: FilterOptions.yonalishlar,
                      selected: _localFilter.yonalishlar,
                      onToggle: (item) => _toggleMulti(
                        _localFilter.yonalishlar,
                        item,
                        (list) =>
                            _localFilter.copyWith(yonalishlar: list),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _section(
                      title: 'videos.filter.fan'.tr(),
                      options: FilterOptions.fanlar,
                      selected: _localFilter.fanlar,
                      onToggle: (item) => _toggleMulti(
                        _localFilter.fanlar,
                        item,
                        (list) =>
                            _localFilter.copyWith(fanlar: list),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ageSection(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _localFilter = const VideoFilterState();
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          side: const BorderSide(
                              color: AppColors.border),
                        ),
                        child: Text(
                          'videos.filter.clear'.tr(),
                          style: const TextStyle(
                              color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          ref
                              .read(videoFilterProvider.notifier)
                              .state = _localFilter;
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          'videos.filter.apply'.tr(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _section({
    required String title,
    required List<String> options,
    required List<String> selected,
    required void Function(String) onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return _Chip(
              label: option,
              isSelected: isSelected,
              onTap: () => onToggle(option),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _ageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'videos.filter.yosh'.tr(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: FilterOptions.yoshGuruhlari.map((age) {
            final isSelected = _localFilter.yoshGuruhi == age;
            return _Chip(
              label: age,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _localFilter =
                        _localFilter.copyWith(clearYosh: true);
                  } else {
                    _localFilter =
                        _localFilter.copyWith(yoshGuruhi: age);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.textPrimary,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
