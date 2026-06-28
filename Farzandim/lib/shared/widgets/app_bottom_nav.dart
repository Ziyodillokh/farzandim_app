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
import 'package:farzandim/core/theme/app_shadows.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/shared/widgets/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

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

  /// Pastki nav balandligi — layout (floating Stack)'da scroll uchun pastki
  /// bo'shliq hisoblashda ishlatiladi: `kBarHeight + md + 8`.
  static const double kBarHeight = 56;
  static const _pillRadius = BorderRadius.all(
    Radius.circular(AppDimensions.radiusPill),
  );

  @override
  Widget build(BuildContext context) {
    final activityActive = activeIndex == 0;
    // ⚠️ Root'da HECH QANDAY fon yo'q (Container/ColoredBox/gradient) — nav
    // orqa gradient + aurora ustida SUZIB turadi. Faqat tugmalarning o'zi
    // ko'rinadi: aktiv = solid yashil pill, inactive = frosted glass doira.
    return SizedBox(
      height: kBarHeight,
      child: Row(
        children: [
          if (activityActive)
            Expanded(
              child: _ActivePill(
                icon: SolarIconsBold.pieChart,
                label: activityLabel,
                onTap: onActivity,
              ),
            )
          else
            _CircleButton(icon: SolarIconsBold.pieChart, onTap: onActivity),
          const SizedBox(width: AppDimensions.md),
          if (activityActive)
            _CircleButton(icon: SolarIconsBold.settings, onTap: onSettings)
          else
            Expanded(
              child: _ActivePill(
                icon: SolarIconsBold.settings,
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
      flightShuttleBuilder: (_, __, ___, ____, _____) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppBottomNav._pillRadius,
        ),
      ),
      child: DecoratedBox(
        // Premium: lime pill gradient ustida qalqib turadi (nozik brand glow).
        decoration: BoxDecoration(
          borderRadius: AppBottomNav._pillRadius,
          boxShadow: AppShadows.glow(AppColors.primary),
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
                  Icon(icon, size: 20, color: AppColors.onPrimary),
                  const SizedBox(width: AppDimensions.sm),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyM.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kichik dumaloq (tanlanmagan) tugma — frosted glass doira.
///
/// `GlassCard` orqa gradient + aurora'ni frost qiladi, o'zi rim + sheen +
/// floating soya beradi. Eski qattiq `surface` doira o'rniga — shisha
/// kartalar bilan bir xil premium til.
class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      // To'liq doira: eni = balandlik, radius = yarmi.
      expandWidth: false,
      width: AppBottomNav.kBarHeight,
      radius: AppBottomNav.kBarHeight / 2,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        width: AppBottomNav.kBarHeight,
        height: AppBottomNav.kBarHeight,
        child: Center(
          child: Icon(icon, size: 22, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
