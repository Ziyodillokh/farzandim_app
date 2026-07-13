// ─────────────────────────────────────────────────────────────────────
// ArticleViewScreen — maqolani o'qish (markdown render) (#48)
// Parvoz NIGHT/GLASS redizayn — faqat ko'rinish (logika saqlangan).
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/articles/data/models/article_model.dart';
import 'package:farzandim_child/features/articles/data/repositories/articles_backend_repository.dart';
import 'package:farzandim_child/shared/widgets/parvoz_glass.dart';
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
  late int _likes = widget.article.likes;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    // O'qildi — views++ (fire-and-forget).
    ref
        .read(articlesBackendRepositoryProvider)
        .markRead(widget.article.id);
  }

  Future<void> _onLike() async {
    if (_liked) return;
    setState(() {
      _liked = true;
      _likes += 1; // optimistik
    });
    final newLikes =
        await ref.read(articlesBackendRepositoryProvider).like(widget.article.id);
    if (newLikes != null && mounted) {
      setState(() => _likes = newLikes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.article;
    return Scaffold(
      backgroundColor: AppColors.parvozBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: a.hasCover ? 240 : 0,
            backgroundColor: AppColors.parvozBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => context.pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.parvozBg.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.parvozBorderStrong),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.parvozText,
                  ),
                ),
              ),
            ),
            flexibleSpace: a.hasCover
                ? FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          a.coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              ColoredBox(color: a.coverColor),
                        ),
                        // Pastga qarab navy gradient — matn bilan ulanish.
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppColors.parvozBg.withValues(alpha: 0.55),
                                AppColors.parvozBg,
                              ],
                              stops: const [0.45, 0.85, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    style: const TextStyle(
                      color: AppColors.parvozText,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.22,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (a.category.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                AppColors.parvozGreen.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color:
                                  AppColors.parvozGreen.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            a.category,
                            style: const TextStyle(
                              color: AppColors.parvozGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Icon(
                        Icons.child_care_rounded,
                        size: 15,
                        color: AppColors.parvozTextDim,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${a.yoshGuruhi} yosh',
                        style: const TextStyle(
                          color: AppColors.parvozTextDim,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Ko'rishlar + yoqtirish (like tugmasi).
                  Row(
                    children: [
                      const Icon(
                        Icons.remove_red_eye_outlined,
                        size: 16,
                        color: AppColors.parvozTextDim,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${a.views}',
                        style: const TextStyle(
                          color: AppColors.parvozTextDim,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 18),
                      GestureDetector(
                        onTap: _onLike,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            Icon(
                              _liked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                              color: _liked
                                  ? AppColors.catPinkVibrant
                                  : AppColors.parvozTextDim,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$_likes',
                              style: TextStyle(
                                color: _liked
                                    ? AppColors.catPinkVibrant
                                    : AppColors.parvozTextDim,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 1,
                    color: AppColors.parvozBorderStrong,
                  ),
                  const SizedBox(height: 18),
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
      color: AppColors.parvozText,
      fontSize: 16,
      height: 1.65,
    );
    return MarkdownStyleSheet(
      p: text,
      h1: const TextStyle(
        color: AppColors.parvozText,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      h2: const TextStyle(
        color: AppColors.parvozText,
        fontSize: 19,
        fontWeight: FontWeight.bold,
      ),
      h3: const TextStyle(
        color: AppColors.parvozText,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      listBullet: text,
      strong: const TextStyle(
        color: AppColors.parvozText,
        fontWeight: FontWeight.bold,
      ),
      blockquotePadding: const EdgeInsets.all(14),
      blockquoteDecoration: parvozGlassFlat(radius: 12),
      a: const TextStyle(color: AppColors.parvozGreen),
    );
  }
}
