// ─────────────────────────────────────────────────────────────────────
// PlayfulButton — Duolingo-style 3D tugma (Sprint UI.2)
// ─────────────────────────────────────────────────────────────────────
//
// 3D shadow + press animation + haptic feedback.
//
// Features:
//   - 4px pastki shadow ("raised" feel)
//   - Press: scale 0.97 (margin↓4 → 0) + lightImpact haptic
//   - Disabled: 50% opacity
//   - Loading: CircularProgressIndicator
//   - 6 variant: primary/secondary/accent/warning/danger/outlined
//
// Usage:
// ```dart
// PlayfulButton(
//   label: 'YUBORISH',
//   onPressed: () => doSomething(),
//   variant: ButtonVariant.primary,
// )
// ```

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tugma variant turlari.
enum ButtonVariant {
  /// Asosiy CTA — Duolingo green.
  primary,

  /// Info — friendly blue.
  secondary,

  /// Reward, achievement — sunshine yellow (matn dark).
  accent,

  /// Battery low, schedule warning — orange.
  warning,

  /// Faqat SOS, emergency — red.
  danger,

  /// Border'li, transparent fon — primary matn.
  outlined,
}

/// Duolingo-style 3D button with shadow + press animation.
class PlayfulButton extends StatefulWidget {
  const PlayfulButton({
    required this.label,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.height = 56,
    super.key,
  });

  /// Tugma matni (Caps Lock tavsiya etiladi: "YUBORISH").
  final String label;

  /// `null` → disabled.
  final VoidCallback? onPressed;

  /// Default `primary`.
  final ButtonVariant variant;

  /// Ixtiyoriy leading ikona.
  final IconData? icon;

  /// Yuklanmoqda — `CircularProgressIndicator` ko'rsatadi, onTap disabled.
  final bool isLoading;

  /// `true` → `double.infinity` width. Default `true`.
  final bool fullWidth;

  /// Default 56dp.
  final double height;

  @override
  State<PlayfulButton> createState() => _PlayfulButtonState();
}

class _PlayfulButtonState extends State<PlayfulButton> {
  bool _isPressed = false;

  Color _mainColor() {
    switch (widget.variant) {
      case ButtonVariant.primary:
        return AppColors.primary;
      case ButtonVariant.secondary:
        return AppColors.secondary;
      case ButtonVariant.accent:
        return AppColors.accent;
      case ButtonVariant.warning:
        return AppColors.warning;
      case ButtonVariant.danger:
        return AppColors.danger;
      case ButtonVariant.outlined:
        return Colors.transparent;
    }
  }

  Color _shadowColor() {
    switch (widget.variant) {
      case ButtonVariant.primary:
        return AppColors.primaryShadow;
      case ButtonVariant.secondary:
        return AppColors.secondaryShadow;
      case ButtonVariant.accent:
        return AppColors.accentShadow;
      case ButtonVariant.warning:
        return AppColors.warningShadow;
      case ButtonVariant.danger:
        return AppColors.dangerShadow;
      case ButtonVariant.outlined:
        return AppColors.divider;
    }
  }

  Color _textColor() {
    switch (widget.variant) {
      case ButtonVariant.accent:
        return AppColors.textOnAccent;
      case ButtonVariant.outlined:
        return AppColors.primary;
      default:
        return AppColors.textOnPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final mainColor = _mainColor();
    final shadowColor = _shadowColor();
    final textColor = _textColor();

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: GestureDetector(
        onTapDown: isDisabled
            ? null
            : (_) {
                setState(() => _isPressed = true);
                HapticFeedback.lightImpact();
              },
        onTapUp: isDisabled ? null : (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: isDisabled ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          width: widget.fullWidth ? double.infinity : null,
          height: widget.height,
          margin: EdgeInsets.only(bottom: _isPressed ? 0 : 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isPressed
                ? const []
                : [
                    BoxShadow(
                      color: shadowColor,
                      offset: const Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: mainColor,
              borderRadius: BorderRadius.circular(16),
              border: widget.variant == ButtonVariant.outlined
                  ? Border.all(color: AppColors.primary, width: 2)
                  : null,
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: textColor,
                        strokeWidth: 3,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: textColor, size: 22),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
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
