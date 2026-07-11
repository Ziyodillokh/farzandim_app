// ─────────────────────────────────────────────────────────────────────
// RoundVideoBubble — Telegram-style yumaloq video xabar bubbleg'i.
// ─────────────────────────────────────────────────────────────────────
//
// Voice bubble bilan parallel:
//   - chap/o'ng align (isOwn)
//   - lazy signed URL fetch (Backend `getFileUrl`)
//   - thumbnail = videoning birinchi kadri (paused VideoPlayer)
//   - tap → fullscreen autoplay dialog
//   - vaqt + ✓/✓✓ ko'rsatkichi yumaloq disk ostida
//
// Child App perspektivasi: `isOwn = sender == 'child'` — o'zining yuborgani
// o'ng tomonda, Parent App'dan kelgani chap tomonda.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/video_message/data/models/video_message.dart';
import 'package:farzandim_child/features/video_message/data/repositories/backend_video_message_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// Doiraning diametri (Telegram'da odatda ~200, biroz kichikroq olamiz).
const double _bubbleDiameter = 180;

/// Telegram'cha yumaloq video bubble.
class RoundVideoBubble extends ConsumerStatefulWidget {
  const RoundVideoBubble({
    required this.message,
    required this.isOwn,
    super.key,
  });

  /// Ko'rsatilayotgan video xabar.
  final VideoMessage message;

  /// Bola o'zi yuborganmi (Child App perspektivasi — o'ng/chap tomon).
  final bool isOwn;

  @override
  ConsumerState<RoundVideoBubble> createState() => _RoundVideoBubbleState();
}

class _RoundVideoBubbleState extends ConsumerState<RoundVideoBubble> {
  VideoPlayerController? _thumbController;
  String? _signedUrl;
  bool _loadingThumb = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Build paytida controller initialize qilmaymiz — lifecycle/ref
    // tayyor bo'lgach.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadThumbnail());
  }

  Future<void> _loadThumbnail() async {
    if (!mounted) return;
    final id = widget.message.id;
    if (id == null) {
      if (!mounted) return;
      setState(() {
        _loadingThumb = false;
        _failed = true;
      });
      return;
    }
    try {
      final url = await ref
          .read(backendVideoMessageRepositoryProvider)
          .getFileUrl(id);
      if (url == null || url.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loadingThumb = false;
          _failed = true;
        });
        return;
      }
      _signedUrl = url;
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      // Birinchi kadrni ko'rsatish uchun pause holatida 0.0 ga seek.
      await controller.seekTo(Duration.zero);
      await controller.setVolume(0);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _thumbController = controller;
        _loadingThumb = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingThumb = false;
        _failed = true;
      });
    }
  }

  @override
  void dispose() {
    _thumbController?.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '0:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openFullscreen() async {
    // Signed URL hali bo'lmasa — fetch (thumbnail xato bergan bo'lsa).
    var url = _signedUrl;
    if (url == null || url.isEmpty) {
      final id = widget.message.id;
      if (id == null) return;
      url = await ref
          .read(backendVideoMessageRepositoryProvider)
          .getFileUrl(id);
    }
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('voiceChat.loadFailed'.tr()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _FullscreenVideoDialog(videoUrl: url!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwn = widget.isOwn;
    final msg = widget.message;
    final createdAt = msg.createdAt ?? DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: isOwn
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (isOwn) const Spacer(),
          Flexible(
            flex: 5,
            child: Column(
              crossAxisAlignment: isOwn
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _openFullscreen,
                  child: SizedBox(
                    width: _bubbleDiameter,
                    height: _bubbleDiameter,
                    child: ClipOval(
                      child: ColoredBox(
                        color: const Color(0xFF1C232B),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Thumbnail (birinchi kadr) yoki placeholder.
                            if (_thumbController != null &&
                                _thumbController!.value.isInitialized)
                              FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _thumbController!.value.size.width,
                                  height: _thumbController!.value.size.height,
                                  child: VideoPlayer(_thumbController!),
                                ),
                              )
                            else if (_loadingThumb)
                              const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF216BFF),
                                  ),
                                ),
                              )
                            else
                              const Center(
                                child: Icon(
                                  Icons.videocam_off,
                                  color: Color(0x8CFFFFFF),
                                  size: 36,
                                ),
                              ),

                            // Yarim-shaffof qora overlay (kontrast uchun).
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.35),
                                  ],
                                ),
                              ),
                            ),

                            // Markazdagi play tugmasi.
                            if (!_loadingThumb && !_failed)
                              Center(
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    AppIcons.play,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),

                            // Pastdagi davomiyligi capsule.
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 14,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _formatDuration(msg.durationSeconds),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(createdAt),
                      style: TextStyle(
                        color: const Color(0x8CFFFFFF),
                        fontSize: 11,
                      ),
                    ),
                    if (isOwn) ...[
                      const SizedBox(width: 4),
                      Icon(
                        msg.status == VideoMessageStatus.seen
                            ? AppIcons.success
                            : Icons.done,
                        size: 14,
                        color: msg.status == VideoMessageStatus.seen
                            ? Colors.blue.shade400
                            : const Color(0x8CFFFFFF),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!isOwn) const Spacer(),
        ],
      ),
    );
  }
}

/// Fullscreen video player dialog.
class _FullscreenVideoDialog extends StatefulWidget {
  const _FullscreenVideoDialog({required this.videoUrl});

  final String videoUrl;

  @override
  State<_FullscreenVideoDialog> createState() => _FullscreenVideoDialogState();
}

class _FullscreenVideoDialogState extends State<_FullscreenVideoDialog> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller
          ..setLooping(true)
          ..play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // Round player diameter — ekran kichik tomoni ~85%.
    final diameter =
        (screenSize.width < screenSize.height
            ? screenSize.width
            : screenSize.height) *
        0.85;
    final videoAr = _controller.value.aspectRatio == 0
        ? 1.0
        : _controller.value.aspectRatio;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.black.withValues(alpha: 0.95),
          child: SizedBox.expand(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_ready)
                  // Telegram-style — yumaloq cropped video markazda.
                  SizedBox(
                    width: diameter,
                    height: diameter,
                    child: ClipOval(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: diameter,
                          height: diameter / videoAr,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(color: Color(0xFF216BFF)),
                  ),
                Positioned(
                  top: 40,
                  right: 16,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(
                        AppIcons.close,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
