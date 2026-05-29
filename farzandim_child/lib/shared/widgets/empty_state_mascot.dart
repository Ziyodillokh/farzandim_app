// ─────────────────────────────────────────────────────────────────────
// EmptyStateMascot — bo'sh ekranlar uchun maskot
// ─────────────────────────────────────────────────────────────────────
//
// Modern app'lar (Duolingo Owl, Mailchimp Freddie) bo'sh holatda
// playful character ko'rsatadi — bola "Hech narsa yo'q" o'rniga
// jonli muloqot oladi.
//
// Hozir Lottie .json yo'q — Flutter built-in icon'lar + bounce
// animatsiya bilan oddiy mascot. Kelajakda Lottie animatsiya.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EmptyStateMascot extends StatelessWidget {
  const EmptyStateMascot({
    this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.accentColor,
    this.faroVariant = FaroVariant.faceSad,
    super.key,
  });

  /// Agar FARO o'rniga oddiy icon kerak bo'lsa (legacy).
  final IconData? icon;

  /// FARO yuz variant — kontekstga qarab.
  final FaroVariant faroVariant;

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // FARO maskot bilan empty state — bounce animation
            (icon != null
                    ? Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          // ignore: deprecated_member_use
                          color: color.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 60),
                      )
                    : FaroMascot(variant: faroVariant, size: 140))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(
                  begin: 0,
                  end: -8,
                  duration: 1200.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.black,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
