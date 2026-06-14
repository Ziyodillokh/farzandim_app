// ─────────────────────────────────────────────────────────────────────
// ArticlesFeedScreen — maqolalar feed (#48)
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/articles/data/models/article_model.dart';
import 'package:farzandim_child/features/articles/presentation/providers/articles_providers.dart';
import 'package:farzandim_child/features/articles/presentation/widgets/article_card.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ArticlesFeedScreen extends ConsumerWidget {
  const ArticlesFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(backendArticlesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(onBack: () => context.pop()),
              Expanded(
                child: async.when(
                  data: (articles) => _List(articles: articles, ref: ref),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => _Empty(
                    icon: Icons.wifi_off_rounded,
                    text: 'Maqolalarni yuklab bo\'lmadi.',
                    onRetry: () => ref.invalidate(backendArticlesProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.articles, required this.ref});
  final List<ArticleModel> articles;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) {
      return const _Empty(
        icon: Icons.menu_book_rounded,
        text: 'Hozircha maqola yo\'q. Tez orada qo\'shiladi!',
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(backendArticlesProvider);
        await ref.read(backendArticlesProvider.future);
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: articles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final a = articles[i];
          return ArticleCard(
            article: a,
            onTap: () => context.push('/articles/view', extra: a),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: onBack,
          ),
          const Expanded(
            child: Text(
              'Maqolalar',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text, this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Qayta urinish')),
          ],
        ],
      ),
    );
  }
}
