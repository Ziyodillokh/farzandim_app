import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/books/data/models/book_model.dart';
import 'package:farzandim_child/features/books/data/repositories/books_backend_repository.dart';

/// Backend'dan kitoblar ro'yxati. Bola pair qilinmagan/401 bo'lsa
/// exception qaytaradi → effective fallback bo'sh ro'yxat.
///
/// 5-daqiqalik cache TTL (oxirgi watch'dan 5 min keyin re-fetch).
final backendBooksProvider = FutureProvider<List<BookModel>>((ref) async {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(booksBackendRepositoryProvider);
  return repo.fetchBooks();
});

extension _RefCache on Ref {
  void cacheFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}

/// Sync provider — UI uchun: backend yuklandimi/xato bo'ldimi, hech bo'lmasa
/// bo'sh ro'yxat qaytaradi (mock fallback yo'q hozircha).
final effectiveBooksProvider = Provider<List<BookModel>>((ref) {
  final async = ref.watch(backendBooksProvider);
  return async.maybeWhen(data: (list) => list, orElse: () => const <BookModel>[]);
});
