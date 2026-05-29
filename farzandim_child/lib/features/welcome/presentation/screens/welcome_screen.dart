// ─────────────────────────────────────────────────────────────────────
// WelcomeScreen — bola ilovani birinchi marta ochganida ko'radi
// ─────────────────────────────────────────────────────────────────────
//
// Logo + sarlavha + tagline + "Boshlash" tugma.
// Tugma bosilsa → /pairing ekraniga.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:farzandim_child/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),

                // Brand: square brand (LOGO, yuqorida) + FARO maskot (hero)
                Image.asset(
                  'assets/icons/child_app_icon_white.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: -0.1, end: 0),
                const SizedBox(height: 16),
                // FARO maskot — Welcome screen hero element
                const FaroMascot(
                  variant: FaroVariant.body,
                  size: 220,
                )
                    .animate()
                    .fadeIn(duration: 800.ms, delay: 200.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 16),

                // Tagline (app name endi logo asset'da)
                Text(
                  'welcome.tagline'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),

                const Spacer(),

                // Boshlash tugma
                PrimaryButton(
                  text: 'welcome.startButton'.tr(),
                  icon: AppIcons.forward,
                  onPressed: () => context.go('/pairing'),
                ),
                const SizedBox(height: 16),

                Text(
                  'welcome.codeHint'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
