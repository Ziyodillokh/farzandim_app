// ─────────────────────────────────────────────────────────────────────
// AudiobookCard — feed sectionidagi 140x230 card (3:4 cover + meta)
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audio_player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudiobookCard extends ConsumerWidget {
  const AudiobookCard({required this.book, super.key});

  final AudiobookModel book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () =>
          ref.read(audioPlayerProvider.notifier).play(book),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3:4 vertikal kitob muqovasi (140 × 185)
            AspectRatio(
              aspectRatio: 3 / 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Rasm yoki fallback color
                      if (book.coverUrl.isNotEmpty)
                        Image.network(
                          book.coverUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(color: book.coverColor);
                          },
                          errorBuilder: (_, __, ___) => _fallbackCover(),
                        )
                      else
                        _fallbackCover(),
                      // Pastdagi dark gradient — duration pill ko'rinishi uchun
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x66000000),
                            ],
                            stops: [0.6, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            // ignore: deprecated_member_use
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            book.duration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Adaptive — dark mode'da AppColors.textPrimary qora bo'lardi.
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.adaptive.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
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
    );
  }

  /// Cover rasm yo'q yoki yuklanmagan holatda — rangli fon + speaker ikona.
  Widget _fallbackCover() {
    return Container(
      color: book.coverColor,
      child: Center(
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            AppIcons.speaker,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}
