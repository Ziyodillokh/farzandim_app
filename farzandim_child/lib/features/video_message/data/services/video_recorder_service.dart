// ─────────────────────────────────────────────────────────────────────
// VideoRecorderService — Telegram-style dumaloq video xabar
// ─────────────────────────────────────────────────────────────────────
//
// Selfie kamera + 15 sek max davomiylik. `startRecording` long-press
// boshida chaqiriladi, `stopRecording` qo'yib yuborilganda yoki 15 sek
// tugagach. Video vaqtinchalik papkaga `.mp4` sifatida saqlanadi va
// fayl yo'li qaytariladi (Bosqich 2'da Storage upload bo'ladi).

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class VideoRecorderService {
  static const int maxDurationSeconds = 15;

  CameraController? _controller;
  bool _isRecording = false;
  Timer? _maxDurationTimer;

  CameraController? get controller => _controller;
  bool get isRecording => _isRecording;

  /// Selfie (front) kamerani topib initsializatsiya qiladi.
  Future<void> initialize() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
  }

  /// Yozishni boshlaydi va 15 sek timer'ni o'rnatadi.
  Future<void> startRecording({
    required VoidCallback onMaxDurationReached,
  }) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }
    if (_isRecording) return;

    await _controller!.startVideoRecording();
    _isRecording = true;

    _maxDurationTimer = Timer(
      const Duration(seconds: maxDurationSeconds),
      onMaxDurationReached,
    );

    debugPrint('VideoRecorder: yozish boshlandi');
  }

  /// Yozishni to'xtatadi va vaqtinchalik papkadagi `.mp4` yo'lini qaytaradi.
  Future<String?> stopRecording() async {
    if (!_isRecording || _controller == null) return null;

    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    final XFile videoFile = await _controller!.stopVideoRecording();
    _isRecording = false;

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newPath = '${directory.path}/video_note_$timestamp.mp4';

    final newFile = await File(videoFile.path).copy(newPath);

    debugPrint('VideoRecorder: yozish tugadi — ${newFile.path}');
    return newFile.path;
  }

  /// Resurslarni tozalash. Agar yozish davom etayotgan bo'lsa to'xtatadi.
  Future<void> dispose() async {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    if (_controller != null) {
      if (_isRecording) {
        try {
          await _controller!.stopVideoRecording();
        } catch (_) {
          // Yozish to'xtatish xatosi bo'lsa ham dispose davom etadi.
        }
      }
      await _controller!.dispose();
      _controller = null;
    }
    _isRecording = false;
  }
}
