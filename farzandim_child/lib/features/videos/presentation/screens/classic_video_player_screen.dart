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
import 'package:farzandim_child/features/videos/data/video_controller_factory.dart';
import 'package:farzandim_child/features/videos/data/models/player_settings.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/data/repositories/videos_backend_repository.dart';
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
  bool _hasController = false;
  bool _initInFlight = false;
  bool _initializing = true;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  Timer? _sleepTimer;
  Duration _sleepTimerRemaining = Duration.zero;

  /// BoxFit.contain (default) — qora chiziqlar bilan to'liq video ko'rinadi.
  /// BoxFit.cover — to'liq ekran, ammo yon tomonlari kesiladi.
  /// Foydalanuvchi controls'da "fit" tugmasi bilan o'zgartiradi.
  BoxFit _videoFit = BoxFit.contain;

  /// Video init xato bo'lsa shu maydonga yoziladi → "Qaytadan" tugmasi.
  String? _initError;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // Ko'rishlar hisoblagichi (backend analitikasi) — ochilganda bir marta.
    ref.read(videosBackendRepositoryProvider).markViewed(widget.video.id);

    _initController();

    // listenManual — `ref.listen` `build()` ichida ba'zan tartibsiz
    // ishlaydi (registratsiya o'zgargandan keyin). listenManual darhol
    // ro'yxatdan o'tadi va widget life uchun saqlanadi.
    ref.listenManual<PlayerSettings>(playerSettingsProvider, (
      prev,
      next,
    ) async {
      if (!_controller.value.isInitialized) return;
      if (prev?.speed != next.speed) {
        await _controller.setPlaybackSpeed(next.speed);
      }
      if (prev?.repeat != next.repeat) {
        await _controller.setLooping(next.repeat);
      }
      if (prev?.sleepTimerMinutes != next.sleepTimerMinutes) {
        if (next.sleepTimerMinutes != null) {
          _startSleepTimer(next.sleepTimerMinutes!);
        } else {
          _sleepTimer?.cancel();
          _sleepTimer = null;
          _sleepTimerRemaining = Duration.zero;
          if (mounted) setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _sleepTimer?.cancel();
    if (_hasController) {
      _controller.removeListener(_onControllerUpdate);
      _controller.dispose();
    }

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  /// Video controller yaratish + init + xato handling. Retry uchun ham
  /// chaqiriladi — eski controller dispose qilinadi.
  ///
  /// MUHIM: `initialize()` ga 20s timeout — URL sekin/ulanmasa abadiy
  /// spinner o'rniga xato + "Qaytadan" tugmasi chiqadi (foydalanuvchi
  /// qotib qolmaydi).
  Future<void> _initController() async {
    // Re-entrancy guard — "Qaytadan" tugmasi ikki marta bosilsa, bir xil
    // controller ikki marta dispose bo'lib (ChangeNotifier-after-dispose
    // crash + native player leak) qolmasligi uchun.
    if (_initInFlight) return;
    _initInFlight = true;
    try {
      // Retry holati — eski controller'ni tozalab, UI'ni spinnerga qaytaramiz.
      // Eski instance'ni LOKALGA olamiz va bookkeeping'ni await'dan OLDIN
      // yangilaymiz — shu orada build() uni ishlatib qolmaydi (showCenter
      // _initializing bilan o'chadi). Birinchi chaqiruvda _hasController false
      // → bu blok o'tkazib yuboriladi (initState ichida setState yo'q).
      if (_hasController) {
        final old = _controller;
        _hasController = false;
        old.removeListener(_onControllerUpdate);
        if (mounted) {
          setState(() {
            _initError = null;
            _initializing = true;
          });
        }
        await old.dispose();
      }

      _controller = videoControllerFor(widget.video.videoUrl);
      _hasController = true;
      await _controller.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) {
        await _controller.dispose();
        _hasController = false;
        return;
      }
      // Video tugaganini aniqlash uchun (replay tugmasi + controls ko'rsatish).
      _controller.addListener(_onControllerUpdate);
      // Link orqali qo'shilgan video duration'i noma'lum bo'lsa, player
      // bilgan haqiqiy vaqtni backend'ga yuboramiz (ro'yxatda to'g'ri
      // ko'rinsin). Backend faqat hozir noma'lum bo'lsa yozadi.
      final realDur = _controller.value.duration.inSeconds;
      if (widget.video.durationSeconds <= 0 && realDur > 0) {
        ref
            .read(videosBackendRepositoryProvider)
            .reportDuration(widget.video.id, realDur);
      }
      // Initial settings'ni darhol qo'llash.
      final s = ref.read(playerSettingsProvider);
      await _controller.setPlaybackSpeed(s.speed);
      await _controller.setLooping(s.repeat);
      if (!mounted) return;
      setState(() => _initializing = false);
      await _controller.play();
      _startHideControlsTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _initError = "Videoni yuklab bo'lmadi. Internet aloqasini tekshiring.";
      });
    } finally {
      _initInFlight = false;
    }
  }

  /// Controller har yangilanganda — video tugasa controls'ni ko'rsatamiz
  /// (replay tugmasi ko'rinsin, qotib qolgan kadr ustida emas).
  void _onControllerUpdate() {
    if (!mounted) return;
    final v = _controller.value;
    final ended =
        v.duration > Duration.zero && v.position >= v.duration && !v.isPlaying;
    if (ended && !_showControls) {
      _hideControlsTimer?.cancel();
      setState(() => _showControls = true);
    }
  }

  void _toggleFit() {
    setState(() {
      _videoFit = _videoFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain;
    });
    _startHideControlsTimer();
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
    if (!_controller.value.isInitialized) return;
    final v = _controller.value;
    final ended = v.duration > Duration.zero && v.position >= v.duration;
    if (ended) {
      // Video tugagan — boshidan qayta o'ynaymiz.
      _controller.seekTo(Duration.zero);
      _controller.play();
    } else if (v.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {});
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
    // Settings'ni watch qilamiz UI ko'rsatish uchun (lock icon, sleep
    // timer matn). Real apply esa `initState`'dagi `listenManual` orqali.
    final settings = ref.watch(playerSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        // Ikki marta bos — fit (contain ↔ cover) toggle. YouTube-style.
        onDoubleTap: _toggleFit,
        child: Stack(
          children: [
            // Video qatlami — error / loading / playing 3 holat.
            Positioned.fill(child: _buildVideoLayer()),
            // Buffering indikator (ulanish sekin bo'lganda)
            if (_controller.value.isInitialized &&
                _controller.value.isBuffering)
              const Center(
                child: CircularProgressIndicator(color: AppColors.parvozGreen),
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

  /// Video qatlami:
  /// • Xato bo'lsa — retry tugmasi
  /// • Hali init bo'lmagan — spinner
  /// • Tayyor — FittedBox bilan rendered (contain yoki cover)
  Widget _buildVideoLayer() {
    if (_initError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _initError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _initController,
              icon: const Icon(Icons.refresh),
              label: const Text("Qaytadan urinib ko'rish"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.parvozGreen,
                foregroundColor: AppColors.parvozOnGreen,
              ),
            ),
          ],
        ),
      );
    }
    if (_initializing || !_controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.parvozGreen),
      );
    }
    // FittedBox bilan rasm size widget'ga moslashtiriladi. BoxFit.contain
    // (default) — to'liq video ko'rinadi, qora chiziqlar bilan. BoxFit.cover
    // — to'liq ekran, ammo yon tomonlari kesiladi. Foydalanuvchi double-tap
    // bilan o'zgartira oladi.
    return SizedBox.expand(
      child: FittedBox(
        fit: _videoFit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }

  /// Controls overlay — 3 mustaqil qatlam (Stack):
  ///   1. Yuqori/past qoraytirish gradienti (butun ekran).
  ///   2. MARKAZIY play/pause/replay tugmasi — TO'LIQ EKRAN markazida
  ///      (`Center`), panellar balandligidan VA notch'dan QAT'I NAZAR. Avval
  ///      Column flex ichida edi → past panel balandroq bo'lgani uchun tugma
  ///      markazdan tepada, landscape SafeArea esa o'ngga surardi.
  ///   3. Tepa (back/title/settings) + past (slider/vaqt/lock) panellar —
  ///      SafeArea ichida, Spacer bilan tepaga va pastga taqaladi.
  Widget _buildControls() {
    final showCenter =
        !_initializing && _controller.value.isInitialized && _initError == null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Gradient scrim — taplarni o'tkazadi (controls toggle uchun).
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        // 2. Markaziy tugma — ekran markazida.
        if (showCenter) Center(child: _buildCenterButton()),
        // 3. Panellar.
        SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const Spacer(),
              if (showCenter) _buildBottomBar(),
            ],
          ),
        ),
      ],
    );
  }

  /// Tepa panel — orqaga, sarlavha, sozlamalar.
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(AppIcons.back, color: Colors.white),
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
            icon: const Icon(AppIcons.settings, color: Colors.white),
            onPressed: _openSettings,
          ),
        ],
      ),
    );
  }

  /// Markaziy doira tugma — play / pause / replay (controller holatidan).
  /// Buffering paytida yashirinadi (build()'dagi spinner ko'rinadi).
  Widget _buildCenterButton() {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller,
      builder: (_, v, __) {
        if (v.isBuffering) return const SizedBox.shrink();
        final ended = v.duration > Duration.zero && v.position >= v.duration;
        final IconData icon = ended
            ? Icons.replay_rounded
            : (v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded);
        return GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 2,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 44),
          ),
        );
      },
    );
  }

  /// Past panel — progress slider + vaqt + lock.
  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _controller,
            builder: (_, value, __) {
              final maxSec = value.duration.inSeconds == 0
                  ? 1.0
                  : value.duration.inSeconds.toDouble();
              return SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Slider(
                  value: value.position.inSeconds.toDouble().clamp(0.0, maxSec),
                  max: maxSec,
                  activeColor: AppColors.parvozGreen,
                  inactiveColor: Colors.white.withValues(alpha: 0.3),
                  onChanged: (val) {
                    _controller.seekTo(Duration(seconds: val.toInt()));
                  },
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _controller,
                  builder: (_, value, __) {
                    return Text(
                      '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.lock_outline, color: Colors.white),
                  onPressed: () {
                    ref.read(playerSettingsProvider.notifier).state = ref
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
          child: const Icon(Icons.lock, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  Widget _buildSleepTimerIndicator() {
    return Positioned(
      top: 60,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
