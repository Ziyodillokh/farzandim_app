import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Ijtimoiy tarmoq orqali kirish tugmasi (Apple, Google va h.k.).
///
/// SVG fayli logo + brand matnini birga ko'rsatadi (masalan, "Apple" yoki
/// "Google" yozuvi bilan), shuning uchun SocialButton alohida `label` matn
/// olmaydi — faqat SVG'ni markazda ko'rsatadi.
///
/// `onPressed` null bo'lsa, tugma o'chiriladi (loading paytida ishlatiladi).
/// Haqiqiy auth chaqiruvi `onPressed` ichida bo'ladi — bu yerda artificial
/// loading kechikishi yo'q.
class SocialButton extends StatelessWidget {
  /// `SocialButton` konstruktor.
  const SocialButton({
    required this.iconAsset,
    required this.semanticsLabel,
    required this.onPressed,
    super.key,
  });

  /// SVG fayl yo'li (masalan, `'assets/icons/ic_apple.svg'`).
  final String iconAsset;

  /// Ekran o'qish dasturlari (screen reader) uchun matn — masalan,
  /// "Apple bilan kirish". Vizual ko'rinmaydi.
  final String semanticsLabel;

  /// Bosilganda chaqiriladi. `null` bo'lsa tugma o'chiriladi (disabled).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppDimensions.radiusPill);
    final disabled = onPressed == null;
    return SizedBox(
      height: AppDimensions.buttonHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: borderRadius,
        ),
        child: Opacity(
          opacity: disabled ? 0.6 : 1.0,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              borderRadius: borderRadius,
              child: Center(
                child: SvgPicture.asset(
                  iconAsset,
                  height: 24,
                  semanticsLabel: semanticsLabel,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
