// ─────────────────────────────────────────────────────────────────────
// PlayfulIconButton — Round icon tugma (Sprint UI.2)
// ─────────────────────────────────────────────────────────────────────
//
// Top bar, FAB ichida ishlatish uchun yumaloq icon tugma.
// Press paytida scale 0.95 + selectionClick haptic.
//
// Usage:
// ```dart
// PlayfulIconButton(
//   icon: AppIcons.bell,
//   onPressed: () => showNotifications(),
// )
// ```

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlayfulIconButton extends StatefulWidget {
  const PlayfulIconButton({
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
    this.iconSize = 24,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Fon rang. Default `AppColors.bgAccent` (soft yellow).
  final Color? backgroundColor;

  /// Icon rang. Default `AppColors.textPrimary`.
  final Color? iconColor;

  final double size;
  final double iconSize;

  @override
  State<PlayfulIconButton> createState() => _PlayfulIconButtonState();
}

class _PlayfulIconButtonState extends State<PlayfulIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;
    return GestureDetector(
      onTapDown: isDisabled
          ? null
          : (_) {
              setState(() => _isPressed = true);
              HapticFeedback.selectionClick();
            },
      onTapUp: isDisabled ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? AppColors.bgAccent,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowLight,
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: widget.iconColor ?? AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
