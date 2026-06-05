// ─────────────────────────────────────────────────────────────────────
// AudioPlayerScreen — full screen audio player (PDF p11)
// ─────────────────────────────────────────────────────────────────────
//
// Top: ✕, sleep timer indicator, ⋮.
// Markazda 240x240 cover + title + author.
// Slider + vaqt + controls (replay_10 / play-pause 72px / forward_10).
// Pastda: tezlik tugma (1.0x ▼), like (❤️ — placeholder).
//
// Menu ⋮ → Tezlik / Uyqu taymeri / Tafsilotlar (3 ta nested sheet).

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'dart:ui';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audio_player_state.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audio_player_provider.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioPlayerScreen extends ConsumerWidget {
  const AudioPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerProvider);

    if (!state.hasAudio) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final book = state.currentBook!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred background — cover rasmidan, kontent ustida o'qib bo'ladigan qiladi.
          if (book.coverUrl.isNotEmpty)
            Image.network(
              book.coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const GradientBackground(child: SizedBox.shrink()),
            )
          else
            const GradientBackground(child: SizedBox.shrink()),
          // Blur + qoramtir overlay
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.55),
            ),
          ),
          // Pastdan tepaga qora gradient — kontent ostida o'qishni
          // osonlashtirish va premium "deep" tuyg'usi.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  // ignore: deprecated_member_use
                  Colors.black.withOpacity(0.25),
                  // ignore: deprecated_member_use
                  Colors.black.withOpacity(0.85),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _TopBar(book: book, state: state),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Cover(book: book),
                        const SizedBox(height: 28),
                        Text(
                          book.author,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                            // ignore: deprecated_member_use
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _SliderRow(state: state),
                        const SizedBox(height: 16),
                        _Controls(state: state, book: book),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top bar ─────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.book, required this.state});

  final AudiobookModel book;
  final AudioPlayerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _GlassIconButton(
            icon: Icons.keyboard_arrow_down_rounded,
            onTap: () => Navigator.pop(context),
          ),
          if (state.hasSleepTimer)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      // ignore: deprecated_member_use
                      color: Colors.white.withOpacity(0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(AppIcons.hourglass,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _formatDuration(state.sleepTimerRemaining),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          _GlassIconButton(
            icon: Icons.more_horiz_rounded,
            onTap: () => _openMenu(context, book),
          ),
        ],
      ),
    );
  }

  void _openMenu(BuildContext context, AudiobookModel book) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AudioMenuSheet(book: book),
    );
  }
}

// ─── Cover ───────────────────────────────────────────────────────────

class _Cover extends StatelessWidget {
  const _Cover({required this.book});

  final AudiobookModel book;

  @override
  Widget build(BuildContext context) {
    // 3:4 vertikal — kitob muqovasi proporsiyasi
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280, maxHeight: 380),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: BoxDecoration(
            color: book.coverColor,
            borderRadius: BorderRadius.circular(20),
            image: book.coverUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(book.coverUrl),
                    fit: BoxFit.cover,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.55),
                blurRadius: 40,
                spreadRadius: 4,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: book.coverUrl.isEmpty
              ? Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      AppIcons.speaker,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

// ─── Slider + vaqt ───────────────────────────────────────────────────

class _SliderRow extends ConsumerWidget {
  const _SliderRow({required this.state});

