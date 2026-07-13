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
    this.leadingIcon,
    this.leadingIconColor,
    super.key,
  });

  final String title;
  final List<AudiobookModel> books;

  /// Sarlavha oldida rangli yumaloq fonda ko'rinadigan Material ikon.
  /// `null` bo'lsa eski rejim (faqat matn).
  final IconData? leadingIcon;
  final Color? leadingIconColor;

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
              Row(
                children: [
                  if (leadingIcon != null) ...[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: (leadingIconColor ?? AppColors.primary)
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        leadingIcon,
                        size: 16,
                        color: leadingIconColor ?? AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.adaptive.textPrimary,
                    ),
                  ),
                ],
              ),
              const Text(
                'Barchasi',
                style: TextStyle(color: AppColors.primary, fontSize: 14),
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
