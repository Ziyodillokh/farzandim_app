// ─────────────────────────────────────────────────────────────────────
// round_video_player — Dumaloq video xabarni to'liq ekranda eshittirish
// ─────────────────────────────────────────────────────────────────────
//
// Chat detalidagi dumaloq video xabar bosilganda ochiladi. `video_player`
// bilan o'ynaydi (web: blob URL, qurilma: fayl). Istalgan joyga bosilsa
// yopiladi.

import 'package:farzandim/features/chat/data/video/video_capture_factory.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Dumaloq video pleer oynasini ochadi.
void showRoundVideoPlayer(BuildContext context, String url) {
  showGeneralDialog<void>(
    context: context,
    barrierColor: const Color(0xF2000000),
    barrierLabel: 'play',
    pageBuilder: (_, __, ___) => _PlayerOverlay(url: url),
    transitionBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

class _PlayerOverlay extends StatefulWidget {
  const _PlayerOverlay({required this.url});

  final String url;

  @override
  State<_PlayerOverlay> createState() => _PlayerOverlayState();
}

class _PlayerOverlayState extends State<_PlayerOverlay> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = createVideoController(widget.url);
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          _controller
            ..setLooping(true)
            ..play();
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: ClipOval(
                child: _ready
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      )
                    : const ColoredBox(
                        color: Color(0xFF2A3340),
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
