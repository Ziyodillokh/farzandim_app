import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:flutter/material.dart';

/// Sozlamalar ichidagi toggle (Switch) — `SettingsTile` o'rniga
/// chevron emas, balki Switch ko'rsatadi (iOS-style).
///
/// Switch'ni bossa, butun row'ni bossa ham `onChanged` chaqiriladi.
class SettingsToggle extends StatelessWidget {
  /// `SettingsToggle` konstruktor.
  const SettingsToggle({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
    this.subtitle,
    this.accentColor,
  });

  /// Chap tomondagi ikonka.
  final IconData icon;

  /// Asosiy yorliq.
  final String title;

  /// Ixtiyoriy ostidagi kichik matn.
  final String? subtitle;

  /// Joriy holat (yoqilgan/o'chirilgan).
  final bool value;

  /// Ikonka container'ining accent rangi. `null` bo'lsa primary lime.
  final Color? accentColor;

  /// Holat o'zgarganda chaqiriladi.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primary;
    final fg = accentColor ?? AppColors.accent;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => onChanged(!value),
        splashColor: accent.withValues(alpha: 0.08),
        highlightColor: accent.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  border: Border.all(color: accent.withValues(alpha: 0.20)),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: fg, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyM.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AppSwitch(
                value: value,
                onChanged: onChanged,
                activeColor: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