  final AudioPlayerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxSec = state.duration.inSeconds == 0
        ? 1.0
        : state.duration.inSeconds.toDouble();

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape:
                const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: Colors.white,
            // ignore: deprecated_member_use
            inactiveTrackColor: Colors.white.withOpacity(0.25),
            thumbColor: Colors.white,
            // ignore: deprecated_member_use
            overlayColor: Colors.white.withOpacity(0.15),
          ),
          child: Slider(
            value: state.position.inSeconds
                .toDouble()
                .clamp(0.0, maxSec),
            max: maxSec,
            onChanged: (val) {
              ref
                  .read(audioPlayerProvider.notifier)
                  .seek(Duration(seconds: val.toInt()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(state.position),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  // ignore: deprecated_member_use
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
              Text(
                _formatDuration(state.duration),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  // ignore: deprecated_member_use
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Controls ────────────────────────────────────────────────────────

class _Controls extends ConsumerWidget {
  const _Controls({required this.state, required this.book});

  final AudioPlayerState state;
  final AudiobookModel book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(audioSpeedProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Tezlik chip (chap)
        GestureDetector(
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => const _SpeedPickerSheet(),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Text(
                '${_formatSpeed(speed)}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        // 15s ortga
        _SeekButton(
          icon: Icons.replay_10_rounded,
          onTap: () =>
              ref.read(audioPlayerProvider.notifier).seekBackward(),
        ),
        // Play/Pause (katta oq doira)
        GestureDetector(
          onTap: () {
            final notifier = ref.read(audioPlayerProvider.notifier);
            if (state.isPlaying) {
              notifier.pause();
            } else {
              notifier.resume();
            }
          },
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              state.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.black,
              size: 44,
            ),
          ),
        ),
        // 15s oldinga
        _SeekButton(
          icon: Icons.forward_10_rounded,
          onTap: () =>
              ref.read(audioPlayerProvider.notifier).seekForward(),
        ),
        // O'ng bo'sh joy — chap "1x" bilan simmetriya
        const SizedBox(width: 48, height: 48),
      ],
    );
  }
}

class _SeekButton extends StatelessWidget {
  const _SeekButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Icon(
          icon,
          color: Colors.white,
          size: 38,
        ),
      ),
    );
  }
}

// Yumshoq glass tugma — top bar uchun.
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                // ignore: deprecated_member_use
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

String _formatSpeed(double speed) {
  if (speed == speed.roundToDouble()) return speed.toInt().toString();
  return speed.toString();
}

// ─── Speed picker sheet ─────────────────────────────────────────────

class _SpeedPickerSheet extends ConsumerWidget {
  const _SpeedPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSpeed = ref.watch(audioSpeedProvider);
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    return _SheetContainer(
      title: 'Tezlik',
      children: [
        for (final speed in speeds)
          ListTile(
            title: Text(
              '${speed}x',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            trailing: speed == currentSpeed
                ? const Icon(AppIcons.check, color: AppColors.primary)
                : null,
            onTap: () {
              ref.read(audioSpeedProvider.notifier).state = speed;
              ref.read(audioPlayerProvider.notifier).setSpeed(speed);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }
}

// ─── Audio menu sheet ───────────────────────────────────────────────

class _AudioMenuSheet extends ConsumerWidget {
  const _AudioMenuSheet({required this.book});

  final AudiobookModel book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(audioSpeedProvider);
    final hasSleepTimer = ref.watch(audioPlayerProvider).hasSleepTimer;

    return _SheetContainer(
      children: [
        ListTile(
          leading: const Icon(Icons.speed, color: AppColors.primary),
          title: const Text('Tezlik',
              style: TextStyle(color: AppColors.textPrimary)),
          subtitle: Text(
            '${speed}x',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
          trailing: const Icon(AppIcons.chevronRight,
              color: AppColors.textSecondary),
          onTap: () {
            Navigator.pop(context);
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => const _SpeedPickerSheet(),
            );
          },
        ),
        ListTile(
          leading: const Icon(AppIcons.hourglass, color: AppColors.primary),
          title: const Text(
            'Uyqu taymeri',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          subtitle: Text(
            hasSleepTimer ? 'Faol' : "O'chirilgan",
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
          trailing: const Icon(AppIcons.chevronRight,
              color: AppColors.textSecondary),
          onTap: () {
            Navigator.pop(context);
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => const _SleepTimerSheet(),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline,
              color: AppColors.primary),
          title: const Text(
            'Tafsilotlar',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          trailing: const Icon(AppIcons.chevronRight,
              color: AppColors.textSecondary),
          onTap: () {
            Navigator.pop(context);
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => _DetailsSheet(book: book),
            );
          },
        ),
      ],
    );
  }
}

// ─── Sleep timer sheet ───────────────────────────────────────────────

class _SleepTimerSheet extends ConsumerWidget {
  const _SleepTimerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTimer = ref.watch(audioPlayerProvider).hasSleepTimer;
    final notifier = ref.read(audioPlayerProvider.notifier);

    return _SheetContainer(
      title: 'Uyqu taymeri',
      children: [
        ListTile(
          title: const Text(
            "O'chirish",
            style: TextStyle(color: AppColors.textPrimary),
          ),
          trailing: !hasTimer
              ? const Icon(AppIcons.check, color: AppColors.primary)
              : null,
          onTap: () {
            notifier.cancelSleepTimer();
            Navigator.pop(context);
          },
        ),
        for (final min in const [5, 10, 15, 20, 30, 45])
          ListTile(
            title: Text(
              '$min daqiqa',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            onTap: () {
              notifier.startSleepTimer(min);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Uyqu taymeri: $min daqiqa'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ─── Details sheet ──────────────────────────────────────────────────

class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({required this.book});

  final AudiobookModel book;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Tafsilotlar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _row('Nomi', book.title),
              _row('Muallif', book.author),
              _row('Kategoriya', book.category),
              _row('Davomiyligi', book.duration),
              _row('Tinglashlar', '${book.listenCount}'),
              const SizedBox(height: 16),
              const Text(
                'Tavsif',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                book.description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
              if (book.hashtags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in book.hashtags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          // ignore: deprecated_member_use
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sheet container shared shell ───────────────────────────────────

class _SheetContainer extends StatelessWidget {
  const _SheetContainer({required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              )
            else
              const SizedBox(height: 16),
            if (title != null)
              const Divider(color: AppColors.border, height: 1),
            ...children,
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────

String _formatDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = two(d.inMinutes.remainder(60));
  final s = two(d.inSeconds.remainder(60));
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
