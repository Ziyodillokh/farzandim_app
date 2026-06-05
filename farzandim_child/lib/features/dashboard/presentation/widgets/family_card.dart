// ─────────────────────────────────────────────────────────────────────
// FamilyCard — "Mening oilam" kartasi (real ota ma'lumoti)
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FamilyCard extends StatelessWidget {
  const FamilyCard({required this.parentInfo, super.key});

  final AsyncValue<Map<String, dynamic>?> parentInfo;

  String _parentLabel() {
    return parentInfo.when(
      data: (data) {
        if (data == null) return 'dashboard.familyFallback'.tr();
        final name = data['displayName'] as String?;
        if (name != null && name.isNotEmpty) return name;
        final email = data['email'] as String?;
        if (email != null && email.isNotEmpty) return email;
        return 'dashboard.familyFallback'.tr();
      },
      loading: () => 'dashboard.familyLoading'.tr(),
      error: (_, __) => 'dashboard.familyFallback'.tr(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'dashboard.familyTitle'.tr(),
          style: TextStyle(
            color: context.adaptive.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.adaptive.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.adaptive.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.family_restroom_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'dashboard.familyParentLabel'.tr(),
                      style: TextStyle(
                        color: context.adaptive.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _parentLabel(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.adaptive.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: AppColors.success, size: 8),
                    const SizedBox(width: 6),
                    Text(
                      'dashboard.familyConnected'.tr(),
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
