// ─────────────────────────────────────────────────────────────────────
// AudiobooksSearchBar — qidirish field
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
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
          color: context.adaptive.bgCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.adaptive.border, width: 0.5),
        ),
        child: TextField(
          style: TextStyle(color: context.adaptive.textPrimary),
          decoration: InputDecoration(
            hintText: 'audiobooks.searchBarHint'.tr(),
            hintStyle: TextStyle(color: context.adaptive.textTertiary),
            prefixIcon: Icon(
              Icons.search,
              color: context.adaptive.textSecondary,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (value) {
            ref.read(audiobookSearchQueryProvider.notifier).state = value;
          },
        ),
      ),
    );
  }
}
