import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Pill-shaped dropdown — Farzandim formalari uchun.
///
/// Generic — istalgan tip uchun ishlaydi (`int` yosh uchun, `String`
/// hudud uchun, `Gender` enum uchun va h.k.).
///
/// Foydalanish:
/// ```dart
/// CustomDropdown<int>(
///   hint: 'Yoshini tanlang',
///   value: _selectedAge,                                  // int?
///   items: [
///     for (var age = 5; age <= 18; age++)
///       DropdownMenuItem(value: age, child: Text('$age yosh')),
///   ],
///   onChanged: (v) => setState(() => _selectedAge = v),  // (int?) → void
/// )
/// ```
///
/// **Tip xavfsizligi:** `T = int` deb e'lon qilsangiz, `value` faqat
/// `int?` bo'lishi mumkin, `items` faqat `DropdownMenuItem<int>`,
/// `onChanged` callback `int?` qabul qiladi. String berib bo'lmaydi —
/// kompilyator xato beradi.
class CustomDropdown<T> extends StatelessWidget {
  /// `CustomDropdown` konstruktor.
  const CustomDropdown({
    required this.hint,
    required this.items,
    required this.onChanged,
    super.key,
    this.value,
  });

  /// Joriy tanlangan qiymat. `null` bo'lsa hint ko'rinadi.
  final T? value;

  /// Bo'sh holatda ko'rinadigan yo'l-yo'riq matni
  /// (masalan, "Yoshini tanlang").
  final String hint;

  /// Dropdown ochilganda ko'rinadigan element'lar.
  ///
  /// Har birining `value` — qaytariladigan ma'lumot, `child` —
  /// ko'rsatiladigan widget (odatda `Text`).
  final List<DropdownMenuItem<T>> items;

  /// Foydalanuvchi tanlov qilganda chaqiriladi.
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.inputHeight, // 56dp — TextField bilan bir xil
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        border: Border.all(color: AppColors.border),
      ),
      // `DropdownButtonHideUnderline` — Dropdown'ning standart ostidagi
      // chiziqni yashiradi (bizning dizayn'da kerak emas).
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: AppTextStyles.bodyM.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          // To'liq kenglikni egallaydi — pill shaklining ichida.
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.textSecondary,
          ),
          // Ochilgan menyu fon'i (default — surfaceContainerHighest).
          dropdownColor: AppColors.surface,
          // Tanlangan qiymat field'da shu stilda ko'rinadi.
          style: AppTextStyles.bodyM,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
