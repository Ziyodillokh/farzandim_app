// U14 · Maqolani o'qish: kategoriya, yosh va o'qish vaqti yorlig'i, matn
// o'lchami (A− / A+, eslab qolinadi) va xatcho'p. Katta o'lchamda ham sahifa
// aylanadi. Ochilganda server «o'qildi» deb belgilaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/articles/data/models/article_model.dart';
import 'package:farzandim_child/features/articles/data/repositories/articles_backend_repository.dart';
import 'package:farzandim_child/features/articles/presentation/providers/articles_providers.dart';
import 'package:farzandim_child/growth/oqish/library/library_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ArticleScreen extends ConsumerStatefulWidget {
  const ArticleScreen({super.key, required this.articleId});

  final String articleId;

  @override
  ConsumerState<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends ConsumerState<ArticleScreen> {
  var _reported = false;

  void _reportRead() {
    if (_reported) return;
    _reported = true;
    Future.microtask(
      () => ref
          .read(articlesBackendRepositoryProvider)
          .markRead(widget.articleId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final articles = ref.watch(effectiveArticlesProvider);
    final article = articles.where((a) => a.id == widget.articleId).firstOrNull;
    final saved =
        ref
            .watch(articleBookmarksProvider)
            .valueOrNull
            ?.contains(widget.articleId) ??
        false;
    final scale = ref.watch(articleTextScaleProvider).valueOrNull ?? 1;
    final back = GTopBar.back(
      label: 'g5.common.back'.tr(),
      onPressed: () => context.pop(),
    );
    if (article == null) {
      return Scaffold(
        backgroundColor: GColors.bg,
        body: GScreen(
          top: GTopBar(leading: back, title: 'g5.library.articles'.tr()),
          children: [
            if (articles.isEmpty)
              Text(
                'g5.common.loading'.tr(),
                textAlign: TextAlign.center,
                style: GText.caption,
              )
            else
              GNote(
                text: 'g5.library.article.notFound'.tr(),
                kind: GNoteKind.warn,
              ),
          ],
        ),
      );
    }
    _reportRead();
    final meta = [
      article.category,
      if (article.ageFrom > 0 && article.ageTo > 0)
        'g5.library.article.ages'.tr(
          namedArgs: {'from': '${article.ageFrom}', 'to': '${article.ageTo}'},
        ),
      'g5.library.readMinutes'.tr(
        namedArgs: {'count': '${articleReadingMinutes(article)}'},
      ),
    ].where((s) => s.trim().isNotEmpty).join(' · ');
    final notifier = ref.read(articleTextScaleProvider.notifier);
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: back,
          title: 'g5.library.articles'.tr(),
          actions: [
            GIconButton(
              icon: GIcons.bookmarkSimple,
              label:
                  (saved
                          ? 'g5.library.article.saved'
                          : 'g5.library.article.save')
                      .tr(),
              onPressed: () => ref
                  .read(articleBookmarksProvider.notifier)
                  .toggle(article.id),
              badge: saved,
              badgeColor: GColors.success,
            ),
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GChip(label: meta, kind: GChipKind.neutral),
          ),
          Semantics(
            header: true,
            child: Text(
              article.title,
              style: GText.h1.copyWith(fontSize: 24 * scale),
            ),
          ),
          Row(
            children: [
              Text(
                'g5.library.article.textSize'.tr(),
                style: GText.onest(
                  13,
                  weight: FontWeight.w600,
                  color: GColors.textMuted,
                ),
              ),
              const Spacer(),
              GIconButton(
                icon: GIcons.minus,
                label: 'g5.library.article.smaller'.tr(),
                onPressed: scale <= kArticleScaleMin
                    ? null
                    : () => notifier.change(-kArticleScaleStep),
              ),
              const SizedBox(width: 8),
              GIconButton(
                icon: GIcons.plus,
                label: 'g5.library.article.bigger'.tr(),
                onPressed: scale >= kArticleScaleMax
                    ? null
                    : () => notifier.change(kArticleScaleStep),
              ),
            ],
          ),
          _Body(article: article, scale: scale),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.article, required this.scale});

  final ArticleModel article;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final base = GText.onest(16 * scale, color: GColors.textBody, height: 1.6);
    return MarkdownBody(
      data: article.body,
      selectable: false,
      styleSheet: MarkdownStyleSheet(
        p: base,
        h1: GText.onest(22 * scale, weight: FontWeight.w700, height: 1.3),
        h2: GText.onest(19 * scale, weight: FontWeight.w700, height: 1.3),
        h3: GText.onest(17 * scale, weight: FontWeight.w700, height: 1.3),
        strong: base.copyWith(fontWeight: FontWeight.w700, color: GColors.text),
        listBullet: base,
        blockSpacing: 14,
        a: base.copyWith(color: GColors.link),
      ),
    );
  }
}
