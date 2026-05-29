import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/books/data/models/book_model.dart';
import 'package:farzandim_child/features/books/presentation/providers/books_providers.dart';
import 'package:farzandim_child/features/books/presentation/widgets/book_section.dart';

class BooksFeedScreen extends ConsumerWidget {
  const BooksFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBooks = ref.watch(backendBooksProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundBottom,
      body: SafeArea(
        child: asyncBooks.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(error: e.toString(), onRetry: () => ref.invalidate(backendBooksProvider)),
          data: (books) {
            if (books.isEmpty) return const _EmptyView();
            // Kategoriya bo'yicha grouplash — oddiy: 3 ta section
            final school = books.where((b) => b.category == 'school').toList();
            final adabiyot = books.where((b) => b.category == 'adabiyot').toList();
            final other = books
                .where((b) => b.category != 'school' && b.category != 'adabiyot')
                .toList();
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(backendBooksProvider);
                await ref.read(backendBooksProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'Kitoblar',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  BookSection(
                    title: 'Hammasi',
                    books: books,
                    onTap: (b) => _openPdf(context, b),
                  ),
                  const SizedBox(height: 20),
                  BookSection(
                    title: 'Maktab darsliklari',
                    books: school,
                    onTap: (b) => _openPdf(context, b),
                  ),
                  if (adabiyot.isNotEmpty) const SizedBox(height: 20),
                  BookSection(
                    title: 'Adabiyot',
                    books: adabiyot,
                    onTap: (b) => _openPdf(context, b),
                  ),
                  if (other.isNotEmpty) const SizedBox(height: 20),
                  BookSection(
                    title: 'Boshqalar',
                    books: other,
                    onTap: (b) => _openPdf(context, b),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openPdf(BuildContext context, BookModel book) {
    context.push('/books/pdf', extra: book);
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.menu,
                size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              'Hozircha kitoblar mavjud emas.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.error,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Yuklab bo\'lmadi.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Qayta urinish')),
          ],
        ),
      ),
    );
  }
}
