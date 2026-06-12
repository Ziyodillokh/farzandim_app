// ─────────────────────────────────────────────────────────────────────
// DeviceLinkRepository — QR orqali 2-qurilma ulash (device-link)
// ─────────────────────────────────────────────────────────────────────
//
// Mas'ul qurilma (Faol seanslar → "Boshqa hisob qo'shish"):
//   create() → qisqa muddatli kod → QR ko'rsatiladi.
// Yangi qurilma (Kirish → "Akkauntga qo'shilish" → kamera skaner):
//   redeem(code) → parent tokenlari (AuthSession) → onLoggedIn → dashboard.

import 'package:dio/dio.dart';
import 'package:farzandim/core/device/device_meta.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/features/auth/data/models/auth_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// QR payload prefiksi — tasodifiy QR'larni rad etish uchun.
const String kDeviceLinkScheme = 'farzandim://device-link?code=';

final deviceLinkRepositoryProvider = Provider<DeviceLinkRepository>((ref) {
  return DeviceLinkRepository(dio: ref.watch(dioClientProvider));
});

class DeviceLinkCode {
  const DeviceLinkCode({required this.code, required this.expiresInSec});
  final String code;
  final int expiresInSec;

  /// QR ichiga yoziladigan to'liq payload.
  String get qrPayload => '$kDeviceLinkScheme$code';
}

class DeviceLinkRepository {
  DeviceLinkRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// Mas'ul qurilmada — QR uchun kod yaratadi (authed).
  Future<DeviceLinkCode> create() async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/device-link/create');
    final data = res.data ?? const <String, dynamic>{};
    return DeviceLinkCode(
      code: data['code'] as String? ?? '',
      expiresInSec: (data['expiresInSec'] as num?)?.toInt() ?? 300,
    );
  }

  /// Yangi qurilmada — skanerlangan kod bilan kirish (anonim).
  /// `scanned` to'liq QR matni yoki xom kod bo'lishi mumkin.
  Future<AuthSession> redeem(String scanned) async {
    final code = _extractCode(scanned);
    if (code.isEmpty) {
      throw const FormatException('QR kod yaroqsiz');
    }
    final device = await currentDeviceMeta();
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/device-link/redeem',
      data: <String, dynamic>{
        'code': code,
        ...device.toJson(),
      },
    );
    return AuthSession.fromJson(res.data ?? <String, dynamic>{});
  }

  /// QR matnidan kodni ajratib oladi (`farzandim://device-link?code=XXX`
  /// yoki xom kod).
  String _extractCode(String scanned) {
    final s = scanned.trim();
    if (s.startsWith(kDeviceLinkScheme)) {
      return s.substring(kDeviceLinkScheme.length).trim();
    }
    // Boshqa farzandim:// payloadlar (masalan eski add-account) — rad etamiz.
    if (s.startsWith('farzandim://')) return '';
    return s; // xom kod
  }
}
