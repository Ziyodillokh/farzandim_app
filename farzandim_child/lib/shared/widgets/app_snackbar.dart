// ─────────────────────────────────────────────────────────────────────
// AppSnackBar — ilova bo'ylab izchil floating snackbar (Duolingo uslubi)
// ─────────────────────────────────────────────────────────────────────
//
// Barcha qisqa xabarlar shu yordamchi orqali ko'rsatiladi — bir xil shakl,
// rang va ikona. To'g'ridan-to'g'ri `ScaffoldMessenger` chaqirish o'rniga:
//   AppSnackBar.success(context, 'Saqlandi');
//   AppSnackBar.error(context, 'Xatolik yuz berdi');
//
// 4 variant: success (yashil), info (ko'k), warning (sariq), error (qizil).

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Ilova bo'ylab izchil snackbar helper'i.
class AppSnackBar {
  AppSnackBar._();

  /// Muvaffaqiyat — yashil (primary).
  static void success(BuildContext context, String message) =>
      _show(context, message, AppColors.primary, Icons.check_circle_rounded);

  /// Ma'lumot — ko'k (secondary).
  static void info(BuildContext context, String message) =>
      _show(context, message, AppColors.secondary, Icons.info_rounded);

  /// Ogohlantirish — sariq (warning).
  static void warning(BuildContext context, String message) => _show(
        context,
        message,
        AppColors.warning,
        Icons.warning_amber_rounded,
      );

  /// Xatolik — qizil (danger).
  static void error(BuildContext context, String message) =>
      _show(context, message, AppColors.danger, Icons.error_rounded);

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }
}
