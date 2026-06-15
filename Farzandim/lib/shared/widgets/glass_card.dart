// ─────────────────────────────────────────────────────────────────────
// GlassCard — "Teal Frosted" premium shisha karta (light + dark)
// ─────────────────────────────────────────────────────────────────────
//
// Yarim-shaffof teal shisha: yarim-shaffof asos + yo'naltirilgan fill gradient
// (tepa yorug') → teal tint → [sheen + specular highlight + glowing rim +
// kontent]. Boy teal gradient fon ostidan ko'rinib premium his beradi.
//
// ⚡ PERF: `BackdropFilter` (frost) ATAYIN ISHLATILMAYDI — u scrollda har kadrda
// butun fonni qayta sampling qilib jank berardi. Silliq gradient fon ustida
// frost deyarli sezilmaydi, shuning uchun yarim-shaffof asos bilan
// almashtirildi (bir xil ko'rinish, lekin silliq 60fps). `blur`/`blurSigma`
// parametrlari saqlangan (API mosligi) — ammo endi e'tiborga olinmaydi
// (no-op).
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
        // Nozik hairline rim — lit-edge ishini pastdagi specular chizig'i
        // qiladi.
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
          // b) Specular TEPA chizig'i (~1.5px) — "haqiqiy shisha" belgisi
          //    (yuqoridan tushgan yorug'lik). Light + dark; ClipRRect
          //    burchaklarda kesadi, markazda eng yorug'.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
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
    //      konveks chuqurlik; light: tekis glassFill) + tint (dark: forest
    //      jilo).
    Widget surface = DecoratedBox(
      // Yo'naltirilgan gradient — tepa yorug', past salqin-chuqur = KONVEKS
      // chuqurlik. Endi light'da ham (avval tekis edi → tekis ko'rinardi).
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.glassFillTop, AppColors.glassFillBottom],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.glassTint : Colors.transparent,
        ),
        child: content,
      ),
    );

    // 3) ⚡ PERF: BackdropFilter YO'Q. Frost scrollda har kadrda butun fonni
    //    qayta sampling qilib JANK berardi. Silliq teal gradient fon ustida
    //    frost deyarli sezilmaydi — o'rniga yarim-shaffof asos + fill
    //    gradient + rim BIR XIL premium ko'rinish beradi, lekin SILLIQ va
    //    TEZ scroll.
    surface = DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surface.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.10),
      ),
      child: surface,
    );

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
