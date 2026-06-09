// ─────────────────────────────────────────────────────────────────────
// MiniAudioPlayer — Spotify uslubidagi global mini-player (PDF p12)
// ─────────────────────────────────────────────────────────────────────
//
// Audio o'ynalmayotgan bo'lsa SizedBox.shrink — joy band qilmaydi.
// Audio bor bo'lsa: cover, title, author, controls (back15/play/forward15),
// close va progress bar. Tap → /audio-player (full screen, 9.E'da).

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audio_player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MiniAudioPlayer extends ConsumerWidget {
  const MiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerProvider);
    if (!state.hasAudio) return const SizedBox.shrink();

    final book = state.currentBook!;
    final progress = state.duration.inSeconds > 0
        ? state.position.inSeconds / state.duration.inSeconds
        : 0.0;

    return GestureDetector(
      onTap: () => context.push('/audio-player'),
      child: Container(
        margin:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.adaptive.bgCard,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  // Cover rasm — coverUrl bo'lsa, rasm; bo'lmasa rangli
                  // fon + speaker ikona fallback.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: book.coverUrl.isNotEmpty
                          ? Image.network(
                              book.coverUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return Container(color: book.coverColor);
                              },
                              errorBuilder: (_, __, ___) =>
                                  _miniFallback(book.coverColor),
                            )
                          : _miniFallback(book.coverColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.adaptive.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.adaptive.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.replay_10,
                        color: context.adaptive.textPrimary),
                    onPressed: () => ref
                        .read(audioPlayerProvider.notifier)
                        .seekBackward(),
                  ),
                  IconButton(
                    icon: Icon(
                      state.isPlaying
                          ? AppIcons.pause
                          : AppIcons.play,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    onPressed: () {
                      final notifier =
                          ref.read(audioPlayerProvider.notifier);
                      if (state.isPlaying) {
                        notifier.pause();
                      } else {
                        notifier.resume();
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.forward_10,
                        color: context.adaptive.textPrimary),
                    onPressed: () => ref
                        .read(audioPlayerProvider.notifier)
                        .seekForward(),
                  ),
                  IconButton(
                    icon: Icon(AppIcons.close,
                        color: context.adaptive.textSecondary, size: 20),
                    onPressed: () =>
                        ref.read(audioPlayerProvider.notifier).stop(),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: context.adaptive.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary),
              minHeight: 2,
            ),
          ],
        ),
      ),
    );
  }

  /// Rasm yo'q yoki yuklanmagan holatda — rangli fon + speaker ikona.
  Widget _miniFallback(Color color) {
    return Container(
      color: color,
      child: const Icon(
        AppIcons.speaker,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}
