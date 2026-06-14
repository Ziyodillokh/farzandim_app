// ─────────────────────────────────────────────────────────────────────
// DevelopmentRepository (Parent) — bola rivojlanish ko'rsatkichi (#63)
// ─────────────────────────────────────────────────────────────────────

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/features/development/data/development_summary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final developmentRepositoryProvider = Provider<DevelopmentRepository>((ref) {
  return DevelopmentRepository(dio: ref.watch(dioClientProvider));
});

/// Bola rivojlanish ko'rsatkichi (haftalik), childId bo'yicha (family).
final developmentSummaryProvider =
    FutureProvider.family<DevelopmentSummary, String>((ref, childId) {
  return ref.read(developmentRepositoryProvider).fetch(childId);
});

class DevelopmentRepository {
  DevelopmentRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<DevelopmentSummary> fetch(
    String childId, {
    String range = 'weekly',
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/development-summary',
        queryParameters: {'range': range},
      );
      final data = res.data;
      if (data == null) return DevelopmentSummary.empty;
      return DevelopmentSummary.fromJson(data);
    } on DioException catch (e) {
      debugPrint('DevelopmentRepository.fetch: ${e.response?.statusCode}');
      return DevelopmentSummary.empty;
    }
  }
}
