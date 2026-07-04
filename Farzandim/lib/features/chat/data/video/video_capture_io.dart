// ─────────────────────────────────────────────────────────────────────
// VideoCapture — telefon implementatsiyasi (camera paketi)
// ─────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:farzandim/features/chat/data/video/video_capture.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Telefon uchun `VideoCapture` yaratadi.
VideoCapture createVideoCapture() => _IoVideoCapture();

/// Fayl yo'lidan video pleer boshqaruvchisi.
VideoPlayerController createVideoController(String source) =>
    VideoPlayerController.file(File(source));

class _IoVideoCapture implements VideoCapture {
  CameraController? _controller;
  bool _ready = false;

  @override
  bool get isReady => _ready;

  @override
  Future<void> init() async {
    final cams = await availableCameras();
    if (cams.isEmpty) throw Exception('Kamera topilmadi');
    final front = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );
    final controller = CameraController(front, ResolutionPreset.medium);
    await controller.initialize();
    _controller = controller;
    _ready = true;
  }

  @override
  Widget preview() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final size = c.value.previewSize ?? const Size(720, 1280);
    // Portret uchun previewSize eni/bo'yi almashtiriladi; FittedBox cover
    // dumaloq qutini to'ldiradi.
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size.height,
        height: size.width,
        child: CameraPreview(c),
      ),
    );
  }

  @override
  Future<void> start() async {
    final c = _controller;
    if (c != null && !c.value.isRecordingVideo) {
      await c.startVideoRecording();
    }
  }

  @override
  Future<String?> stop() async {
    final c = _controller;
    if (c == null || !c.value.isRecordingVideo) return null;
    final file = await c.stopVideoRecording();
    return file.path;
  }

  @override
  Future<void> cancel() async {
    final c = _controller;
    try {
      if (c != null && c.value.isRecordingVideo) {
        await c.stopVideoRecording();
      }
    } catch (_) {
      // Bekor qilishda xato — e'tiborsiz.
    }
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
