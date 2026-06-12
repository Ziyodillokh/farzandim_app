import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Auth ekranlardagi linklar uchun indigo rang (Figma dizayni).
const Color kAuthLinkColor = Color(0xFF7C7CF5);

/// Forma maydoni ustidagi yorliq matni (masalan, "Parol").
class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodyS.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Inline xato matni (qizil ikonka + matn).
class AuthErrorText extends StatelessWidget {
  const AuthErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: AppDimensions.iconS,
          color: AppColors.error,
        ),
        const SizedBox(width: AppDimensions.xs),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.bodyS.copyWith(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}

/// Orqaga qaytish tugmasi — `pop` bo'lmasa Welcome ekraniga o'tadi.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.welcome);
        }
      },
    );
  }
}
