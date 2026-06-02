import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import 'app_loading.dart';

/// Full-screen light barrier while [AppLoading] is active (API or refresh).
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLoading.instance,
      builder: (context, _) {
        final block = AppLoading.instance.isBlocking;
        return Stack(
          children: [
            child,
            if (block)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                    ),
                    child: Center(
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 160,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: const LinearProgressIndicator(
                                    minHeight: 4,
                                    color: AppColors.primary,
                                    backgroundColor: Color(0xFFE8ECF0),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Yuklanmoqda…',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
