// ─────────────────────────────────────────────────────────────────────
// ArticlesFeedScreen — maqolalar feed (#48) (Parvoz NIGHT/GLASS redizayn)
// ─────────────────────────────────────────────────────────────────────
//
// Faqat ko'rinish night/glass'ga o'tkazildi (parvoz tokenlar + ParvozHeader).
// LOGIKA SAQLANGAN — provider'lar, navigatsiya, refresh, ArticleCard tap.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/articles/data/models/article_model.dart';
import 'package:farzandim_child/features/articles/presentation/providers/articles_providers.dart';
import 'package:farzandim_child/features/articles/presentation/widgets/article_card.dart';
import 'package:farzandim_child/shared/widgets/parvoz_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ArticlesFeedScreen extends ConsumerWidget {
  const ArticlesFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(backendArticlesProvider);

    return Scaffold(
      backgroundColor: AppColors.parvozBg,
      body: Column(
        children: [
          ParvozHeader(
            title: 'articles.title'.tr(),
            onBack: () => context.pop(),
          ),
          Expanded(
            child: async.when(
              data: (articles) => _List(articles: articles, ref: ref),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.parvozGreen),
              ),
              error: (_, __) => _Empty(
                icon: Icons.wifi_off_rounded,
                text: 'articles.loadFailed'.tr(),
                onRetry: () => ref.invalidate(backendArticlesProvider),
              ),
            ),
          ),
        ],
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
      return _Empty(
        icon: Icons.menu_book_rounded,
        text: 'articles.empty'.tr(),
      );
    }
    return RefreshIndicator(
      color: AppColors.parvozGreen,
      backgroundColor: AppColors.parvozSurface,
      onRefresh: () async {
        ref.invalidate(backendArticlesProvider);
        await ref.read(backendArticlesProvider.future);
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        itemCount: articles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
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
          Container(
            width: 96,
            height: 96,
            decoration: parvozGlass(radius: 28),
            child: Icon(icon, size: 44, color: AppColors.parvozTextDim),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.parvozTextDim,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.parvozGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'common.retry'.tr(),
                  style: TextStyle(
                    color: AppColors.parvozOnGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
