// ─────────────────────────────────────────────────────────────────────
// GlassCard — "Teal Frosted" premium shisha karta (light + dark)
// ─────────────────────────────────────────────────────────────────────
//
// SHAFFOF frosted shisha: orqa teal gradient fon BackdropFilter blur orqali
// ko'rinib refraksiya qiladi (kartalar "tirik"). Qatlamlar (clip ichida,
// past→tepa): BackdropFilter(blur) → yo'naltirilgan fill gradient (tepa
// yorug') → teal tint → [sheen + specular glass highlight + glowing rim +
// kontent]. Boy teal fon shaffof shishani premium qiladi (opaque asos
// kerak emas).
//
// ⚠️ `BackdropFilter` GPU'ga og'ir — uzun grid'da `blur: false` (soxta shisha:
// blur yo'q, biroz solidroq fill — deyarli bir xil, tez).
import 'dart:ui';

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_shadows.dart';
import 'package:flutter/material.dart';

/// Shisha karta ko'tarilish darajasi.
enum GlassElevation { flat, normal, raised }

/// Premium shisha karta. `Container(surface...)` o'rniga.
class GlassCard extends StatelessWidget {
  /// `GlassCard` konstruktor.
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.lg),
    this.radius = AppDimensions.radiusL,
    this.blur = true,
    this.blurSigma = 20,
    this.elevation = GlassElevation.normal,
    this.onTap,
    this.fill = false,
    this.expandWidth = true,
    this.width,
    super.key,
  });

  /// Karta ichidagi mazmun.
  final Widget child;

  /// Ichki padding.
  final EdgeInsetsGeometry padding;

  /// Burchak radiusi (default 24 — reference rasm).
  final double radius;

  /// Haqiqiy frost (BackdropFilter). Grid/ro'yxatda `false`.
  final bool blur;

  /// Blur kuchi (Samsung: 20–28).
  final double blurSigma;

  /// Soya darajasi.
  final GlassElevation elevation;

  /// Bosilsa — Material + InkWell (ripple clip ichida).
  final VoidCallback? onTap;

  /// `true` — mavjud (tight) bo'shliqni TO'LDIRADI (grid cell uchun;
  /// kontent markazlashadi). `false` — kontent o'lchamida (hero karta).
  final bool fill;

  /// `true` (default) — eni `double.infinity` (to'liq qator). `false` —
  /// eni `width` bilan belgilanadi (masalan dumaloq nav tugmasi).
  final bool expandWidth;

  /// `expandWidth == false` bo'lganda kartaning aniq eni. `null` bo'lsa
  /// kontent o'lchamida.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final isDark = AppColors.isDark;

    // 6) Kontent: rim border + sheen + (onTap) + padding(child).
    Widget inner = Padding(padding: padding, child: child);
    if (onTap != null) {
      inner = Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: br, child: inner),
      );
    }
    final content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        // Nozik hairline rim — lit-edge ishini pastdagi specular chizig'i qiladi.
        border: Border.all(
          color: AppColors.glassRim,
          width: isDark ? 1.0 : 1.2,
        ),
      ),
      child: Stack(
        fit: fill ? StackFit.expand : StackFit.loose,
        children: [
          // a) Sheen — yuqori-chapdan yumshoq yorug'lik.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: br,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.center,
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.07 : 0.25),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // b) Specular TEPA chizig'i (~1.5px) — "haqiqiy shisha" eng kuchli
          //    belgisi (yuqoridan tushgan mint-salqin yorug'lik). Faqat dark;
          //    ClipRRect burchaklarda kesadi, markazda eng yorug'.
          if (isDark)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        AppColors.glassTopHighlight,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          inner,
        ],
      ),
    );

    // 4-5) Fill (dark: yo'naltirilgan gradient — tepa yorug', past to'q =
    //      konveks chuqurlik; light: tekis glassFill) + tint (dark: forest jilo).
    Widget surface = DecoratedBox(
      decoration: isDark
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.glassFillTop, AppColors.glassFillBottom],
              ),
            )
          : BoxDecoration(color: AppColors.glassFill),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.glassTint : Colors.transparent,
        ),
        child: content,
      ),
    );

    if (blur) {
      // 3a) DARK: blur ICHIDA yarim-shaffof teal asos — scroll'da BackdropFilter
      //     fon (gradient/yog'du)ning turli qismini tutib kartani "miltillatishi"
      //     ni BARQARORLASHTIRADI (kartalar scrollda qoraymaydi). Shisha hissi
      //     qoladi (asos yarim-shaffof, blur ham ko'rinadi).
      if (isDark) {
        surface = DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.45),
          ),
          child: surface,
        );
      }
      // 3b) Haqiqiy frost (BackdropFilter) — orqa teal gradient shisha orqali
      //     ko'rinib refraksiya qiladi (dark: teal frosted; light: oq frosted).
      surface = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: surface,
      );
    } else {
      // Frost'siz (grid/tile) — biroz solidroq fill (deyarli bir xil, tez).
      surface = DecoratedBox(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surface.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.10),
        ),
        child: surface,
      );
    }

    // 1) Soya (clip TASHQARIDA) + 2) clip.
    final shadows = elevation == GlassElevation.flat
        ? AppShadows.card
        : AppShadows.glass;
    return SizedBox(
      width: expandWidth ? double.infinity : width,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: br, boxShadow: shadows),
        child: ClipRRect(borderRadius: br, child: surface),
      ),
    );
  }
}
