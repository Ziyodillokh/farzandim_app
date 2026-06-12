import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_shadows.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Quick action grid tugmasi — "Luminous Glass Lite" premium tile.
///
/// `GlassCard(blur: false)` o'rniga MAXSUS yorug' tizim: gradient fill (konveks
/// chuqurlik) + glowing rim + sheen + specular tepa chizig'i + accent rangli
/// halo soya + gradient ikonka badge (OQ glyph). 6 ta BackdropFilter YO'Q —
/// 60fps scroll, lekin hero GlassCard bilan bir xil premium daraja.
///
/// Rang faqat ikonka badge'da — tile tanasi 6 tasi uchun bir xil; bosilganda
/// 0.95 scale + haptik.
class QuickActionTile extends StatefulWidget {
  /// `QuickActionTile` konstruktor.
  const QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accentColor,
    super.key,
  });

  /// Markaz ustki qismida ko'rinadigan ikonka (badge ichida, oq glyph).
  final IconData icon;

  /// Ikonka ostidagi yorliq (markazda, 2 qatorgacha).
  final String label;

  /// Tugma bosilganda chaqiriladi.
  final VoidCallback onTap;

  /// Ikonka badge gradientining accent rangi. `null` bo'lsa `AppColors.accent`.
  final Color? accentColor;

  @override
  State<QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<QuickActionTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
      if (value) {
        HapticFeedback.lightImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppColors.accent;
    final isDark = AppColors.isDark;
    final radius = BorderRadius.circular(AppDimensions.radiusTile);

    return AnimatedScale(
      scale: _pressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      // Listener press-state'ni boshqaradi; InkWell ripple + onTap.
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        // 1) Soya (clip TASHQARIDA) — accent halo bilan float.
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: AppShadows.qaTile,
          ),
          // 2) Clip.
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 3-4) Tana — yo'naltirilgan gradient fill + teal tint.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.qaTileFillTop,
                          AppColors.qaTileFillBottom,
                        ],
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.qaTileTint),
                    ),
                  ),
                ),
                // 5a) Sheen — yuqori-chapdan yumshoq yorug'lik.
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.center,
                          colors: [
                            Colors.white.withValues(
                              alpha: isDark ? 0.12 : 0.30,
                            ),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 5b) Specular tepa chizig'i (~1.5px) — "haqiqiy shisha"
                // belgisi.
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
                            Colors.white.withValues(
                              alpha: isDark ? 0.40 : 0.55,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 5d-e) Kontent — Material + InkWell ripple + badge + label.
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onTap,
                      splashColor: accent.withValues(alpha: 0.12),
                      highlightColor: accent.withValues(alpha: 0.06),
                      child: Padding(
                        padding: const EdgeInsets.all(
                          AppDimensions.sm + AppDimensions.xs,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _PremiumIconBadge(
                              icon: widget.icon,
                              accent: accent,
                            ),
                            const SizedBox(height: AppDimensions.sm),
                            Flexible(
                              child: Text(
                                widget.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyS.copyWith(
                                  fontSize: 13,
                                  color: AppColors.qaTileLabel,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 5c) Rim — yorug' chekka (eng ustda, crisp).
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        border: Border.all(
                          color: AppColors.qaTileRim,
                          width: 1.2,
                        ),
                      ),
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

/// TOZA SHISHA ikonka badge (48×48) — referensdek: nozik oq fill gradient +
/// crisp rim + OQ glyph (dark). Rangli gradient EMAS. Identity uchun juda nozik
/// accent yog'du. Light'da accent-tinted (oq tile ustida ko'rinishi uchun).
class _PremiumIconBadge extends StatelessWidget {
  const _PremiumIconBadge({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Dark: toza oq shisha (fon ko'rinadi → glyph uchun yetarli to'q).
        // Light: nozik accent-tinted (oq tile ustida ajraladi).
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.07),
                ]
              : [
                  accent.withValues(alpha: 0.22),
                  accent.withValues(alpha: 0.12),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.48)
              : accent.withValues(alpha: 0.40),
        ),
        boxShadow: [
          // Neytral yumshoq soya — shisha ortida RANG yo'q (dark). Light'da
          // oq tile uchun nozik accent yog'du qoladi (badge ko'rinishi uchun).
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.22)
                : accent.withValues(alpha: 0.12),
            blurRadius: isDark ? 10 : 14,
            spreadRadius: -2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 24, color: isDark ? Colors.white : accent),
    );
  }
}
