// ─────────────────────────────────────────────────────────────────────
// BackendUnlockRequestRepository (Parent) — unlock so'roviga qaror
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   POST /api/unlock-requests/:id/decide  { approve, minutes? }  → 200
//   GET  /api/unlock-requests?status=pending                     → { requests }
//
// Ota-ona bola yuborgan "qo'shimcha vaqt" so'rovini rad etadi yoki 5–60
// daqiqa beradi. Backend bolaga FCM + app_limit:updated WS yuboradi.

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendUnlockRequestRepositoryProvider =
    Provider<BackendUnlockRequestRepository>((ref) {
  return BackendUnlockRequestRepository(dio: ref.watch(dioClientProvider));
});

class BackendUnlockRequestRepository {
  BackendUnlockRequestRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// So'rovga qaror. `approve=true` bo'lsa `minutes` (5..60) majburiy.
  /// `true` — muvaffaqiyatli.
  Future<bool> decide({
    required String requestId,
    required bool approve,
    int? minutes,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/unlock-requests/$requestId/decide',
        data: {
          'approve': approve,
          if (approve && minutes != null) 'minutes': minutes,
        },
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        'BackendUnlockRequestRepository.decide xato '
        '${e.response?.statusCode} body=${e.response?.data}',
      );
      return false;
    }
  }
}
