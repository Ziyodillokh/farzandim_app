// ─────────────────────────────────────────────────────────────────────
// articles_providers — maqolalar Riverpod (#48)
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/articles/data/models/article_model.dart';
import 'package:farzandim_child/features/articles/data/repositories/articles_backend_repository.dart';

/// Backend'dan maqolalar (yoshga mos + approved). JWT orqali bola aniqlanadi.
final backendArticlesProvider = FutureProvider<List<ArticleModel>>((ref) async {
  final repo = ref.watch(articlesBackendRepositoryProvider);
  return repo.fetchArticles();
});

/// Sinxron yordamchi — xato/yuklanishda bo'sh ro'yxat.
final effectiveArticlesProvider = Provider<List<ArticleModel>>((ref) {
  return ref.watch(backendArticlesProvider).valueOrNull ?? const [];
});
