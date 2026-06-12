// Faol sessiyalar REST API — ro'yxat olish va sessiyalarni tugatish.

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/features/settings/data/models/user_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendSessionRepositoryProvider =
    Provider<BackendSessionRepository>((ref) {
  return BackendSessionRepository(dio: ref.watch(dioClientProvider));
});

class BackendSessionRepository {
  BackendSessionRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Faol sessiyalar — joriy sessiya `isCurrent: true` bilan belgilangan.
  Future<List<UserSession>> getSessions() async {
    final response = await _dio.get<List<dynamic>>('/auth/sessions');
    final list = response.data ?? const <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(UserSession.fromJson)
        .toList(growable: false);
  }

  /// Bitta sessiyani uzoqdan tugatish (boshqa qurilma).
  Future<void> revokeSession(String sessionId) async {
    await _dio.delete<void>('/auth/sessions/$sessionId');
  }

  /// Joriydan boshqa barcha sessiyalarni tugatish.
  Future<void> revokeOthers() async {
    await _dio.delete<void>('/auth/sessions/others');
  }
}
