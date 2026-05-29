// ─────────────────────────────────────────────────────────────────────
// AudiobooksSearchBar — qidirish field
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudiobooksSearchBar extends ConsumerWidget {
  const AudiobooksSearchBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: TextField(
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Audiokitob qidirish...',
            hintStyle: TextStyle(color: AppColors.textTertiary),
            prefixIcon:
                Icon(Icons.search, color: AppColors.textSecondary),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (value) {
            ref.read(audiobookSearchQueryProvider.notifier).state = value;
          },
        ),
      ),
    );
  }
}
