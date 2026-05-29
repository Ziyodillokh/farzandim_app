// ─────────────────────────────────────────────────────────────────────
// BooksBackendRepository
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakti (Sprint 5.7a):
//   GET /api/content/books?page=&limit=
//     → { items: [{ id, title, author, description, pdfUrl, coverUrl,
//                   pages, ageFrom, ageTo, category, planRequired,
//                   reads, createdAt }],
//         pagination: { page, totalPages, total, limit } }
//   POST /api/content/books/:id/read  → reads++

// ignore_for_file: public_member_api_docs

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/books/data/models/book_model.dart';

final booksBackendRepositoryProvider = Provider<BooksBackendRepository>((ref) {
  return BooksBackendRepository(dio: ref.watch(dioClientProvider));
});

class BooksBackendRepository {
  BooksBackendRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<List<BookModel>> fetchBooks({int page = 1, int limit = 50}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/content/books',
        queryParameters: {'page': page, 'limit': limit},
      );
      final items = (response.data?['items'] as List<dynamic>?) ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(_toBookModel)
          .toList(growable: false);
    } on DioException catch (e) {
      debugPrint('BooksBackend.fetchBooks: ${e.response?.statusCode} ${e.message}');
      rethrow;
    }
  }

  Future<void> markRead(String bookId) async {
    try {
      await _dio.post<Map<String, dynamic>>('/content/books/$bookId/read');
    } on DioException catch (e) {
      debugPrint('BooksBackend.markRead: ${e.message}');
    }
  }

  BookModel _toBookModel(Map<String, dynamic> raw) {
    final id = raw['id']?.toString() ?? '';
    final ageFrom = (raw['ageFrom'] as num?)?.toInt() ?? 0;
    final ageTo = (raw['ageTo'] as num?)?.toInt() ?? 18;
    return BookModel(
      id: id,
      title: (raw['title'] as String?) ?? '—',
      author: (raw['author'] as String?) ?? 'Noma\'lum',
      description: (raw['description'] as String?) ?? '',
      pdfUrl: (raw['pdfUrl'] as String?) ?? '',
      coverUrl: (raw['coverUrl'] as String?) ?? '',
      coverColor: _coverColorFor(id),
      pages: (raw['pages'] as num?)?.toInt() ?? 0,
      category: (raw['category'] as String?) ?? 'school',
      yoshGuruhi: '$ageFrom-$ageTo',
      reads: (raw['reads'] as num?)?.toInt() ?? 0,
    );
  }

  Color _coverColorFor(String id) {
    if (id.isEmpty) return AppColors.catLavenderDark;
    int hash = 0;
    for (final code in id.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    const palette = <Color>[
      AppColors.catLavenderDark,
      AppColors.catPinkRose,
      AppColors.warning,
      AppColors.catMint,
      AppColors.catLavender,
      AppColors.catGreen,
      AppColors.catPinkVibrant,
    ];
    return palette[hash % palette.length];
  }
}
