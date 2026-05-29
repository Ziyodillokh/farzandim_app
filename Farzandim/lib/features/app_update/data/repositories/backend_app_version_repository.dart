// ─────────────────────────────────────────────────────────────────────
// BackendAppVersionRepository — Parent App GET /api/app/version
// (Sprint 4.4.28)
// ─────────────────────────────────────────────────────────────────────

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/features/app_update/data/models/app_version_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _appName = 'parent';

final backendAppVersionRepositoryProvider =
    Provider<BackendAppVersionRepository>((ref) {
  return BackendAppVersionRepository(dio: ref.watch(dioClientProvider));
});

class BackendAppVersionRepository {
  BackendAppVersionRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<AppVersionInfo?> fetch() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/app/version',
        queryParameters: {'app': _appName},
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
