import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Sozlamalar ekranidagi bo'lim — sarlavha + ichidagi tile'lar.
///
/// Yuqorida kichik sarlavha ("PROFIL", "BOLALAR", va h.k.) — group'larni
/// vizual ajratadi. Children list `surface` rangli yaxlit kontainer'da,
/// orasidagi separator chiziqlar avtomatik qo'shiladi.
class SettingsSection extends StatelessWidget {
  /// `SettingsSection` konstruktor.
  const SettingsSection({
    required this.title,
    required this.children,
    super.key,
  });

  /// Bo'lim sarlavhasi (kichik, weight 600, textSecondary).
  final String title;

  /// Bo'lim ichidagi widget'lar (odatda `SettingsTile` / `SettingsToggle`).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppDimensions.sm),
          child: Text(
            title,
            style: AppTextStyles.label.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(
                    height: 1,
                    color: AppColors.divider,
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
