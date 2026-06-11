// ─────────────────────────────────────────────────────────────────────
// SettingsCard — ichki sahifalar uchun PREMIUM "accent panel"
// ─────────────────────────────────────────────────────────────────────
//
// Dashboard'dagi `GlassCard` (RANGSIZ frost shisha — translucent, neytral
// sheen) dan ATAYIN farqli. Bu:
//   • SOLID surface asos ("yerga qo'ngan", suzmaydigan) — boshqa his.
//   • Yuqori-chapdan diagonal RANGLI jilo (glass rangsiz edi).
//   • Accent hairline chegara (glass'ning oq rim'i emas).
//
// Har sahifa o'z `accent` rangini beradi (qurilma=turkuaz, geo=ko'k,
// jadval=yashil, limit=qizil...) → "har page premiumligi o'zicha bilinadi".
// Shu bilan ichki sahifalar dashboard bilan bir xil/zerikarli bo'lib qolmaydi.
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_shadows.dart';
import 'package:flutter/material.dart';

/// Premium accent panel. `Container(surface...)` o'rniga ishlatiladi.
class SettingsCard extends StatelessWidget {
  /// `SettingsCard` konstruktor.
  const SettingsCard({
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(AppDimensions.md),
    this.radius = AppDimensions.radiusL,
    this.onTap,
    super.key,
  });

  /// Karta mazmuni.
  final Widget child;

  /// Sahifa aksent rangi. `null` bo'lsa brand `accent` (mint/teal).
  final Color? accent;

  /// Ichki padding.
  final EdgeInsetsGeometry padding;

  /// Burchak radiusi.
  final double radius;

  /// Bosilsa — Material + InkWell.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final a = accent ?? AppColors.accent;
    final isDark = AppColors.isDark;
    final br = BorderRadius.circular(radius);

    // Kontent kartaning TO'LIQ enini egallaydi — aks holda ichidagi Column
    // (masalan action tile'dagi ikon + yozuv) chapga yopishib qoladi.
    // To'liq en + Column'ning default markazlashi → ikon/yozuv markazda.
    Widget content = SizedBox(
      width: double.infinity,
      child: Padding(padding: padding, child: child),
    );
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: br,
          splashColor: a.withValues(alpha: 0.08),
          highlightColor: a.withValues(alpha: 0.04),
          child: content,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: br, boxShadow: AppShadows.card),
      child: ClipRRect(
        borderRadius: br,
        child: DecoratedBox(
          // Solid asos — glass'dan farqli, opaque "panel".
          decoration: BoxDecoration(color: AppColors.surface),
          child: Stack(
            children: [
              // a) Diagonal RANGLI jilo — yuqori-chapdan accent yorug'lik.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0, 0.55],
                        colors: [
                          a.withValues(alpha: isDark ? 0.10 : 0.06),
                          a.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // b) Accent hairline chegara (rangli — glass oq rim emas).
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: br,
                      border: Border.all(
                        color: a.withValues(alpha: isDark ? 0.22 : 0.20),
                      ),
                    ),
                  ),
                ),
              ),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings-row uchun premium ikona "chip" — accent-tint gradient fonli
/// rounded-square ichida accent rangli ikona. SettingsCard bilan juftlik.
class SettingsIconChip extends StatelessWidget {
  /// `SettingsIconChip` konstruktor.
  const SettingsIconChip({
    required this.icon,
    this.accent,
    this.size = 42,
    super.key,
  });

  /// Ikona.
  final IconData icon;

  /// Aksent rang. `null` bo'lsa brand `accent`.
  final Color? accent;

  /// Chip o'lchami (kvadrat).
  final double size;

  @override
  Widget build(BuildContext context) {
    final a = accent ?? AppColors.accent;
    final isDark = AppColors.isDark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            a.withValues(alpha: isDark ? 0.24 : 0.16),
            a.withValues(alpha: isDark ? 0.10 : 0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: a.withValues(alpha: 0.30)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: a),
    );
  }
}
