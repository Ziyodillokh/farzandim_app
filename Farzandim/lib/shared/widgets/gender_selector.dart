import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Bola jinsi tanlash widget'i — yonma-yon ikkita pill tugma.
///
/// **Controlled widget:** ichki state yo'q — `selected` parametri parent
/// tomonidan boshqariladi (`setState` yoki Riverpod orqali).
///
/// Foydalanish:
/// ```dart
/// GenderSelector(
///   selected: _selectedGender,                          // Gender?
///   onChanged: (g) => setState(() => _selectedGender = g),
/// )
/// ```
///
/// Vizual:
/// - **Tanlangan:** lime green fon, qora matn (w600), filled gender icon
/// - **Tanlanmagan:** surface fon, oq matn (w500), border bilan
class GenderSelector extends StatelessWidget {
  /// `GenderSelector` konstruktor.
  const GenderSelector({required this.onChanged, super.key, this.selected});

  /// Joriy tanlangan jinsi. `null` bo'lsa ikkala tugma ham tanlanmagan
  /// holatida ko'rinadi.
  final Gender? selected;

  /// Foydalanuvchi tugma bossa chaqiriladi.
  final ValueChanged<Gender> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildOption(
            label: 'childManagement.addEdit.genderMale'.tr(),
            icon: SolarIconsBold.men,
            isSelected: selected == Gender.male,
            onTap: () => onChanged(Gender.male),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildOption(
            label: 'childManagement.addEdit.genderFemale'.tr(),
            icon: SolarIconsBold.women,
            isSelected: selected == Gender.female,
            onTap: () => onChanged(Gender.female),
          ),
        ),
      ],
    );
  }

  /// Bitta tugma uchun helper — ikki tugma bir xil tuzilishda, faqat
  /// label/ikonka/holati farq qiladi.
  Widget _buildOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final borderRadius = BorderRadius.circular(AppDimensions.radiusPill);
    // Lime green fonida DOIM qora matn (PrimaryButton uslubi).
    const selectedFg = AppColors.onPrimary;
    final fg = isSelected ? selectedFg : AppColors.textPrimary;

    return Material(
      color: isSelected ? AppColors.primary : AppColors.surface,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          height: AppDimensions.buttonHeight,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            // Tanlanmagan tugmaga border — fondan ajralib turishi uchun.
            border: isSelected ? null : Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: AppDimensions.sm),
              Text(
                label,
                style: AppTextStyles.bodyM.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
