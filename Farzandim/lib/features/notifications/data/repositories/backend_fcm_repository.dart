// ─────────────────────────────────────────────────────────────────────
// BackendFcmRepository — Backend FCM token API (Sprint 4.4.8)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   POST   /api/fcm/tokens         body { token, deviceType, deviceId }
//   GET    /api/fcm/tokens         → { tokens: [...], count }
//   DELETE /api/fcm/tokens/:id     bitta token o'chirish
//   DELETE /api/fcm/tokens         hammasi (full logout)
//
// Backend qachon voice/video/sos kelsa, registered tokenlar orqali
// FCM push yuboradi (Firebase Admin SDK).

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendFcmRepositoryProvider = Provider<BackendFcmRepository>((ref) {
  return BackendFcmRepository(dio: ref.watch(dioClientProvider));
});

class BackendFcmRepository {
  BackendFcmRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// FCM token Backend'ga register qilish.
  ///
  /// `token` — FirebaseMessaging.getToken() natijasi.
  /// `deviceType` — 'android' yoki 'ios'.
  /// `deviceId` — qurilma noyob ID (device_info_plus dan).
  ///
  /// Idempotent: bir xil token boshqa user'ga tegishli bo'lsa Backend
  /// upsert qilib egasini yangilaydi (qurilma boshqa hisobga login).
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
      debugPrint('BackendFcm: token registered ($deviceType, $deviceId)');
      return true;
    } on DioException catch (e) {
      debugPrint(
        'BackendFcm.registerToken xato ${e.response?.statusCode} '
        '— ${e.message}',
      );
      return false;
    }
  }

  /// Bitta token o'chirish (qurilma logout vaqti).
  Future<bool> deleteToken(String tokenId) async {
    try {
      await _dio.delete<void>('/fcm/tokens/$tokenId');
      return true;
    } on DioException {
      return false;
    }
  }

  /// Diagnostika: o'ziga test push yuborish.
  ///
  /// Backend natijani qaytaradi:
  ///   tokens — ro'yxatdan o'tgan token soni (0 → registratsiya muammosi)
  ///   sent   — muvaffaqiyatli yuborilgan (>0 → FCM yetkazdi)
  ///   failed — yuborilmagan (Firebase init xato yoki token yaroqsiz)
  /// `null` qaytsa — so'rov umuman bormadi (auth/tarmoq).
  Future<Map<String, dynamic>?> sendTestPush() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/fcm/test');
      return res.data;
    } on DioException catch (e) {
      debugPrint(
        'BackendFcm.sendTestPush xato ${e.response?.statusCode} — ${e.message}',
      );
      return null;
    }
  }

  /// Foydalanuvchining barcha tokenlari (full logout / hisob o'chirish).
  Future<bool> deleteAllTokens() async {
    try {
      await _dio.delete<Map<String, dynamic>>('/fcm/tokens');
      debugPrint('BackendFcm: all tokens deleted');
      return true;
    } on DioException {
      return false;
    }
  }
}
