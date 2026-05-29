// ─────────────────────────────────────────────────────────────────────
// AudiobookSection — sarlavha + horizontal card list
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/presentation/widgets/audiobook_card.dart';
import 'package:flutter/material.dart';

class AudiobookSection extends StatelessWidget {
  const AudiobookSection({
    required this.title,
    required this.books,
    super.key,
  });

  final String title;
  final List<AudiobookModel> books;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text(
                'Barchasi',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          // 3:4 cover (~185) + meta (title 2 lines + author) ≈ 245
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => AudiobookCard(book: books[i]),
          ),
        ),
      ],
    );
  }
}
