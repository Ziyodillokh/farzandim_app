// ─────────────────────────────────────────────────────────────────────
// AudioPlayerScreen — Parvoz NIGHT/GLASS audio pleer (Premium Edition)
// ─────────────────────────────────────────────────────────────────────
//
// Fon: AppColors.parvozBg (solid navy — GradientBackground olib tashlandi).
// Cover: parvozGlass() bilan o'ralgan, glow soyasi aqua.
// Top bar: ParvozHeader orqaga + sleep timer glass chip + menu.
// Slider: aqua aktiv iz, oq thumb.
// Play tugmasi: aqua (#22D3EE) doira, ustida to'q navy icon.
// Tezlik/seek: parvozText/parvozTextDim.
// BottomSheet'lar: parvozSurface fon, parvozBorder ajratuvchi.
//
// LOGIKA SAQLANADI: ref.watch(audioPlayerProvider), ref.listen(error),
// hasAudio guard, seek/play/pause/resume/setSpeed/sleepTimer — barchasi
// o'zgarishsiz.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audio_player_state.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audio_player_provider.dart';
import 'package:farzandim_child/shared/widgets/parvoz_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioPlayerScreen extends ConsumerWidget {
  const AudioPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerProvider);

    // Audio yuklab/ijro etib bo'lmasa — snackbar xabar.
    ref.listen<String?>(
      audioPlayerProvider.select((s) => s.error),
      (prev, err) {
        if (err != null && err.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      },
    );

    if (!state.hasAudio) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final book = state.currentBook!;

    return Scaffold(
      backgroundColor: AppColors.parvozBg,
      body: Column(
        children: [
          // ── Top bar: orqaga + sleep timer + menu ──
          _PlayerTopBar(book: book, state: state),
          // ── Qolgan kontent ──
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // ── Cover ──
                    _Cover(book: book),
                    const SizedBox(height: 24),
                    // ── Muallif ──
                    Text(
                      book.author,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                        color: AppColors.parvozTextDim,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // ── Sarlavha ──
                    Text(
                      book.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.parvozText,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // ── Slider + vaqt ──
                    _SliderRow(state: state),
                    const SizedBox(height: 20),
                    // ── Boshqaruv tugmalari ──
                    _Controls(state: state, book: book),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top bar ─────────────────────────────────────────────────────────

class _PlayerTopBar extends ConsumerWidget {
  const _PlayerTopBar({required this.book, required this.state});

  final AudiobookModel book;
  final AudioPlayerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.parvozBorder)),
        ),
        child: Row(
          children: [
            // Orqaga tugma
            GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.parvozText,
                  size: 28,
                ),
              ),
            ),
            // ── Sleep timer chip (markazda) ──
            Expanded(
              child: Center(
                child: state.hasSleepTimer
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.parvozSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.parvozBorderStrong),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(AppIcons.hourglass,
                                color: AppColors.parvozGreen, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              _formatDuration(state.sleepTimerRemaining),
                              style: const TextStyle(
                                color: AppColors.parvozText,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            // Menu tugmasi
            GestureDetector(
              onTap: () => _openMenu(context, book),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.parvozSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.parvozText,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
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

// ─── Cover (glass card) ──────────────────────────────────────────────

class _Cover extends StatelessWidget {
  const _Cover({required this.book});

  final AudiobookModel book;

  @override
  Widget build(BuildContext context) {
    // 3:4 kitob muqovasi proporsiyasi, glass frame
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260, maxHeight: 352),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: parvozGlass(radius: 20).copyWith(
            image: book.coverUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(book.coverUrl),
                    fit: BoxFit.cover,
                  )
                : null,
            color: book.coverUrl.isEmpty ? book.coverColor : null,
            // parvozGreen glow soyasi — cover pastida
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: AppColors.parvozGreen.withOpacity(0.18),
                blurRadius: 40,
                spreadRadius: 4,
                offset: const Offset(0, 18),
              ),
              const BoxShadow(
                color: Color(0x80000000),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: book.coverUrl.isEmpty
              ? Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.parvozSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      AppIcons.speaker,
                      color: AppColors.parvozTextDim,
                      size: 44,
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
            activeTrackColor: AppColors.parvozGreen,
            // ignore: deprecated_member_use
            inactiveTrackColor: AppColors.parvozBorderStrong,
            thumbColor: AppColors.parvozText,
            // ignore: deprecated_member_use
            overlayColor: AppColors.parvozGreen.withOpacity(0.15),
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.parvozTextDim,
                ),
              ),
              Text(
                _formatDuration(state.duration),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.parvozTextDim,
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
          child: Container(
            width: 52,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.parvozSurface,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.parvozBorderStrong),
            ),
            child: Text(
              '${_formatSpeed(speed)}x',
              style: const TextStyle(
                color: AppColors.parvozText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        // 10s ortga
        _SeekButton(
          icon: Icons.replay_10_rounded,
          onTap: () =>
              ref.read(audioPlayerProvider.notifier).seekBackward(),
        ),
        // Play/Pause — aqua doira, to'q navy icon
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
              color: AppColors.parvozGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: AppColors.parvozGreen.withOpacity(0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              state.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: AppColors.parvozOnGreen,
              size: 44,
            ),
          ),
        ),
        // 10s oldinga
        _SeekButton(
          icon: Icons.forward_10_rounded,
          onTap: () =>
              ref.read(audioPlayerProvider.notifier).seekForward(),
        ),
        // O'ng bo'sh joy — simmetriya (tezlik chip bilan)
        const SizedBox(width: 52, height: 40),
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
        width: 52,
        height: 52,
        child: Icon(
          icon,
          color: AppColors.parvozText,
          size: 36,
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
              style: const TextStyle(color: AppColors.parvozText),
            ),
            trailing: speed == currentSpeed
                ? const Icon(AppIcons.check, color: AppColors.parvozGreen)
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
          leading: const Icon(Icons.speed, color: AppColors.parvozGreen),
          title: const Text('Tezlik',
              style: TextStyle(color: AppColors.parvozText)),
          subtitle: Text(
            '${speed}x',
            style: const TextStyle(
                color: AppColors.parvozTextDim, fontSize: 12),
          ),
          trailing: const Icon(AppIcons.chevronRight,
              color: AppColors.parvozTextDim),
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
          leading:
              const Icon(AppIcons.hourglass, color: AppColors.parvozGreen),
          title: const Text(
            'Uyqu taymeri',
            style: TextStyle(color: AppColors.parvozText),
          ),
          subtitle: Text(
            hasSleepTimer ? 'Faol' : "O'chirilgan",
            style: const TextStyle(
                color: AppColors.parvozTextDim, fontSize: 12),
          ),
          trailing: const Icon(AppIcons.chevronRight,
              color: AppColors.parvozTextDim),
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
              color: AppColors.parvozGreen),
          title: const Text(
            'Tafsilotlar',
            style: TextStyle(color: AppColors.parvozText),
          ),
          trailing: const Icon(AppIcons.chevronRight,
              color: AppColors.parvozTextDim),
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
            style: TextStyle(color: AppColors.parvozText),
          ),
          trailing: !hasTimer
              ? const Icon(AppIcons.check, color: AppColors.parvozGreen)
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
              style: const TextStyle(color: AppColors.parvozText),
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
        color: AppColors.parvozSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: AppColors.parvozBorderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Tafsilotlar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.parvozText,
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
                  color: AppColors.parvozTextDim,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                book.description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.parvozText,
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
                          color: AppColors.parvozGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            // ignore: deprecated_member_use
                            color: AppColors.parvozGreen.withOpacity(0.25),
                          ),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: AppColors.parvozGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
                color: AppColors.parvozTextDim,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.parvozText,
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
        color: AppColors.parvozSurface,
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
                color: AppColors.parvozBorderStrong,
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
                    color: AppColors.parvozText,
                  ),
                ),
              )
            else
              const SizedBox(height: 16),
            if (title != null)
              const Divider(
                  color: AppColors.parvozBorder, height: 1),
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
