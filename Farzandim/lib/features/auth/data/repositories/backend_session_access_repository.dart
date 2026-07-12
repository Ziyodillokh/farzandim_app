// Session access (2-qurilma limit) — 3-qurilma kirish so'rovi.
//
// Oqim: login 409 DEVICE_LIMIT_REACHED (+pendingToken) → requestAccess()
// (2 qurilmaga push) → pollStatus() (tasdiq + slot bo'shashini kutadi) →
// APPROVED + tokenlar kelsa kiradi. Ulangan qurilma listPending/approve/reject.

import 'package:dio/dio.dart';
import 'package:farzandim/core/device/device_meta.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/features/auth/data/models/auth_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 2-qurilma limiti to'lganda login shuni tashlaydi (pendingToken bilan).
class DeviceLimitException implements Exception {
  const DeviceLimitException(this.pendingToken);
  final String pendingToken;
}

/// Poll natijasi holati.
enum SessionAccessStatus {
  pending, // hali qaror yo'q
  approvedWaitingSlot, // tasdiqlangan, lekin qurilma chiqarilishini kutmoqda
  approvedReady, // tasdiqlangan + slot bo'sh → tokenlar keldi (kiramiz)
  rejected,
  expired,
}

class SessionAccessPoll {
  const SessionAccessPoll(this.status, {this.session});
  final SessionAccessStatus status;
  final AuthSession? session; // faqat approvedReady bo'lsa
}

/// Ulangan qurilma ko'radigan ochiq so'rov.
class SessionAccessRequestInfo {
  const SessionAccessRequestInfo({
    required this.id,
    this.deviceModel,
    this.platform,
    this.ipAddress,
    this.createdAt,
    this.expiresAt,
  });

  factory SessionAccessRequestInfo.fromJson(Map<String, dynamic> j) =>
      SessionAccessRequestInfo(
        id: j['id'] as String,
        deviceModel: j['deviceModel'] as String?,
        platform: j['platform'] as String?,
        ipAddress: j['ipAddress'] as String?,
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
        expiresAt: j['expiresAt'] != null
            ? DateTime.tryParse(j['expiresAt'] as String)
            : null,
      );

  final String id;
  final String? deviceModel;
  final String? platform;
  final String? ipAddress;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  String get displayName {
    final m = deviceModel?.trim();
    if (m != null && m.isNotEmpty) return m;
    switch (platform?.toLowerCase()) {
      case 'ios':
        return 'iPhone';
      case 'android':
        return 'Android qurilma';
      case 'web':
        return 'Brauzer';
      default:
        return 'Yangi qurilma';
    }
  }
}

final backendSessionAccessRepositoryProvider =
    Provider<BackendSessionAccessRepository>((ref) {
      return BackendSessionAccessRepository(dio: ref.watch(dioClientProvider));
    });

class BackendSessionAccessRepository {
  BackendSessionAccessRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// "Ruxsat so'rash" — 2 ta ulangan qurilmaga push yuboradi.
  Future<({String requestId, String pollToken, int pollIntervalSec})>
  requestAccess(String pendingToken) async {
    final device = await currentDeviceMeta();
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/session-access/request',
      data: <String, dynamic>{'pendingToken': pendingToken, ...device.toJson()},
    );
    final d = res.data ?? const <String, dynamic>{};
    return (
      requestId: d['requestId'] as String,
      pollToken: d['pollToken'] as String,
      pollIntervalSec: (d['pollIntervalSec'] as num?)?.toInt() ?? 3,
    );
  }

  /// So'rov holatini poll qiladi. APPROVED + slot bo'sh → session keladi.
  Future<SessionAccessPoll> pollStatus(
    String requestId,
    String pollToken,
  ) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/auth/session-access/status/$requestId',
        queryParameters: <String, dynamic>{'token': pollToken},
      );
      final d = res.data ?? const <String, dynamic>{};
      final status = (d['status'] as String?)?.toUpperCase();
      switch (status) {
        case 'APPROVED':
          if (d['accessToken'] != null) {
            return SessionAccessPoll(
              SessionAccessStatus.approvedReady,
              session: AuthSession.fromJson(d),
            );
          }
          return const SessionAccessPoll(
            SessionAccessStatus.approvedWaitingSlot,
          );
        case 'REJECTED':
          return const SessionAccessPoll(SessionAccessStatus.rejected);
        case 'EXPIRED':
        case 'CONSUMED':
          return const SessionAccessPoll(SessionAccessStatus.expired);
        default:
          return const SessionAccessPoll(SessionAccessStatus.pending);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const SessionAccessPoll(SessionAccessStatus.expired);
      }
      rethrow;
    }
  }

  /// Ochiq so'rovlar (ulangan qurilma tasdiqlashi uchun).
  Future<List<SessionAccessRequestInfo>> listPending() async {
    final res = await _dio.get<List<dynamic>>('/auth/session-access/pending');
    return (res.data ?? const <dynamic>[])
        .map(
          (e) => SessionAccessRequestInfo.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> approve(String id) =>
      _dio.post<void>('/auth/session-access/$id/approve');

  Future<void> reject(String id) =>
      _dio.post<void>('/auth/session-access/$id/reject');
}
