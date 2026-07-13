// ─────────────────────────────────────────────────────────────────────
// AudioPlayerScreen — to'liq audio pleer (screenshot 1:1)
// ─────────────────────────────────────────────────────────────────────
//
// Layout:
//   ┌ SafeArea ─────────────────────────────────────────────────
//   │ [←]      "1-qism"                            [↑ share]
//   │          "A kite for a moon · Jane Yolen"
//   │
//   │                ┌────────────────┐
//   │                │                │
//   │                │     COVER      │  (240 × 320, radius 14)
//   │                │                │
//   │                └────────────────┘
//   │
//   │  ━━━━━━━━━━●━━━━━━━━━━━━━━━━━━━━━━━━━━  (blue → gray)
//   │  09:40                                 40:12
//   │
//   │   1.5x   ⟲15   [▶]   ⟳15   ⏱
//   │
//   └───────────────────────────────────────────────────────────
//
// Ranglar:
//   - Sahifa fon: #0B0F14
//   - Cover glow: yumshoq navy
//   - Progress aktiv: #216BFF (ko'k)
//   - Play tugma: tund kul-qora doira (#2A2F38)
//   - Ikon rangi: oq / #B6BCC5

import 'package:cached_network_image/cached_network_image.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audio_player_state.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_series.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audio_player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

const _pageBg = Color(0xFF0B0F14);
const _tileBg = Color(0xFF1A2029);
const _blue = Color(0xFF216BFF);
const _trackInactive = Color(0xFF2A323D);
const _textMuted = Color(0xFF9CA3AF);
const _iconMuted = Color(0xFFB6BCC5);
const _playBg = Color(0xFF2A2F38);

class AudioPlayerScreen extends ConsumerWidget {
  const AudioPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerProvider);

    // Audio xatosi bo'lsa foydalanuvchiga bildirish (jim qolmaslik).
    ref.listen<String?>(audioPlayerProvider.select((s) => s.error), (
      prev,
      err,
    ) {
      if (err != null && err.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    });

    if (!state.hasAudio) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final book = state.currentBook!;
    // Sarlavhadagi qism raqami: "Mehrobdan chayon 14" -> "14-qism".
    final (seriesTitle, partNo) = splitSeriesTitle(book.title);

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              title: partNo != null ? '$partNo-qism' : book.title,
              subtitle: partNo != null
                  ? '$seriesTitle · ${book.author}'
                  : book.author,
              onBack: () => Navigator.of(context).maybePop(),
              onShare: () => _showShareInfo(context),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Cover(book: book),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _ProgressBar(state: state),
                        const SizedBox(height: 32),
                        _Controls(state: state),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
          ],
        ),
      ),
    );
  }

  void _showShareInfo(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ulashish tez orada qo\'shiladi'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Top bar — ← [Title/Subtitle] [↑ share]
// ═════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onShare,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Boshqa sahifalar bilan bir xil: header tepaga yopishmasin.
      padding: const EdgeInsets.fromLTRB(16, 54, 16, 8),
      child: Row(
        children: [
          _IconTile(icon: SolarIconsOutline.arrowLeft, onTap: onBack),
          Expanded(
            child: Column(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _IconTile(icon: SolarIconsOutline.uploadMinimalistic, onTap: onShare),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _tileBg,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Cover — o'rtada katta muqova (yumshoq soya bilan)
// ═════════════════════════════════════════════════════════════════════
class _Cover extends StatelessWidget {
  const _Cover({required this.book});

  final AudiobookModel book;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240, maxHeight: 320),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 34,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: book.coverUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: book.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: book.coverColor),
                      errorWidget: (_, __, ___) => _fallback(book),
                    )
                  : _fallback(book),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback(AudiobookModel book) {
    return Container(
      color: book.coverColor,
      alignment: Alignment.center,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.28),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          SolarIconsBold.headphonesRound,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Progress bar — aktiv qism ko'k, pozitsiya + davomiylik pastda
// ═════════════════════════════════════════════════════════════════════
class _ProgressBar extends ConsumerWidget {
  const _ProgressBar({required this.state});

  final AudioPlayerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxSec = state.duration.inSeconds == 0
        ? 1.0
        : state.duration.inSeconds.toDouble();
    final position = state.position.inSeconds.toDouble().clamp(0.0, maxSec);

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: _blue,
            inactiveTrackColor: _trackInactive,
            thumbColor: _blue,
            overlayColor: _blue.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: position,
            max: maxSec,
            onChanged: (v) => ref
                .read(audioPlayerProvider.notifier)
                .seek(Duration(seconds: v.toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(state.position),
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _fmt(state.duration),
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ═════════════════════════════════════════════════════════════════════
// Controls — [1.5x] ⟲15 [▶] ⟳15 [⏱]
// ═════════════════════════════════════════════════════════════════════
class _Controls extends ConsumerWidget {
  const _Controls({required this.state});

  final AudioPlayerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(audioSpeedProvider);
    final hasSleepTimer = state.hasSleepTimer;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SpeedButton(speed: speed, onTap: () => _openSpeedSheet(context)),
        _SeekButton(
          seconds: 15,
          direction: _SeekDirection.back,
          onTap: () => ref.read(audioPlayerProvider.notifier).seekBackward(),
        ),
        _PlayButton(
          isPlaying: state.isPlaying,
          onTap: () {
            final n = ref.read(audioPlayerProvider.notifier);
            if (state.isPlaying) {
              n.pause();
            } else {
              n.resume();
            }
          },
        ),
        _SeekButton(
          seconds: 15,
          direction: _SeekDirection.forward,
          onTap: () => ref.read(audioPlayerProvider.notifier).seekForward(),
        ),
        _SleepTimerButton(
          active: hasSleepTimer,
          onTap: () => _openSleepSheet(context),
        ),
      ],
    );
  }

  void _openSpeedSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SpeedSheet(),
    );
  }

  void _openSleepSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SleepSheet(),
    );
  }
}

