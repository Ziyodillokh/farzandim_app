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

/// Ota-ona tasdiqlagan, hali amal qilayotgan qo'shimcha vaqt.
@immutable
class ActiveUnlockGrant {
  const ActiveUnlockGrant({required this.expiresAt, required this.remaining});

  factory ActiveUnlockGrant.fromJson(Map<String, dynamic> json) {
    return ActiveUnlockGrant(
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      remaining: Duration(
        seconds: (json['remainingSeconds'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  final DateTime expiresAt;
  final Duration remaining;
}

class BackendUnlockRequestRepository {
  BackendUnlockRequestRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// Bloklangan ilova ('APP') yoki ekran-vaqt ('SCREEN_TIME') uchun
  /// qo'shimcha vaqt so'rovi. childId JWT'dan olinadi (path'da kerak emas).
  /// Backend dublikat (ochiq PENDING) bo'lsa o'shanini qaytaradi — spam yo'q.
  ///
  /// [requestedMinutes] (5..60) va [reason] bola modalda kiritadi — ota-onaga
  /// ko'rsatiladi; tasdiqlanса o'shancha miqdorda limit qo'shiladi.
  Future<bool> createRequest({
    required String kind,
    String? packageName,
    int? requestedMinutes,
    String? reason,
  }) async {
    try {
      final trimmedReason = reason?.trim();
      await _dio.post<Map<String, dynamic>>(
        '/unlock-requests',
        data: {
          'kind': kind,
          if (packageName != null && packageName.isNotEmpty)
            'packageName': packageName,
          if (requestedMinutes != null) 'requestedMinutes': requestedMinutes,
          if (trimmedReason != null && trimmedReason.isNotEmpty)
            'reason': trimmedReason,
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

  /// Hozir amal qilayotgan grantlar. Tarmoq/format xatosida `null` —
  /// chaqiruvchi oxirgi holatni o'zgartirmaydi.
  Future<List<ActiveUnlockGrant>?> getActiveGrants() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/unlock-requests/active',
      );
      final grants = response.data?['grants'] as List<dynamic>?;
      if (grants == null) return null;
      return grants
          .map((g) => ActiveUnlockGrant.fromJson(g as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint(
        'BackendUnlockRequestRepository.getActiveGrants xato '
        '${e.response?.statusCode}',
      );
      return null;
    } on FormatException catch (e) {
      debugPrint('BackendUnlockRequestRepository.getActiveGrants format: $e');
      return null;
    }
  }
}
