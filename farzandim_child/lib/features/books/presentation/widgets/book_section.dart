import 'package:flutter/material.dart';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/books/data/models/book_model.dart';
import 'package:farzandim_child/features/books/presentation/widgets/book_card.dart';

class BookSection extends StatelessWidget {
  const BookSection({
    super.key,
    required this.title,
    required this.books,
    required this.onTap,
  });

  final String title;
  final List<BookModel> books;
  final ValueChanged<BookModel> onTap;

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
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Barchasi',
                style: TextStyle(color: AppColors.primary, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          // 3:4 cover (~185) + meta ≈ 245
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => BookCard(
              book: books[i],
              onTap: () => onTap(books[i]),
            ),
          ),
        ),
      ],
    );
  }
}
