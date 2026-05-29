// ─────────────────────────────────────────────────────────────────────
// RecordButton — long-press orqali yozish (Telegram-style)
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class RecordButton extends StatelessWidget {
  const RecordButton({
    required this.isRecording,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    super.key,
  });

  final bool isRecording;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => onLongPressStart(),
      onLongPressEnd: (_) => onLongPressEnd(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isRecording ? 90 : 80,
        height: isRecording ? 90 : 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecording ? Colors.red : AppColors.primary,
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: (isRecording ? Colors.red : AppColors.primary).withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: isRecording ? 8 : 4,
            ),
          ],
        ),
        child: Icon(
          isRecording ? Icons.stop : AppIcons.video,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}
