import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Ikkilamchi tugma — Welcome ekran kabi rasm fonli yoki dark fon
/// ekranlarda ishlatamiz.
///
/// Spec: 56dp baland, pill (radius 999), qora-shaffof fon (rgba 0,0,0,0.4),
/// 1dp oq border (Colors.white24), oq matn (weight 500, 16sp).
///
/// Ixtiyoriy parametrlar:
/// - [icon]: bo'lsa, matn chap tomonida 24dp ikonka ko'rsatiladi
/// - [isLoading]: `true` bo'lsa, matn o'rnida CircularProgressIndicator
///
/// Foydalanish:
/// ```dart
/// SecondaryButton(
///   label: 'Akkauntga kirish',
///   onPressed: () => context.go(AppRoutes.signIn),
/// )
///
/// // Loading bilan, ikonka bilan:
/// SecondaryButton(
///   label: "Akkauntga qo'shish",
///   icon: Icons.qr_code_2,
///   isLoading: _isLoading,
///   onPressed: _isLoading ? null : _onAdd,
/// )
/// ```
class SecondaryButton extends StatelessWidget {
  /// `SecondaryButton` konstruktor.
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isLoading = false,
  });

  /// Tugma ichidagi matn.
  final String label;

  /// Bosilganda chaqiriladi. `null` bo'lsa tugma disabled holatga o'tadi.
  final VoidCallback? onPressed;

  /// Ixtiyoriy ikonka — matn chap tomonida ko'rsatiladi.
  final IconData? icon;

  /// `true` bo'lsa, matn o'rnida loading spinner ko'rsatiladi va tap
  /// bloklanadi.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    final borderRadius = BorderRadius.circular(AppDimensions.radiusPill);

    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Qora-shaffof fon — rasm orqali yarim ko'rinadi.
          color: const Color(0x66000000),
          border: Border.all(color: Colors.white24),
          borderRadius: borderRadius,
        ),
        child: Material(
          // DecoratedBox o'z foniga ega — Material shaffof bo'lishi shart.
          type: MaterialType.transparency,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: borderRadius,
            child: Center(child: _buildContent(isDisabled)),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDisabled) {
    if (isLoading) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.textPrimary,
        ),
      );
    }

    final textColor =
        isDisabled ? AppColors.textTertiary : AppColors.textPrimary;
    final textWidget = Text(
      label,
      style: AppTextStyles.bodyM.copyWith(
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
    );

    if (icon == null) return textWidget;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppDimensions.iconM, color: textColor),
        const SizedBox(width: AppDimensions.sm),
        textWidget,
      ],
    );
  }
}
