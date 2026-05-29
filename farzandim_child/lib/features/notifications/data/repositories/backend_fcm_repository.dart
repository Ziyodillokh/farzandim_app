// ─────────────────────────────────────────────────────────────────────
// BackendFcmRepository — Backend FCM token API (Sprint 4.4.8 Child)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt (Parent App bilan parallel):
//   POST   /api/fcm/tokens     body { token, deviceType, deviceId }
//   DELETE /api/fcm/tokens     hammasi (logout)
//
// Backend qachon voice/video/parent_request kelsa, registered token
// orqali FCM push yuboradi.

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendFcmRepositoryProvider = Provider<BackendFcmRepository>((ref) {
  return BackendFcmRepository(dio: ref.watch(dioClientProvider));
});

class BackendFcmRepository {
  BackendFcmRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// FCM token Backend'ga register qilish.
  Future<bool> registerToken({
    required String token,
    required String deviceType,
    required String deviceId,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/fcm/tokens',
        data: {
          'token': token,
          'deviceType': deviceType,
          'deviceId': deviceId,
        },
      );
      debugPrint('BackendFcm: token registered ($deviceType)');
      return true;
    } on DioException catch (e) {
      debugPrint(
        'BackendFcm.registerToken xato ${e.response?.statusCode}',
      );
      return false;
    }
  }

  /// Foydalanuvchining barcha tokenlari (full logout).
  Future<bool> deleteAllTokens() async {
    try {
      await _dio.delete<Map<String, dynamic>>('/fcm/tokens');
      return true;
    } on DioException {
      return false;
    }
  }
}
