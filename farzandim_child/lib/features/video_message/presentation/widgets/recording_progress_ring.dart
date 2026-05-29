// ─────────────────────────────────────────────────────────────────────
// RecordingProgressRing — dumaloq preview atrofida yashil halqa
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class RecordingProgressRing extends StatelessWidget {
  const RecordingProgressRing({
    required this.progress,
    required this.child,
    this.size = 280,
    super.key,
  });

  final double progress; // 0.0 — 1.0
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(child: child),
          if (progress > 0)
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 6,
                color: AppColors.primary,
                // ignore: deprecated_member_use
                backgroundColor: Colors.white.withOpacity(0.2),
              ),
            ),
        ],
      ),
    );
  }
}
