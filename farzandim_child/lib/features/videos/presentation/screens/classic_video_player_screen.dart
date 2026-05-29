// ─────────────────────────────────────────────────────────────────────
// ClassicVideoPlayerScreen — landscape player (PDF p8-9)
// ─────────────────────────────────────────────────────────────────────
//
// Top: back, title, settings ikon. Center: katta play/pause (auto-hide
// 4 sek). Bottom: progress slider + vaqt + lock ikon. Lock holatida
// faqat lock ikon ko'rinadi (long-press unlock). Sleep timer faol
// bo'lsa yuqori o'ngda hisoblagich.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'dart:async';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/videos/data/models/player_settings.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/presentation/providers/player_providers.dart';
import 'package:farzandim_child/features/videos/presentation/widgets/player_settings_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

class ClassicVideoPlayerScreen extends ConsumerStatefulWidget {
  const ClassicVideoPlayerScreen({required this.video, super.key});

  final VideoModel video;

  @override
  ConsumerState<ClassicVideoPlayerScreen> createState() =>
      _ClassicVideoPlayerScreenState();
}

class _ClassicVideoPlayerScreenState
    extends ConsumerState<ClassicVideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  Timer? _sleepTimer;
  Duration _sleepTimerRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.video.videoUrl),
    );

    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.play();
      _isPlaying = true;
      _startHideControlsTimer();
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _sleepTimer?.cancel();
    _controller.dispose();

    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    final settings = ref.read(playerSettingsProvider);
    if (settings.screenLocked) return;

    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideControlsTimer();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() => _isPlaying = !_isPlaying);
    _startHideControlsTimer();
  }

  void _startSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimerRemaining = Duration(minutes: minutes);

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_sleepTimerRemaining.inSeconds <= 0) {
        timer.cancel();
        _controller.pause();
        if (mounted) Navigator.pop(context);
      } else {
        setState(() {
          _sleepTimerRemaining = Duration(
            seconds: _sleepTimerRemaining.inSeconds - 1,
          );
        });
      }
    });
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const PlayerSettingsBottomSheet(),
    );
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(playerSettingsProvider);

    ref.listen<PlayerSettings>(playerSettingsProvider, (prev, next) {
      if (prev?.speed != next.speed) {
        _controller.setPlaybackSpeed(next.speed);
      }
      if (prev?.repeat != next.repeat) {
        _controller.setLooping(next.repeat);
      }
      if (prev?.sleepTimerMinutes != next.sleepTimerMinutes &&
          next.sleepTimerMinutes != null) {
        _startSleepTimer(next.sleepTimerMinutes!);
      }
      if (prev?.sleepTimerMinutes != null &&
          next.sleepTimerMinutes == null) {
        _sleepTimer?.cancel();
        _sleepTimer = null;
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            Center(
              child: _controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(
                      color: AppColors.primary),
            ),
            if (_showControls && !settings.screenLocked) _buildControls(),
            if (settings.screenLocked) _buildLockIndicator(),
            if (_sleepTimer != null && _sleepTimerRemaining.inSeconds > 0)
              _buildSleepTimerIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            // ignore: deprecated_member_use
            Colors.black.withOpacity(0.5),
            Colors.transparent,
            // ignore: deprecated_member_use
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(AppIcons.back,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(AppIcons.settings, color: Colors.white),
                    onPressed: _openSettings,
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                _isPlaying ? AppIcons.pause : Icons.play_circle,
                color: Colors.white,
                size: 64,
              ),
              onPressed: _togglePlay,
            ),
            const Spacer(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: _controller,
                    builder: (_, value, __) {
                      final maxSec = value.duration.inSeconds == 0
                          ? 1.0
                          : value.duration.inSeconds.toDouble();
                      return Slider(
                        value: value.position.inSeconds
                            .toDouble()
                            .clamp(0.0, maxSec),
                        max: maxSec,
                        activeColor: AppColors.primary,
                        // ignore: deprecated_member_use
                        inactiveColor: Colors.white.withOpacity(0.3),
                        onChanged: (val) {
                          _controller.seekTo(
                              Duration(seconds: val.toInt()));
                        },
                      );
                    },
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: _controller,
                          builder: (_, value, __) {
                            return Text(
                              '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.lock_outline,
                              color: Colors.white),
                          onPressed: () {
                            ref
                                .read(playerSettingsProvider.notifier)
                                .state = ref
                                .read(playerSettingsProvider)
                                .copyWith(screenLocked: true);
                            setState(() => _showControls = false);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockIndicator() {
    return Center(
      child: GestureDetector(
        onLongPress: () {
          ref.read(playerSettingsProvider.notifier).state = ref
              .read(playerSettingsProvider)
              .copyWith(screenLocked: false);
          _startHideControlsTimer();
          setState(() => _showControls = true);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(40),
          ),
          child: const Icon(Icons.lock,
              color: Colors.white, size: 32),
        ),
      ),
    );
  }

  Widget _buildSleepTimerIndicator() {
    return Positioned(
      top: 60,
      right: 16,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          // ignore: deprecated_member_use
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.hourglass, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              _formatDuration(_sleepTimerRemaining),
              style:
                  const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
