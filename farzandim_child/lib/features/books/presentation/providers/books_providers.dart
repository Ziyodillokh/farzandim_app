import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/books/data/models/book_model.dart';
import 'package:farzandim_child/features/books/data/repositories/books_backend_repository.dart';
import 'package:farzandim_child/features/onboarding/presentation/providers/interests_provider.dart';

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

/// Bola qiziqishlariga mos kitoblar — overlap-based filter.
///
/// `BookModel.category` (school|adabiyot|fan|tarjima) `Child.interests`'dan
/// kelgan `contentTags` set'i bilan kesishsa kitob tavsiya etiladi.
/// Eng ko'p kesishganlar tepada (oddiy overlap count sort).
///
/// Qiziqishlar bo'sh bo'lsa eng mashhur kitoblar (`reads desc`) qaytariladi —
/// shu sababli "Tavsiya" bo'limi har doim biror narsa ko'rsatadi.
final recommendedBooksProvider = Provider<List<BookModel>>((ref) {
  final all = ref.watch(effectiveBooksProvider);
  if (all.isEmpty) return const [];
  final tags = ref.watch(interestContentTagsProvider);
  if (tags.isEmpty) {
    // Qiziqish yo'q — top-N mashhur kitoblar (reads desc).
    final sorted = [...all]..sort((a, b) => b.reads.compareTo(a.reads));
    return sorted.take(10).toList();
  }
  // Har kitobga "overlap skor" hisoblaymiz: category tag'da bormi.
  final scored = <(BookModel, int)>[];
  for (final b in all) {
    final cat = b.category.toLowerCase();
    final score = tags.contains(cat) ? 1 : 0;
    if (score > 0) scored.add((b, score));
  }
  // Skor tugagach mashhurlik (reads) — bir xil skor uchun.
  scored.sort((a, b) {
    final s = b.$2.compareTo(a.$2);
    if (s != 0) return s;
    return b.$1.reads.compareTo(a.$1.reads);
  });
  final list = scored.map((s) => s.$1).take(10).toList();
  if (list.isEmpty) {
    // Overlap topilmadi — popular fallback.
    final sorted = [...all]..sort((a, b) => b.reads.compareTo(a.reads));
    return sorted.take(10).toList();
  }
  return list;
});
