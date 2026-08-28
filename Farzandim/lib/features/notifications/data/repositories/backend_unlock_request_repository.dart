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

  /// Kutilayotgan (PENDING) so'rovlarni serverdan olib keladi.
  ///
  /// ⚠️ NEGA KERAK: 2026-08-28'gacha ota-ona ilovasida bola so'rovini
  /// ko'rsatadigan YAGONA kanal FCM push edi — `unlock_request:created`
  /// WS hodisasining tinglovchisi yo'q, bazadagi `Notification` yozuvi
  /// esa hech qachon o'qilmasdi. Push bitta sababga ko'ra yetib bormasa
  /// (bildirishnoma ruxsati o'chiq, token eskirgan, telefon Doze'da,
  /// ilova majburan to'xtatilgan) so'rov butunlay ko'rinmas bo'lardi va
  /// ota-ona uni ochib ko'radigan ro'yxat ham yo'q edi.
  ///
  /// Bu metod o'sha bo'shliqni yopadi: ilova ochilganda va fondan
  /// qaytganda server haqiqatini so'raymiz. Xato bo'lsa bo'sh ro'yxat —
  /// mavjud push oqimi hech qachon buzilmaydi.
  Future<List<Map<String, dynamic>>> listPending() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/unlock-requests',
        // Backend DTO kichik harf kutadi
        // (IsIn: pending|approved|denied|expired).
        queryParameters: const {'status': 'pending'},
      );
      final raw = response.data?['requests'];
      if (raw is! List) return const [];
      return raw.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (e) {
      debugPrint(
        'BackendUnlockRequestRepository.listPending xato '
        '${e.response?.statusCode}',
      );
      return const [];
    }
  }

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
