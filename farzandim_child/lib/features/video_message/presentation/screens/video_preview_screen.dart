// ─────────────────────────────────────────────────────────────────────
// VideoPreviewScreen — yozilgan video preview + Send/Cancel
// ─────────────────────────────────────────────────────────────────────
//
// VideoRecordingScreen tugagach `videoPath` + `durationSeconds` bilan
// shu ekranga o'tadi. Foydalanuvchi videoni dumaloq preview'da loop
// ko'radi va "Yuborish" yoki "Bekor" tanlaydi.
//
// "Yuborish" → `videoMessageUploadProvider` orqali Firebase Storage
// upload + Firestore document. Progress halqada ko'rinadi.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/video_message/presentation/providers/video_message_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

class VideoPreviewArgs {
  const VideoPreviewArgs({
    required this.videoPath,
    required this.durationSeconds,
    this.requestId,
  });

  final String videoPath;
  final int durationSeconds;

  /// Parent so'roviga javob bo'lsa — request hujjat ID'si.
  /// `null` bo'lsa bola o'z xohishi bilan yozayapti.
  final String? requestId;
}

class VideoPreviewScreen extends ConsumerStatefulWidget {
  const VideoPreviewScreen({required this.args, super.key});

  final VideoPreviewArgs args;

  @override
  ConsumerState<VideoPreviewScreen> createState() =>
      _VideoPreviewScreenState();
}

class _VideoPreviewScreenState
    extends ConsumerState<VideoPreviewScreen> {
  late VideoPlayerController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.args.videoPath));
    _controller.initialize().then((_) {
      if (!mounted) return;
      _controller.setLooping(true);
      _controller.setVolume(0); // selfie video — ovozsiz preview
      _controller.play();
      setState(() => _isReady = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _deleteTempFile() async {
    try {
      final file = File(widget.args.videoPath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _onSend() async {
    final ok = await ref
        .read(videoMessageUploadProvider.notifier)
        .send(
          videoFile: File(widget.args.videoPath),
          durationSeconds: widget.args.durationSeconds,
          requestId: widget.args.requestId,
        );

    if (!mounted) return;
    if (ok) {
      // Yuborilgach mahalliy faylni tozalaymiz — OS keshini band qilmasin.
      await _deleteTempFile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('videoRecording.sentSnack'.tr()),
          backgroundColor: AppColors.success,
        ),
      );
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          ref.read(videoMessageUploadProvider.notifier).reset();
          Navigator.of(context).pop();
        }
      });
    } else {
      final err = ref.read(videoMessageUploadProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'videoRecording.errorPrefix'.tr(
              namedArgs: {
                'error':
                    err ?? 'videoRecording.sendErrorFallback'.tr(),
              },
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _onCancel() async {
    // Bekor — fayl OS keshini band qilmasligi uchun darhol o'chiramiz.
    await _deleteTempFile();
    if (!mounted) return;
    ref.read(videoMessageUploadProvider.notifier).reset();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final upload = ref.watch(videoMessageUploadProvider);
    final isUploading = upload.status == UploadStatus.uploading;
    final isSent = upload.status == UploadStatus.sent;

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
                onPressed: isUploading ? null : _onCancel,
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 280,
                            height: 280,
                            child: _isReady
                                ? FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: 280,
                                      height: 280 /
                                          _controller.value.aspectRatio,
                                      child:
                                          VideoPlayer(_controller),
                                    ),
                                  )
                                : const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        if (isUploading || isSent)
                          SizedBox(
                            width: 280,
                            height: 280,
                            child: CircularProgressIndicator(
                              value: upload.progress,
                              strokeWidth: 6,
                              color: AppColors.primary,
                              // ignore: deprecated_member_use
                              backgroundColor: Colors.white.withOpacity(0.2),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    isSent
                        ? 'videoRecording.sentStatus'.tr()
                        : isUploading
                            ? 'videoRecording.uploadingPercent'.tr(
                                namedArgs: {
                                  'percent':
                                      '${(upload.progress * 100).toInt()}',
                                },
                              )
                            : 'videoRecording.durationLabel'.tr(
                                namedArgs: {
                                  'seconds':
                                      '${widget.args.durationSeconds}',
                                },
                              ),
                    style: TextStyle(
                      color: isSent
                          ? AppColors.success
                          : isUploading
                              ? AppColors.primary
                              : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (!isUploading && !isSent)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _onCancel,
                          icon: const Icon(AppIcons.delete),
                          label: Text(
                              'videoRecording.cancelButton'.tr()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            side: const BorderSide(
                                color: Colors.white24),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _onSend,
                          icon: const Icon(AppIcons.send, size: 18),
                          label:
                              Text('videoRecording.sendButton'.tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
