import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../ux/app_error_handler.dart';
import 'common.dart';

/// Full error panel with retry — never silent.
class AppErrorStateView extends StatelessWidget {
  const AppErrorStateView({
    super.key,
    required this.error,
    required this.onRetry,
    this.title = 'Yuklash amalga oshmadi',
  });

  final Object error;
  final VoidCallback onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    final msg = AppErrorHandler.userMessage(error);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                const SizedBox(height: AppSpacing.sm),
                Text(title, style: AppTextStyles.sectionTitle, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  msg,
                  style: AppTextStyles.pageSubtitle.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                AppPrimaryButton(label: 'Qayta urinish', onPressed: onRetry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
