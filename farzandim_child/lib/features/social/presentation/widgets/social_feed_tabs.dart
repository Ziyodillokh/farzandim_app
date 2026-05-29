// ─────────────────────────────────────────────────────────────────────
// SocialFeedTabs — "Following" / "Siz uchun" (PDF p18)
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/social/presentation/providers/social_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SocialFeedTabs extends ConsumerWidget {
  const SocialFeedTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(socialFeedTabProvider);

    return Row(
      children: [
        _Tab(
          label: 'social.tabFollowing'.tr(),
          isActive: active == SocialFeedTab.following,
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(socialFeedTabProvider.notifier).state =
                SocialFeedTab.following;
          },
        ),
        const SizedBox(width: 24),
        _Tab(
          label: 'social.tabForYou'.tr(),
          isActive: active == SocialFeedTab.forYou,
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(socialFeedTabProvider.notifier).state =
                SocialFeedTab.forYou;
          },
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: 36,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
