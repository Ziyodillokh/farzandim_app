// Per-app ruxsat siyosati API'si; ro'yxatda yo'q ilova default ruxsatli.

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendAppPermissionRepositoryProvider =
    Provider<BackendAppPermissionRepository>((ref) {
      return BackendAppPermissionRepository(dio: ref.watch(dioClientProvider));
    });

class BackendAppPermissionRepository {
  BackendAppPermissionRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// `permission` uchun siyosatlar: packageName → allowed.
  Future<Map<String, bool>> getPolicies({
    required String childId,
    required String permission,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/app-permissions',
        queryParameters: {'permission': permission},
      );
      final list = response.data?['policies'] as List<dynamic>? ?? const [];
      final map = <String, bool>{};
      for (final p in list) {
        final m = p as Map;
        map[m['packageName'] as String] = m['allowed'] as bool? ?? true;
      }
      return map;
    } on DioException catch (e) {
      // Xatoni yutmaymiz — offline'da yolg'on "hammasi ruxsat" ko'rinardi.
      debugPrint('BackendAppPermissionRepository.getPolicies: $e');
      rethrow;
    }
  }

  /// Bitta ilova-ruxsat siyosatini saqlaydi.
  Future<void> setPolicy({
    required String childId,
    required String packageName,
    required String permission,
    required bool allowed,
  }) async {
    await _dio.put<Map<String, dynamic>>(
      '/children/$childId/app-permissions',
      data: {
        'packageName': packageName,
        'permission': permission,
        'allowed': allowed,
      },
    );
  }
}

/// (childId, permission) → packageName→allowed map.
/// Ro'yxatda yo'q ilova UI'da default `true` ko'rsatiladi.
final appPermissionPoliciesProvider =
    FutureProvider.family<Map<String, bool>, (String, String)>((
      ref,
      key,
    ) async {
      final (childId, permission) = key;
      final repo = ref.watch(backendAppPermissionRepositoryProvider);
      return repo.getPolicies(childId: childId, permission: permission);
    });
