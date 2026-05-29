// ─────────────────────────────────────────────────────────────────────
// VideoRecordingScreen — Telegram-style video xabar yozish (Bosqich 1)
// ─────────────────────────────────────────────────────────────────────
//
// Selfie kamera + dumaloq preview + yashil progress halqa + long-press
// record. 15 sek max — tugagach yoki barmoq qo'yib yuborilsa to'xtaydi
// va `/video-preview` ekraniga o'tadi (Send/Bekor tanlash uchun).

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/video_message/data/services/video_recorder_service.dart';
import 'package:farzandim_child/features/video_message/presentation/screens/video_preview_screen.dart';
import 'package:farzandim_child/features/video_message/presentation/widgets/circular_camera_preview.dart';
import 'package:farzandim_child/features/video_message/presentation/widgets/record_button.dart';
import 'package:farzandim_child/features/video_message/presentation/widgets/recording_progress_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoRecordingScreen extends ConsumerStatefulWidget {
  const VideoRecordingScreen({this.requestId, super.key});

  /// Parent so'roviga javob bo'lsa — request hujjat ID'si. Null bo'lsa
  /// bola o'z xohishi bilan yozayapti (test tugma yoki kelajakda nav).
  final String? requestId;

  @override
  ConsumerState<VideoRecordingScreen> createState() =>
      _VideoRecordingScreenState();
}

class _VideoRecordingScreenState
    extends ConsumerState<VideoRecordingScreen>
    with WidgetsBindingObserver {
  static const Duration _minDuration = Duration(milliseconds: 1500);

  final VideoRecorderService _service = VideoRecorderService();
  bool _isInitialized = false;
  bool _isRecording = false;
  double _progress = 0.0;
  Timer? _progressTimer;
  String? _errorMessage;
  DateTime? _recordingStartedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App background/inactive bo'lsa kamera muammoga uchraydi —
    // recording'ni darhol to'xtatamiz va camera dispose.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _abortRecording();
    }
  }

  Future<void> _abortRecording() async {
    _progressTimer?.cancel();
    if (_isRecording) {
      try {
        final path = await _service.stopRecording();
        if (path != null) await _deleteFile(path);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isRecording = false;
          _progress = 0.0;
        });
      }
    }
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameraPerm = await Permission.camera.request();
      final micPerm = await Permission.microphone.request();

      if (!cameraPerm.isGranted || !micPerm.isGranted) {
        if (mounted) {
          setState(() {
            _errorMessage = 'videoRecording.permissionRequired'.tr();
          });
        }
        return;
      }

      await _service.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'videoRecording.cameraError'.tr(
            namedArgs: {'error': '$e'},
          );
        });
      }
    }
  }

  Future<void> _onLongPressStart() async {
    if (!_isInitialized || _isRecording) return;

    try {
      await _service.startRecording(
        onMaxDurationReached: _stopRecording,
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _progress = 0.0;
        _recordingStartedAt = DateTime.now();
      });

      const totalMs = VideoRecorderService.maxDurationSeconds * 1000;
      var elapsedMs = 0;

      _progressTimer?.cancel();
      _progressTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (timer) {
          elapsedMs += 100;
          if (mounted) {
            setState(() {
              _progress = (elapsedMs / totalMs).clamp(0.0, 1.0);
            });
          }
          if (elapsedMs >= totalMs) timer.cancel();
        },
      );
    } catch (e) {
      debugPrint('Yozish boshlash xatosi: $e');
    }
  }

  void _onLongPressEnd() {
    if (_isRecording) _stopRecording();
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    _progressTimer?.cancel();

    final startedAt = _recordingStartedAt;
    final actualElapsed = startedAt != null
        ? DateTime.now().difference(startedAt)
        : Duration.zero;
    final isTooShort = actualElapsed < _minDuration;

    final filePath = await _service.stopRecording();

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _progress = 0.0;
      _recordingStartedAt = null;
    });

    if (isTooShort) {
      // Juda qisqa — faylni tashlab, foydalanuvchini ogohlantiramiz.
      if (filePath != null) await _deleteFile(filePath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('videoRecording.tooShort'.tr()),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (filePath != null) {
      final durationSeconds = actualElapsed.inSeconds.clamp(
        1,
        VideoRecorderService.maxDurationSeconds,
      );
      // Preview ekraniga o'tamiz — bola Send/Bekor tanlaydi.
      context.pushReplacement(
        '/video-preview',
        extra: VideoPreviewArgs(
          videoPath: filePath,
          durationSeconds: durationSeconds,
          requestId: widget.requestId,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressTimer?.cancel();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(AppIcons.close,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    )
                  else if (_isInitialized) ...[
                    RecordingProgressRing(
                      progress: _progress,
                      size: 280,
                      child: CircularCameraPreview(
                        controller: _service.controller!,
                        size: 280,
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (_isRecording)
                      Text(
                        'videoRecording.timer'.tr(
                          namedArgs: {
                            'current':
                                '${(_progress * VideoRecorderService.maxDurationSeconds).toInt()}',
                            'total':
                                '${VideoRecorderService.maxDurationSeconds}',
                          },
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        'videoRecording.recordHint'.tr(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    const SizedBox(height: 32),
                    RecordButton(
                      isRecording: _isRecording,
                      onLongPressStart: _onLongPressStart,
                      onLongPressEnd: _onLongPressEnd,
                    ),
                  ] else
                    const CircularProgressIndicator(color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
