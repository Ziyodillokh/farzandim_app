// ─────────────────────────────────────────────────────────────────────
// PairingRepository — Backend REST pairing (Sprint 4.4)
// ─────────────────────────────────────────────────────────────────────
//
// Eski Firestore pairing: `collectionGroup('children').where('familyCode')`
// — Parent backend'ga ko'chgandan keyin Firestore'da children yo'q.
//
// Yangi flow:
//   1. POST /api/auth/child-pair { familyCode }
//   2. Response: { accessToken, refreshToken, user, child }
//   3. JWT TokenStorage'ga, parentUid + childId pairing_state'ga
//   4. Endi Child App backend REST + WS bilan ishlaydi
//
// Re-pair: bir xil familyCode qayta kiritilsa Backend `childUserId`
// yangi userga bog'laydi (eski child JWT bekor bo'ladi).

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pairingRepositoryProvider = Provider<PairingRepository>((ref) {
  return PairingRepository(
    dio: ref.watch(dioClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

/// Pairing natijasi — muvaffaqiyat yoki konkret xato sababi bilan.
/// UX'da har xato uchun mos xabar ko'rsatish uchun.
sealed class PairingResult {
  const PairingResult();
}

class PairingSuccess extends PairingResult {
  const PairingSuccess({
    required this.parentUid,
    required this.childId,
    required this.currentUserId,
  });
  final String parentUid;
  final String childId;

  /// Backend Child User ID (JWT user.id). Voice messages sender
  /// directionini (chap/o'ng bubble) aniqlashda kerak (Sprint 4.4.5).
  final String currentUserId;
}

/// Kod noto'g'ri (404) — kod hech qaysi bola'da yo'q.
class PairingFailureInvalidCode extends PairingResult {
  const PairingFailureInvalidCode();
}

/// Kod allaqachon ishlatilgan (409) — bola boshqa qurilma bilan
/// bog'langan. Parent yangi kod yaratishi kerak (regenerate).
class PairingFailureAlreadyUsed extends PairingResult {
  const PairingFailureAlreadyUsed();
}

/// Backend 0.6.0 re-pair flow — 409 + `AWAITING_PARENT_CONFIRM`.
/// Parent App'ga FCM push ketadi, bola polling boshlaydi.
class PairingAwaitingParent extends PairingResult {
  const PairingAwaitingParent({
    required this.pairRequestId,
    required this.expiresAt,
  });

  final String pairRequestId;
  final DateTime expiresAt;
}

/// Pair request status polling natijasi.
sealed class PairStatusResult {
  const PairStatusResult();
}

class PairStatusPending extends PairStatusResult {
  const PairStatusPending({required this.expiresAt});
  final DateTime expiresAt;
}

class PairStatusApproved extends PairStatusResult {
  const PairStatusApproved({
    required this.parentUid,
    required this.childId,
    required this.currentUserId,
  });
  final String parentUid;
  final String childId;
  final String currentUserId;
}

class PairStatusRejected extends PairStatusResult {
  const PairStatusRejected();
}

class PairStatusExpired extends PairStatusResult {
  const PairStatusExpired();
}

class PairStatusError extends PairStatusResult {
  const PairStatusError(this.message);
  final String message;
}

/// Tarmoq yoki server xatosi — qayta urinish.
class PairingFailureNetwork extends PairingResult {
  const PairingFailureNetwork(this.message);
  final String message;
}

class PairingRepository {
  PairingRepository({
    required Dio dio,
    required TokenStorage tokenStorage,
  })  : _dio = dio,
        _tokenStorage = tokenStorage;

  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// 5-raqamli familyCode bilan Backend'ga ulanish.
  /// `childDeviceUid` ignored (eski Firestore signature uchun saqlanadi).
  ///
  /// Returns `PairingResult` sealed class:
  ///   - `PairingSuccess` — JWT olindi, parent + child uid
  ///   - `PairingFailureInvalidCode` — kod noto'g'ri (404)
  ///   - `PairingFailureAlreadyUsed` — kod ishlatilgan (409),
  ///     parent regenerate qilishi kerak
  ///   - `PairingFailureNetwork` — tarmoq xato
  Future<PairingResult> verifyCode(
    String code,
    String childDeviceUid, // eski signature, ignored
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/child-pair',
        data: {'familyCode': code},
      );
      final data = response.data;
      if (data == null) {
        return const PairingFailureNetwork('Empty response');
      }

      final accessToken = data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String?;
      if (accessToken == null || refreshToken == null) {
        debugPrint('PairingRepo: tokens yo\'q response: $data');
        return const PairingFailureNetwork('Tokens missing');
      }

      // 1. JWT'ni saqlaymiz — keyingi REST chaqiruvlarda Bearer header
      await _tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      // 2. parentUid + childId — child obyektidan
      final child = data['child'];
      if (child is! Map<String, dynamic>) {
        debugPrint('PairingRepo: child obyekti yo\'q');
        return const PairingFailureNetwork('Child missing');
      }
      final parentUid = child['parentId'] as String?;
      final childId = child['id'] as String?;
      if (parentUid == null || childId == null) {
        return const PairingFailureNetwork('parentId/childId missing');
      }

      // currentUserId — Backend Child User ID (Sprint 4.4.5 voice messages).
      final user = data['user'];
      final currentUserId = user is Map<String, dynamic>
          ? (user['id'] as String?) ?? ''
          : '';

      debugPrint(
        'PairingRepo: ulandi parent=$parentUid child=$childId '
        'user=$currentUserId (Backend)',
      );

      return PairingSuccess(
        parentUid: parentUid,
        childId: childId,
        currentUserId: currentUserId,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      debugPrint(
        'PairingRepo: pair fail status=$status body=$body',
      );
      switch (status) {
        case 409:
          // Backend 0.6.0 — 2 ta variant:
          //   - AWAITING_PARENT_CONFIRM → pair request yaratildi, parent
          //     tasdiqi kutilmoqda
          //   - boshqa (eski) → kod ishlatilgan
          if (body is Map<String, dynamic>) {
            final code = body['code'] as String?;
            if (code == 'AWAITING_PARENT_CONFIRM') {
              final pairRequestId = body['pairRequestId'] as String?;
              final expiresAtIso = body['expiresAt'] as String?;
              if (pairRequestId != null && pairRequestId.isNotEmpty) {
                final expiresAt =
                    DateTime.tryParse(expiresAtIso ?? '')?.toLocal() ??
                        DateTime.now().add(const Duration(minutes: 5));
                return PairingAwaitingParent(
                  pairRequestId: pairRequestId,
                  expiresAt: expiresAt,
                );
              }
            }
          }
          return const PairingFailureAlreadyUsed();
        case 400:
        case 404:
          return const PairingFailureInvalidCode();
        default:
          return PairingFailureNetwork(e.message ?? 'Unknown');
      }
    }
  }

  /// Pair request statusini tekshirish (har 3 sek polling).
  /// Endpoint: GET /api/auth/child-pair-status/:id (NO AUTH).
  ///
  /// APPROVED bo'lsa response'da JWT tokenlar va child obyekti keladi —
  /// avtomatik saqlanadi va `PairStatusApproved` qaytariladi.
  Future<PairStatusResult> checkPairStatus(String pairRequestId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/auth/child-pair-status/$pairRequestId',
      );
      final data = response.data;
      if (data == null) {
        return const PairStatusError('Empty response');
      }
      final status = data['status'] as String?;

      switch (status) {
        case 'PENDING':
          final expiresAt =
              DateTime.tryParse(data['expiresAt'] as String? ?? '')
                      ?.toLocal() ??
                  DateTime.now().add(const Duration(minutes: 5));
          return PairStatusPending(expiresAt: expiresAt);
        case 'APPROVED':
          // JWT keladi → saqlaymiz va child obyektidan parentId/childId
          final accessToken = data['accessToken'] as String?;
          final refreshToken = data['refreshToken'] as String?;
          if (accessToken == null || refreshToken == null) {
            return const PairStatusError('Tokens missing in APPROVED');
          }
          await _tokenStorage.saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
          final child = data['child'];
          if (child is! Map<String, dynamic>) {
            return const PairStatusError('Child missing in APPROVED');
          }
          final parentUid = child['parentId'] as String?;
          final childId = child['id'] as String?;
          if (parentUid == null || childId == null) {
            return const PairStatusError('parentId/childId missing');
          }
          final user = data['user'];
          final currentUserId = user is Map<String, dynamic>
              ? (user['id'] as String?) ?? ''
              : '';
          return PairStatusApproved(
            parentUid: parentUid,
            childId: childId,
            currentUserId: currentUserId,
          );
        case 'REJECTED':
          return const PairStatusRejected();
        case 'EXPIRED':
          return const PairStatusExpired();
        default:
          return PairStatusError('Unknown status: $status');
      }
    } on DioException catch (e) {
      return PairStatusError(e.message ?? 'Network error');
    }
  }

  /// Bola ma'lumotlarini Backend'dan oladi (pair tugagach).
  /// Endpoint: GET /api/children/:id (Bearer token bilan).
  Future<Map<String, dynamic>?> getChildData(
    String parentUid, // ignored — backend o'zi auth'dan biladi
    String childId,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId',
      );
      return response.data;
    } on DioException catch (e) {
      debugPrint('PairingRepo: getChildData fail ${e.message}');
      return null;
    }
  }

  /// Joriy CHILD user ID (Backend `user.id`) — fallback for eski
  /// pair'lar (Sprint 4.4.5 voice messages uchun). `GET /api/users/me`.
  Future<String?> getMeUserId() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/users/me');
      return response.data?['id'] as String?;
    } on DioException catch (e) {
      debugPrint('PairingRepo: getMeUserId fail ${e.message}');
      return null;
    }
  }
}