// ─── Speed button ("1.5x" matn) ──────────────────────────────────────
class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.speed, required this.onTap});

  final double speed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: Text(
            '${_fmt(speed)}x',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(double s) {
    if (s == s.roundToDouble()) return s.toInt().toString();
    return s.toString();
  }
}

// ─── Seek button (⟲15 / ⟳15 — Solar Bold ikon + son ustida) ──────────
enum _SeekDirection { back, forward }

class _SeekButton extends StatelessWidget {
  const _SeekButton({
    required this.seconds,
    required this.direction,
    required this.onTap,
  });

  final int seconds;
  final _SeekDirection direction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              direction == _SeekDirection.back
                  ? SolarIconsOutline.rewind15SecondsBack
                  : SolarIconsOutline.rewind15SecondsForward,
              color: _iconMuted,
              size: 44,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Play / Pause tugma (katta dumaloq, oq ikon) ─────────────────────
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.isPlaying, required this.onTap});

  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: _playBg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }
}

// ─── Sleep timer tugma ───────────────────────────────────────────────
class _SleepTimerButton extends StatelessWidget {
  const _SleepTimerButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: Icon(
            active ? SolarIconsBold.stopwatch : SolarIconsOutline.stopwatch,
            color: active ? _blue : _iconMuted,
            size: 26,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Bottom sheet — tezlik tanlash
// ═════════════════════════════════════════════════════════════════════
class _SpeedSheet extends ConsumerWidget {
  const _SpeedSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(audioSpeedProvider);
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    return _Sheet(
      title: 'Tezlik',
      children: [
        for (final s in speeds)
          _SheetTile(
            label: '${s}x',
            selected: s == current,
            onTap: () {
              ref.read(audioSpeedProvider.notifier).state = s;
              ref.read(audioPlayerProvider.notifier).setSpeed(s);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Bottom sheet — uyqu taymeri
// ═════════════════════════════════════════════════════════════════════
class _SleepSheet extends ConsumerWidget {
  const _SleepSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(audioPlayerProvider.notifier);
    final hasTimer = ref.watch(audioPlayerProvider).hasSleepTimer;

    return _Sheet(
      title: 'Uyqu taymeri',
      children: [
        _SheetTile(
          label: "O'chirish",
          selected: !hasTimer,
          onTap: () {
            notifier.cancelSleepTimer();
            Navigator.pop(context);
          },
        ),
        for (final m in const [5, 10, 15, 20, 30, 45])
          _SheetTile(
            label: '$m daqiqa',
            selected: false,
            onTap: () {
              notifier.startSleepTimer(m);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _tileBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _trackInactive,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        label,
        style: TextStyle(
          color: selected ? _blue : Colors.white,
          fontSize: 15,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: _blue, size: 22)
          : null,
    );
  }
}
