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
/// Bosilganda 1500ms loading simulyatsiyasi ko'rsatadi (real auth
/// hissini beradi), keyin `onPressed` chaqiriladi. Bosqich 1.6'da
/// haqiqiy Apple/Google Sign In integratsiya qilinganda bu kechikish
/// olib tashlanadi.
class SocialButton extends StatefulWidget {
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

  /// 1500ms simulyatsiyadan **keyin** chaqiriladi.
  final VoidCallback onPressed;

  @override
  State<SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<SocialButton> {
  bool _isLoading = false;

  Future<void> _handleTap() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _isLoading = false);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppDimensions.radiusPill);
    return SizedBox(
      height: AppDimensions.buttonHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: borderRadius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: _isLoading ? null : _handleTap,
            borderRadius: borderRadius,
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : SvgPicture.asset(
                      widget.iconAsset,
                      height: 24,
                      semanticsLabel: widget.semanticsLabel,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
