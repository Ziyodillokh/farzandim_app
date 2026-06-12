// Per-app limitlar API'si. Blok = dailyLimitMs 0, limit = daqiqa * 60000.

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/network/friendly_error.dart';
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
    // O'qish ham throw qiladi — offline'da yolg'on "limit yo'q"
    // ko'rinmasin (ekranda error branch bor).
    final wires = await _getLimits(childId, throwOnError: true);
    return wires.map((w) => w.toRestriction()).toList();
  }

  /// `throwOnError`: `remove()` kabi yozuv oqimlarida true — xato yutilsa
  /// "limit topilmadi → allaqachon yo'q → muvaffaqiyat" degan yolg'on
  /// natija chiqadi: foydalanuvchi "o'chirildi" deb o'ylaydi, blok esa
  /// bola qurilmasida aktiv qolaveradi.
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
  /// Backend POST idempotent upsert (`(childId, packageName)` unique):
  /// mavjud bo'lsa yangilaydi, yo'q bo'lsa yaratadi. Shuning uchun
  /// GET-then-PUT kerak emas — har doim POST qilamiz.
  ///
  /// `appName` yuborilmaydi (backend modelida yo'q). Xato bo'lsa aniq
  /// sababli [AppLimitException] tashlaydi.
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

  /// Domain'ga xos 401/403/404 xabarlari; qolgan hamma holat (backend
  /// message, internet yo'q) markaziy `friendlyError`da — status-kod
  /// mantig'i takrorlanmaydi.
  String _messageForDioError(DioException e) {
    final code = e.response?.statusCode;
    // 401 friendlyError'dan oldin tekshiriladi: backend auth xabari
    // inglizcha, friendlyError uni shundayligicha ko'rsatib yuborardi.
    // Lokal sessiya xabari aniqroq.
    if (code == 401) return 'errors.sessionExpired'.tr();
    if (code == 403) return 'errors.appLimit.childNotLinked'.tr();
    if (code == 404) return 'errors.appLimit.childNotFound'.tr();
    return friendlyError(e, fallback: 'errors.appLimit.saveFailed'.tr());
  }
}

/// App-limit operatsiyasi muvaffaqiyatsiz bo'lganda — aniq, ko'rsatish mumkin
/// bo'lgan xabar bilan (generic "saqlashda xatolik" o'rniga).
class AppLimitException implements Exception {
  AppLimitException(this.message);

  /// Foydalanuvchiga ko'rsatiladigan xabar.
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
