// ─────────────────────────────────────────────────────────────────────
// BackendUnlockRequestRepository — bola "qo'shimcha vaqt" so'rovi
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   POST /api/unlock-requests        { kind, packageName? }  → 201 (PENDING)
//   GET  /api/unlock-requests/active                          → { grants, count }
//
// Bola bloklangan ilova uchun so'rov yuboradi; ota-ona qaror bergach
// backend `app_limit:updated` WS + `unlock_decision` FCM yuboradi va
// RestrictionsSyncService limitни qayta yuklaydi (server effektiv limitga
// grant daqiqalarini qo'shadi).

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendUnlockRequestRepositoryProvider =
    Provider<BackendUnlockRequestRepository>((ref) {
  return BackendUnlockRequestRepository(dio: ref.watch(dioClientProvider));
});

class BackendUnlockRequestRepository {
  BackendUnlockRequestRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// Bloklangan ilova ('APP') yoki ekran-vaqt ('SCREEN_TIME') uchun
  /// qo'shimcha vaqt so'rovi. childId JWT'dan olinadi (path'da kerak emas).
  /// Backend dublikat (ochiq PENDING) bo'lsa o'shanini qaytaradi — spam yo'q.
  Future<bool> createRequest({
    required String kind,
    String? packageName,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/unlock-requests',
        data: {
          'kind': kind,
          if (packageName != null && packageName.isNotEmpty)
            'packageName': packageName,
        },
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        'BackendUnlockRequestRepository.createRequest xato '
        '${e.response?.statusCode} body=${e.response?.data}',
      );
      return false;
    }
  }
}
