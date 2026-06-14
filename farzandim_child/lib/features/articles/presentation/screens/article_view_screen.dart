// ─────────────────────────────────────────────────────────────────────
// ArticleViewScreen — maqolani o'qish (markdown render) (#48)
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/articles/data/models/article_model.dart';
import 'package:farzandim_child/features/articles/data/repositories/articles_backend_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ArticleViewScreen extends ConsumerStatefulWidget {
  const ArticleViewScreen({required this.article, super.key});

  final ArticleModel article;

  @override
  ConsumerState<ArticleViewScreen> createState() => _ArticleViewScreenState();
}

class _ArticleViewScreenState extends ConsumerState<ArticleViewScreen> {
  @override
  void initState() {
    super.initState();
    // O'qildi — views++ (fire-and-forget).
    ref
        .read(articlesBackendRepositoryProvider)
        .markRead(widget.article.id);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.article;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: a.hasCover ? 220 : 0,
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: a.hasCover
                ? FlexibleSpaceBar(
                    background: Image.network(
                      a.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: a.coverColor),
                    ),
                  )
                : null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (a.category.isNotEmpty) ...[
                        Text(
                          a.category,
                          style: TextStyle(
                            color: a.coverColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        '${a.yoshGuruhi} yosh',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28, color: AppColors.border),
                  MarkdownBody(
                    data: a.body,
                    selectable: true,
                    styleSheet: _markdownStyle(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle() {
    const text = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 16,
      height: 1.6,
    );
    return MarkdownStyleSheet(
      p: text,
      h1: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      h2: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 19,
        fontWeight: FontWeight.bold,
      ),
      h3: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      listBullet: text,
      strong: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
      ),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      a: const TextStyle(color: AppColors.primary),
    );
  }
}
