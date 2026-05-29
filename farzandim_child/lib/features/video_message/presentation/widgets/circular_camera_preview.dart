// ─────────────────────────────────────────────────────────────────────
// CircularCameraPreview — selfie kamerani dumaloq mask bilan ko'rsatadi
// ─────────────────────────────────────────────────────────────────────

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CircularCameraPreview extends StatelessWidget {
  const CircularCameraPreview({
    required this.controller,
    this.size = 280,
    super.key,
  });

  final CameraController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size,
            height: size / controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}
