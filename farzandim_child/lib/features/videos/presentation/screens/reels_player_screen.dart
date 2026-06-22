// ─────────────────────────────────────────────────────────────────────
// ReelsPlayerScreen — Instagram/TikTok kabi vertikal reels
// ─────────────────────────────────────────────────────────────────────
//
// Faqat ≤90 sekundlik videolar (`isReels == true`). PageView vertikal,
// active reel auto-play va loop. Tap pause/play. Pastda title +
// description overlay.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/videos/data/video_controller_factory.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:farzandim_child/features/videos/data/repositories/videos_backend_repository.dart';
import 'package:video_player/video_player.dart';

class ReelsPlayerScreen extends ConsumerStatefulWidget {
  const ReelsPlayerScreen({required this.initialVideo, super.key});

  final VideoModel initialVideo;

  @override
  ConsumerState<ReelsPlayerScreen> createState() =>
      _ReelsPlayerScreenState();
}

class _ReelsPlayerScreenState extends ConsumerState<ReelsPlayerScreen> {
  late final PageController _pageController;
  late final List<VideoModel> _reels;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Backend real ro'yxatdan reels filter qilish (mock emas).
    // Agar effective list bo'sh bo'lsa, hech bo'lmasa boshlang'ich video'ni
    // o'zi ko'rsatamiz (player sinmasligi uchun).
    final effective = ref.read(effectiveVideosProvider);
    // YouTube videolari bu yerda emas (alohida YouTube player'da) — vertikal
    // VideoPlayerController ularni o'ynay olmaydi.
    _reels = effective.where((v) => v.isReels && !v.isYouTube).toList();
    if (_reels.isEmpty) _reels = [widget.initialVideo];
    _currentIndex =
        _reels.indexWhere((v) => v.id == widget.initialVideo.id);
    if (_currentIndex < 0) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
    // Birinchi reel ko'rildi.
    _markViewed(_reels[_currentIndex].id);
  }

  // Ko'rishlar hisoblagichi — har reel bir marta sanaladi.
  final _viewed = <String>{};
  void _markViewed(String videoId) {
    if (!_viewed.add(videoId)) return;
    ref.read(videosBackendRepositoryProvider).markViewed(videoId);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            itemCount: _reels.length,
            onPageChanged: (i) {
              setState(() => _currentIndex = i);
              _markViewed(_reels[i].id);
            },
            itemBuilder: (_, i) {
              return _ReelItem(
                video: _reels[i],
                isActive: i == _currentIndex,
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(AppIcons.back,
                      color: Colors.white),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelItem extends StatefulWidget {
  const _ReelItem({required this.video, required this.isActive});

  final VideoModel video;
  final bool isActive;

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  late VideoPlayerController _controller;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _controller = videoControllerFor(widget.video.videoUrl);
    _controller.initialize().then((_) {
      if (!mounted) return;
      _controller.setLooping(true);
      if (widget.isActive) _controller.play();
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.play();
      _isPlaying = true;
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.pause();
      _isPlaying = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: _controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(
                    color: AppColors.parvozGreen),
          ),
          if (!_isPlaying)
            Center(
              child: Icon(
                AppIcons.play,
                // ignore: deprecated_member_use
                color: Colors.white.withOpacity(0.8),
                size: 80,
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.video.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.video.description,
                  style: TextStyle(
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
