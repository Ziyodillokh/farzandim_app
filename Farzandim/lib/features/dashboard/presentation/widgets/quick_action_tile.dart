import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Quick action grid tugmasi — kvadratga yaqin karta. Yumaloq accent fonli
/// ikonka, ikkala tomon gradient, nozik border. Bosilganda 0.95 scale.
///
/// Dashboard'dagi quick actions grid'da ishlatiladi.
class QuickActionTile extends StatefulWidget {
  /// `QuickActionTile` konstruktor.
  const QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accentColor,
    super.key,
  });

  /// Markaz ustki qismida ko'rinadigan ikonka.
  final IconData icon;

  /// Ikonka ostidagi yorliq (14sp, oq, markazda).
  final String label;

  /// Tugma bosilganda chaqiriladi.
  final VoidCallback onTap;

  /// Ikonkaning accent rangi (yumaloq fon + ikonkaning o'zi).
  /// `null` bo'lsa `AppColors.primary` ishlatiladi.
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
    final accent = widget.accentColor ?? AppColors.primary;
    final borderRadius = BorderRadius.circular(AppDimensions.radiusM);
    return AnimatedScale(
      scale: _pressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            // Nozik diagonal gradient — surfaceVariant'dan surface'gacha
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surfaceVariant,
                AppColors.surface,
              ],
            ),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            borderRadius: borderRadius,
            splashColor: accent.withValues(alpha: 0.12),
            highlightColor: accent.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Yumaloq accent fonda ikonka (15% alpha + 25% border)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(widget.icon, size: 24, color: accent),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
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
