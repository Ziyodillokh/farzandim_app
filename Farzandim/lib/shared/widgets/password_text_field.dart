import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/shared/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Parol uchun maxsus text field — `obscureText: true` + ko'rsatish/yashirish
/// (eye) toggle bilan.
///
/// Ichida `CustomTextField`'ni o'rab oladi. Toggle bosilganda parol vaqtincha
/// ko'rinadi.
///
/// Foydalanish:
/// ```dart
/// PasswordTextField(
///   controller: _passwordController,
///   hint: 'Parolingizni kiriting',
///   onChanged: (_) => setState(() {}),
/// )
/// ```
class PasswordTextField extends StatefulWidget {
  /// `PasswordTextField` konstruktor.
  const PasswordTextField({
    required this.controller,
    required this.hint,
    super.key,
    this.onChanged,
  });

  /// Parol matn nazoratchisi.
  final TextEditingController controller;

  /// Bo'sh holatdagi placeholder matni.
  final String hint;

  /// Parol o'zgarganda chaqiriladi (validatsiya uchun).
  final ValueChanged<String>? onChanged;

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: widget.controller,
      hint: widget.hint,
      onChanged: widget.onChanged,
      obscureText: _obscureText,
      suffix: IconButton(
        icon: Icon(
          _obscureText ? SolarIconsBold.eyeClosed : SolarIconsBold.eye,
        ),
        color: AppColors.textSecondary,
        onPressed: () => setState(() => _obscureText = !_obscureText),
      ),
    );
  }
}
