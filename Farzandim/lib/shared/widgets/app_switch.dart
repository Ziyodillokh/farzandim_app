import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_shadows.dart';
import 'package:flutter/material.dart';

/// Premium on/off toggle — ikkala (light + night) mode'da ham ANIQ ko'rinadi.
///
/// `Switch.adaptive` dark mode'da OFF holatni fonga singdirib ko'rsatmasdi.
/// Bu widget OFF da aniq track + thumb, ON da brand rang + nozik glow beradi.
/// Bosilganda silliq animatsiya (dinamik his). Loyihadagi BARCHA toggle shu
/// widgetni ishlatadi (izchillik).
class AppSwitch extends StatelessWidget {
  /// `AppSwitch` konstruktor.
  const AppSwitch({
    required this.value,
    required this.onChanged,
    this.activeColor,
    super.key,
  });

  /// Joriy holat (yoqilgan/o'chirilgan).
  final bool value;

  /// Holat o'zgarganda chaqiriladi. `null` bo'lsa o'chirilgan (disabled).
  final ValueChanged<bool>? onChanged;

  /// ON holatdagi track rangi. `null` bo'lsa brand `primary`.
  final Color? activeColor;

  static const double _w = 52;
  static const double _h = 30;
  static const double _thumb = 24;
  static const _dur = Duration(milliseconds: 200);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;
    final on = activeColor ?? AppColors.primary;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disabled ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: _dur,
          curve: _curve,
          width: _w,
          height: _h,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? on : AppColors.switchOffTrack,
            borderRadius: BorderRadius.circular(_h / 2),
            // OFF: nozik chegara (aniq ko'rinish). ON: brand glow (premium).
            border: value ? null : Border.all(color: AppColors.border),
            boxShadow: value ? AppShadows.glow(on) : null,
          ),
          child: AnimatedAlign(
            duration: _dur,
            curve: _curve,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: _thumb,
              height: _thumb,
              decoration: BoxDecoration(
                color: value ? Colors.white : AppColors.switchOffThumb,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
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
