import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_shadows.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Asosiy harakat tugmasi — lime green pill.
///
/// PDF dizayni bo'yicha: 56dp baland, pill (radius 999), lime green fon,
/// qora matn (weight 600, 16sp), tap effect (Material InkWell).
///
/// Ixtiyoriy parametrlar:
/// - [icon]: matn chap tomonida 20dp ikonka qo'shadi
/// - [isLoading]: matn o'rnida CircularProgressIndicator + tap bloklash
/// - [expanded]: `false` bo'lsa kontent o'lchamida (default: full width)
///
/// Foydalanish:
/// ```dart
/// PrimaryButton(
///   label: "Ro'yxatdan o'tish",
///   onPressed: () => context.go(AppRoutes.signUp),
/// )
///
/// // Ikonka + shrink-wrap (empty state karta uchun):
/// PrimaryButton(
///   label: "Yangi bola qo'shish",
///   icon: SolarIconsBold.addCircle,
///   expanded: false,
///   onPressed: () => context.push(AppRoutes.addChild),
/// )
///
/// // Async harakat bilan loading:
/// PrimaryButton(
///   label: 'Kod yuborish',
///   onPressed: _isFormValid ? _onSendCode : null,
///   isLoading: _isLoading,
/// )
/// ```
class PrimaryButton extends StatelessWidget {
  /// `PrimaryButton` konstruktor.
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
  });

  /// Tugma ichidagi matn.
  final String label;

  /// Bosilganda chaqiriladi. `null` bo'lsa tugma disabled holatga o'tadi.
  final VoidCallback? onPressed;

  /// Ixtiyoriy ikonka — matn chap tomonida 20dp o'lchamda ko'rsatiladi.
  final IconData? icon;

  /// `true` bo'lsa, matn o'rnida loading spinner ko'rsatiladi va tap
  /// bloklanadi. Fon hali lime green — "ishlayotgan" hissi.
  final bool isLoading;

  /// `true` (default) bo'lsa tugma to'liq kenglikda. `false` bo'lsa
  /// kontent o'lchamiga shrink qiladi (masalan, empty state karta'larda).
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    final borderRadius = BorderRadius.circular(AppDimensions.radiusPill);

    return SizedBox(
      // null = "tabiiy o'lcham" → kontent + padding kenglikda.
      width: expanded ? double.infinity : null,
      height: AppDimensions.buttonHeight,
      child: DecoratedBox(
        // Premium: enabled holatda lime ostida nozik brand glow — CTA bo'rtadi.
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: isDisabled ? null : AppShadows.glow(AppColors.primary),
        ),
        child: Material(
          color: isDisabled ? AppColors.surfaceVariant : AppColors.primary,
          borderRadius: borderRadius,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: borderRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
              child: Center(
                // expanded=false paytda Center kontentga teng kenglik oladi.
                widthFactor: expanded ? null : 1,
                child: _buildContent(isDisabled),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDisabled) {
    if (isLoading) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          // Lime green fonda qora spinner — eng yuqori kontrast.
          color: AppColors.onPrimary,
        ),
      );
    }

    final textColor = isDisabled ? AppColors.textTertiary : AppColors.onPrimary;
    final textWidget = Text(
      label,
      style: AppTextStyles.bodyM.copyWith(
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    );

    if (icon == null) return textWidget;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: textColor),
        const SizedBox(width: AppDimensions.sm),
        textWidget,
      ],
    );
  }
}
