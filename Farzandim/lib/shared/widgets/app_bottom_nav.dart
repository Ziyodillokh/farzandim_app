// ─────────────────────────────────────────────────────────────────────
// AppBottomNav — Dashboard ↔ Sozlamalar pastki navigatsiya (2 tab)
// ─────────────────────────────────────────────────────────────────────
//
// Tanlangan tab — yashil kengaytirilgan pill, ikkinchisi — kichik dumaloq
// tugma. Dashboard'da "Foydalanish vaqti" aktiv (chap), Sozlamalar'da
// "Sozlamalar" aktiv (o'ng). Yashil pill `Hero` orqali bir ekrandan
// ikkinchisiga SILLIQ ko'chadi (chapdan o'ngga slide + morph) — avval
// push'da keskin sakrardi.

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Pastki navigatsiya — `activeIndex` 0 = Foydalanish vaqti, 1 = Sozlamalar.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.activeIndex,
    required this.onActivity,
    required this.onSettings,
    required this.activityLabel,
    required this.settingsLabel,
    super.key,
  });

  final int activeIndex;
  final VoidCallback onActivity;
  final VoidCallback onSettings;
  final String activityLabel;
  final String settingsLabel;

  static const double _height = 56;
  static const _pillRadius = BorderRadius.all(
    Radius.circular(AppDimensions.radiusPill),
  );

  @override
  Widget build(BuildContext context) {
    final activityActive = activeIndex == 0;
    return SizedBox(
      height: _height,
      child: Row(
        children: [
          if (activityActive)
            Expanded(
              child: _ActivePill(
                icon: Icons.pie_chart_rounded,
                label: activityLabel,
                onTap: onActivity,
              ),
            )
          else
            _CircleButton(icon: Icons.pie_chart_rounded, onTap: onActivity),
          const SizedBox(width: AppDimensions.md),
          if (activityActive)
            _CircleButton(icon: Icons.settings_rounded, onTap: onSettings)
          else
            Expanded(
              child: _ActivePill(
                icon: Icons.settings_rounded,
                label: settingsLabel,
                onTap: onSettings,
              ),
            ),
        ],
      ),
    );
  }
}

/// Yashil kengaytirilgan tugma — `Hero` morph bilan.
class _ActivePill extends StatelessWidget {
  const _ActivePill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'nav.activePill',
      // Parvoz paytida faqat yashil pill ko'rinadi (matn morf'lanmaydi —
      // kenglik o'zgargani uchun cho'zilmasin). Boshlanish/oxirida to'liq
      // ikona+matn ko'rinadi.
      flightShuttleBuilder: (_, __, ___, ____, _____) => const DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppBottomNav._pillRadius,
        ),
      ),
      child: Material(
        color: AppColors.primary,
        borderRadius: AppBottomNav._pillRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppBottomNav._pillRadius,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: AppColors.background),
                const SizedBox(width: AppDimensions.sm),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyM.copyWith(
                      color: AppColors.background,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kichik dumaloq (tanlanmagan) tugma.
class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: AppBottomNav._height,
          height: AppBottomNav._height,
          child: Icon(
            icon,
            size: 22,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
