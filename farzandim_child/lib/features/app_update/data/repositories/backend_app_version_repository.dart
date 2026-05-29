// ─────────────────────────────────────────────────────────────────────
// BackendAppVersionRepository — GET /api/app/version (Sprint 4.4.28)
// ─────────────────────────────────────────────────────────────────────
//
// Auth talab qilinmaydi — app startup'da (Welcome ekrandan oldin)
// chaqirilishi mumkin. Lekin Dio bizning interceptor'lar bilan keladi:
// authInterceptor token bo'lsa qo'shadi, bo'lmasa skip qiladi
// (`/auth/*` pattern emas).

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/app_update/data/models/app_version_info.dart';

const String _appName = 'child';

final backendAppVersionRepositoryProvider =
    Provider<BackendAppVersionRepository>((ref) {
  return BackendAppVersionRepository(dio: ref.watch(dioClientProvider));
});

class BackendAppVersionRepository {
  BackendAppVersionRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// Backend'dan child app uchun version ma'lumotini olish.
  /// Tarmoq xatosida `null` qaytaradi (app startup'da silent skip).
  Future<AppVersionInfo?> fetch() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/app/version',
        queryParameters: {'app': _appName},
        // Auth interceptor token qo'shsa ham, Backend authsiz qabul qiladi.
      );
      final data = response.data;
      if (data == null) return null;
      return AppVersionInfo.fromJson(data);
    } on DioException catch (e) {
      debugPrint(
        'BackendAppVersionRepository.fetch xato '
        '${e.response?.statusCode}: ${e.message}',
      );
      return null;
    }
  }
}
