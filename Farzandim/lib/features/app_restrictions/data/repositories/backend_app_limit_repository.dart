// ─────────────────────────────────────────────────────────────────────
// BackendAppLimitRepository — Per-app limits (Backend 0.5.1)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt (`/api/children/:childId/app-limits`):
//   GET    /api/children/:childId/app-limits → {limits: [...], count}
//   POST   /api/children/:childId/app-limits body: {packageName, dailyLimitMs}
//   PUT    /api/app-limits/:id body: {dailyLimitMs}
//   DELETE /api/app-limits/:id
//
// Mapping:
//   Block       → POST { packageName, dailyLimitMs: 0 }
//   Limit 30min → POST { packageName, dailyLimitMs: 1800000 }
//   Remove      → DELETE /app-limits/:id

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_restriction.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendAppLimitRepositoryProvider =
    Provider<BackendAppLimitRepository>((ref) {
  return BackendAppLimitRepository(dio: ref.watch(dioClientProvider));
});

class BackendAppLimitRepository {
  BackendAppLimitRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// Bola uchun barcha app limit'lar — domain model.
  Future<List<AppRestriction>> getRestrictions(String childId) async {
    // EH-09: o'qish ham throw qiladi — offline'da yolg'on "limit yo'q"
    // ko'rinmasin (ekranda error branch bor).
    final wires = await _getLimits(childId, throwOnError: true);
    return wires.map((w) => w.toRestriction()).toList();
  }

  /// `throwOnError`: `remove()` kabi YOZUV oqimlarida true — xato yutilsa
  /// "limit topilmadi → allaqachon yo'q → muvaffaqiyat" degan YOLG'ON natija
  /// chiqardi (EH-04): offline'da foydalanuvchi "o'chirildi" deb o'ylaydi,
  /// blok esa bola qurilmasida aktiv qoladi.
  Future<List<_AppLimitWire>> _getLimits(
    String childId, {
    bool throwOnError = false,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/app-limits',
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['limits'] as List<dynamic>? ?? const [];
      return list
          .map((m) => _AppLimitWire.fromJson(m as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('BackendAppLimitRepository._getLimits: $e');
      if (throwOnError) rethrow;
      return const [];
    }
  }

  /// Cheklov o'rnatish/yangilash.
  ///
  /// Backend POST endi **idempotent upsert** (`(childId, packageName)` unique):
  /// mavjud bo'lsa yangilaydi, aks holda yaratadi. Shuning uchun GET-then-PUT
  /// kerak emas — DOIM POST qilamiz. (Avval GET muvaffaqiyatsiz bo'lsa
  /// `_getLimits` jim `[]` qaytarib, noto'g'ri yo'l tanlanardi va 409/xato
  /// "saqlashda xatolik" sifatida ko'rinardi.)
  ///
  /// `appName` yuborilmaydi (backend modelida yo'q; backend eski klientlar
  /// uchun qabul qilsa-da, e'tiborsiz qoldiradi). Xato bo'lsa aniq sababli
  /// [AppLimitException] tashlaydi.
  Future<bool> upsert({
    required String childId,
    required String packageName,
    required String appName,
    required int dailyLimitMs,
  }) async {
    try {
      await _dio.post<void>(
        '/children/$childId/app-limits',
        data: {
          'packageName': packageName,
          'dailyLimitMs': dailyLimitMs,
        },
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        'BackendAppLimitRepository.upsert xato '
        '${e.response?.statusCode} body=${e.response?.data}',
      );
      throw AppLimitException(_messageForDioError(e));
    }
  }

  /// Cheklovni o'chirish (cheklanmagan). Backend DELETE id bo'yicha, shuning
  /// uchun avval `(childId, packageName)` bo'yicha id topamiz.
  Future<bool> remove({
    required String childId,
    required String packageName,
  }) async {
    final _AppLimitWire? match;
    try {
      // throwOnError: GET yiqilsa yolg'on "allaqachon yo'q" emas — aniq xato.
      final existing = await _getLimits(childId, throwOnError: true);
      match = existing
          .where((l) => l.packageName == packageName)
          .cast<_AppLimitWire?>()
          .firstWhere((_) => true, orElse: () => null);
    } on DioException catch (e) {
      throw AppLimitException(_messageForDioError(e));
    }
    if (match == null) return true; // allaqachon yo'q
    try {
      await _dio.delete<void>('/app-limits/${match.id}');
      return true;
    } on DioException catch (e) {
      debugPrint(
        'BackendAppLimitRepository.remove xato '
        '${e.response?.statusCode} body=${e.response?.data}',
      );
      throw AppLimitException(_messageForDioError(e));
    }
  }

  /// DioException'dan foydalanuvchiga ko'rsatish uchun aniq o'zbekcha xabar.
  String _messageForDioError(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    String? serverMsg;
    if (data is Map) {
      final m = data['message'];
      if (m is String) {
        serverMsg = m;
      } else if (m is List && m.isNotEmpty) {
        serverMsg = m.map((x) => '$x').join(', ');
      }
    }
    if (code == null) {
      return 'Internet aloqasi yo\'q yoki server javob bermadi. Qayta urinib ko\'ring.';
    }
    if (code == 401) return 'Sessiya muddati tugagan — qaytadan kiring.';
    if (code == 403) return 'Bu bola sizning akkauntingizga ulanmagan.';
    if (code == 404) return 'Bola topilmadi.';
    return serverMsg ?? 'Saqlashda xatolik (server $code).';
  }
}

/// App-limit operatsiyasi muvaffaqiyatsiz bo'lganda — aniq, ko'rsatish mumkin
/// bo'lgan xabar bilan (generic "saqlashda xatolik" o'rniga).
class AppLimitException implements Exception {
  AppLimitException(this.message);

  /// Foydalanuvchiga ko'rsatiladigan o'zbekcha xabar.
  final String message;

  @override
  String toString() => message;
}

@immutable
class _AppLimitWire {
  const _AppLimitWire({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.dailyLimitMs,
    required this.updatedAt,
  });

  factory _AppLimitWire.fromJson(Map<String, dynamic> json) {
    return _AppLimitWire(
      id: json['id'] as String? ?? '',
      packageName: json['packageName'] as String? ?? '',
      appName: (json['appName'] as String?) ?? '',
      dailyLimitMs: (json['dailyLimitMs'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')
              ?.toLocal() ??
          DateTime.now(),
    );
  }

  final String id;
  final String packageName;
  final String appName;
  final int dailyLimitMs;
  final DateTime updatedAt;

  /// Domain modelga konvertatsiya.
  AppRestriction toRestriction() {
    return AppRestriction(
      packageName: packageName,
      appName: appName,
      limitMinutes: dailyLimitMs ~/ 60000,
      isBlocked: dailyLimitMs == 0,
      updatedAt: updatedAt,
    );
  }
}


