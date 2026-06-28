// ─────────────────────────────────────────────────────────────────────
// RoundVideoBubble — Telegram-style yumaloq video xabar bubbleg'i.
// ─────────────────────────────────────────────────────────────────────
//
// Voice bubble bilan parallel:
//   - chap/o'ng align (isOwn)
//   - lazy signed URL fetch (Backend `getFileUrl`)
//   - thumbnail = DISK-keshlangan JPG (MEM-3: avval har bubble jonli
//     VideoPlayerController ushlab turardi — 30 xabarda 30 native pleyer!)
//   - tap → fullscreen autoplay dialog (pleyer FAQAT shu yerda ochiladi)
//   - vaqt + ✓/✓✓ ko'rsatkichi yumaloq disk ostida
//
// Yumaloq aspect-ratio uchun ClipOval ichida `Image.file(cover)` —
// video portret yoki landshaft bo'lsa ham doiraning to'liq markazidan
// kesib olinadi (Telegram standartiga mos).

import 'dart:io';

import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/features/video_message/data/models/video_message.dart';
import 'package:farzandim/features/video_message/data/repositories/backend_video_message_repository.dart';
import 'package:farzandim/features/voice_message/data/services/video_thumb_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
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

  /// Ota-ona yuborganmi (o'ng/chap tomon).
  final bool isOwn;

  @override
  ConsumerState<RoundVideoBubble> createState() => _RoundVideoBubbleState();
}

class _RoundVideoBubbleState extends ConsumerState<RoundVideoBubble> {
  File? _thumbFile;
  String? _signedUrl;
  bool _loadingThumb = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Build paytida ishlamaymiz — lifecycle/ref tayyor bo'lgach.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadThumbnail());
  }

  Future<void> _loadThumbnail() async {
    if (!mounted) return;
    try {
      // Proxy stream URL — signed URL telefondan yetib bo'lmaydi (ichki
      // MinIO manzili).
      final url = ref
          .read(backendVideoMessageRepositoryProvider)
          .videoStreamUrl(widget.message.id);
      _signedUrl = url;
      // MEM-3: jonli VideoPlayerController O'RNIGA disk-keshlangan JPG.
      // Birinchi marta: video yuklab olinib bitta kadr JPG qilinadi;
      // keyin abadiy keshdan (0 tarmoq, 0 native pleyer).
      final thumb = await VideoThumbCache.getThumb(
        messageId: widget.message.id,
        videoUrl: url,
        dio: ref.read(dioClientProvider),
      );
      if (!mounted) return;
      setState(() {
        _thumbFile = thumb;
        _loadingThumb = false;
        _failed = thumb == null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingThumb = false;
        _failed = true;
      });
    }
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
    // Proxy stream URL (signed URL telefondan yetib bo'lmaydi).
    final url =
        _signedUrl ??
        ref
            .read(backendVideoMessageRepositoryProvider)
            .videoStreamUrl(widget.message.id);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _FullscreenVideoDialog(videoUrl: url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwn = widget.isOwn;
    final msg = widget.message;

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
                        color: AppColors.surface,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Thumbnail (keshlangan birinchi kadr JPG).
                            if (_thumbFile != null)
                              Image.file(
                                _thumbFile!,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(
                                    SolarIconsBold.videocamera,
                                    color: AppColors.textTertiary,
                                    size: 36,
                                  ),
                                ),
                              )
                            else if (_loadingThumb)
                              Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            else
                              Center(
                                child: Icon(
                                  SolarIconsBold.videocamera,
                                  color: AppColors.textTertiary,
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
                                    SolarIconsBold.play,
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
                      _formatTime(msg.createdAt),
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                        fontSize: 11,
                      ),
                    ),
                    if (isOwn) ...[
                      const SizedBox(width: 4),
                      Icon(
                        msg.status == VideoMessageStatus.seen
                            ? SolarIconsBold.checkSquare
                            : SolarIconsBold.checkCircle,
                        size: 14,
                        color: msg.status == VideoMessageStatus.seen
                            ? Colors.blue.shade400
                            : AppColors.textSecondary.withValues(alpha: 0.7),
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
    final screenSize = MediaQuery.sizeOf(context);
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
        child: ColoredBox(
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
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                Positioned(
                  top: 40,
                  right: 16,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(
                        SolarIconsBold.closeCircle,
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
