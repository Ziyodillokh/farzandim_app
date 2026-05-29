// ─────────────────────────────────────────────────────────────────────
// VoiceFAB — Voice recording FAB (Sprint UI.2)
// ─────────────────────────────────────────────────────────────────────
//
// Pulse animation when recording. Tap → `onPressed`.
// Idle: accent yellow + mic icon
// Recording: danger red + stop icon + pulsing scale (1.0 → 1.1)
//
// Usage:
// ```dart
// VoiceFAB(
//   isRecording: _recording,
//   onPressed: () => _toggleRecording(),
// )
// ```

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VoiceFAB extends StatefulWidget {
  const VoiceFAB({
    this.onPressed,
    this.isRecording = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool isRecording;

  @override
  State<VoiceFAB> createState() => _VoiceFABState();
}

class _VoiceFABState extends State<VoiceFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VoiceFAB oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRecording && _pulseController.isAnimating) {
      _pulseController
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isRecording ? AppColors.danger : AppColors.accent;
    final iconColor = widget.isRecording
        ? AppColors.textOnPrimary
        : AppColors.textOnAccent;

    return GestureDetector(
      onTap: widget.onPressed == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onPressed?.call();
            },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = widget.isRecording
              ? 1.0 + (_pulseController.value * 0.1)
              : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    offset: const Offset(0, 4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Icon(
                widget.isRecording ? AppIcons.stop : AppIcons.mic,
                color: iconColor,
                size: 32,
              ),
            ),
          );
        },
      ),
    );
  }
}
