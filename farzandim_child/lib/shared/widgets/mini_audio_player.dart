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
          color: AppColors.surface,
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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: book.coverColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(AppIcons.speaker,
                        color: Colors.white, size: 20),
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
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay_10,
                        color: AppColors.textPrimary),
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
                    icon: const Icon(Icons.forward_10,
                        color: AppColors.textPrimary),
                    onPressed: () => ref
                        .read(audioPlayerProvider.notifier)
                        .seekForward(),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close,
                        color: AppColors.textSecondary, size: 20),
                    onPressed: () =>
                        ref.read(audioPlayerProvider.notifier).stop(),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary),
              minHeight: 2,
            ),
          ],
        ),
      ),
    );
  }
}
