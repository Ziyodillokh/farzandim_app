import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Sozlamalar ichidagi bitta tap'lanadigan element (iOS-style).
///
/// Layout:
/// - Chap: 38dp rounded square (radius 10) — subtle gradient, accent ikonka
/// - O'rta: title (16sp, w500, oq) + ixtiyoriy subtitle (13sp, secondary)
/// - O'ng: rounded chevron yoki custom trailing widget
/// - Press: 0.98 scale + subtle splash
class SettingsTile extends StatefulWidget {
  /// `SettingsTile` konstruktor.
  const SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
    this.subtitle,
    this.trailing,
    this.accentColor,
  });

  /// Chap tomondagi ikonka.
  final IconData icon;

  /// Asosiy yorliq.
  final String title;

  /// Ixtiyoriy ostida'i kichik matn.
  final String? subtitle;

  /// O'ng tomondagi widget — `null` bo'lsa default rounded chevron.
  final Widget? trailing;

  /// Ikonka container'ining accent rangi. `null` bo'lsa primary lime.
  final Color? accentColor;

  /// Bosilganda chaqiriladi.
  final VoidCallback onTap;

  @override
  State<SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<SettingsTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppColors.accent;
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          splashColor: accent.withValues(alpha: 0.08),
          highlightColor: accent.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                // Rounded square (iOS-style) — gradient + nozik border
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: 0.22),
                        accent.withValues(alpha: 0.12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.20),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(widget.icon, color: accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: AppTextStyles.bodyM.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: AppTextStyles.bodyS.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                widget.trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: AppColors.textTertiary,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
