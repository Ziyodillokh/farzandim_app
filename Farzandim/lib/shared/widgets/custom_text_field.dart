import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pill-shaped TextField — Farzandim formalarida ishlatamiz.
///
/// Standart `TextField`'dan farqi: yumshoqroq pill burchak (radius 999),
/// `AppColors.surface` fon, fokus paytida lime green chegara.
///
/// Foydalanish:
/// ```dart
/// CustomTextField(
///   controller: _phoneController,
///   hint: '90 123 45 67',
///   prefix: '+998 ',
///   keyboardType: TextInputType.phone,
///   maxLength: 9,
///   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
///   onChanged: (value) => setState(() {}),
/// )
/// ```
///
/// Parol input uchun `obscureText: true` + `suffix:` (eye toggle) ishlating
/// — yoki tayyor `PasswordTextField`'dan foydalaning.
class CustomTextField extends StatelessWidget {
  /// `CustomTextField` konstruktor.
  const CustomTextField({
    required this.controller,
    required this.hint,
    super.key,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.maxLength,
    this.inputFormatters,
    this.onChanged,
    this.obscureText = false,
  });

  /// Field'ning matn nazoratchisi.
  final TextEditingController controller;

  /// Bo'sh holatdagi yo'l-yo'riq matni (placeholder).
  final String hint;

  /// Hint'dan oldin ko'rinadigan o'zgarmas matn (masalan, `'+998 '`).
  final String? prefix;

  /// Field'ning **o'ng** tomonida ko'rinadigan widget (masalan,
  /// parol uchun ko'rsatish/yashirish IconButton).
  final Widget? suffix;

  /// Klaviatura turi: `phone`, `email`, `number` va h.k.
  final TextInputType? keyboardType;

  /// Maksimal belgilar soni. Counter ("0/9") yashirin.
  final int? maxLength;

  /// Kiritishga cheklovlar (masalan, faqat raqam).
  final List<TextInputFormatter>? inputFormatters;

  /// Matn o'zgarganda chaqiriladi (validatsiya, button enable, va h.k.).
  final ValueChanged<String>? onChanged;

  /// `true` bo'lsa matn yashirin (parol field uchun).
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppDimensions.radiusPill);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      obscureText: obscureText,
      style: AppTextStyles.bodyM,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyM.copyWith(
          color: AppColors.textTertiary,
        ),
        prefixText: prefix,
        prefixStyle: AppTextStyles.bodyM,
        suffixIcon: suffix,
        // `maxLength` ostidagi counter ("0/9") yashirin.
        counterText: '',
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.lg,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }
}
