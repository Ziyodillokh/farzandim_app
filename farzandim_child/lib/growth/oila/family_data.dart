// F04 · Qo'shimcha vaqt so'rovlari (bola tomoni): o'z so'rovlari, yangi
// so'rov va javob kutayotganini bekor qilish (`/api/unlock-requests`).
// Bola so'raydi — ota-ona hal qiladi; cheklovni chetlab o'tish yo'q.

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ExtraTimeStatus { pending, approved, denied, expired, cancelled }

/// Bola so'rashi mumkin bo'lgan daqiqalar (F04).
const kExtraTimeOptions = [10, 15, 30];

@immutable
class ExtraTimeRequest {
  const ExtraTimeRequest({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.requestedMinutes,
    this.grantedMinutes,
    this.reason,
  });

  static ExtraTimeRequest? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    final requestedAt = DateTime.tryParse('${json['requestedAt']}');
    if (id == null || requestedAt == null || json['kind'] != 'SCREEN_TIME') {
      return null;
    }
    return ExtraTimeRequest(
      id: id,
      status: switch (json['status']) {
        'APPROVED' => ExtraTimeStatus.approved,
        'DENIED' => ExtraTimeStatus.denied,
        'EXPIRED' => ExtraTimeStatus.expired,
        'CANCELLED' => ExtraTimeStatus.cancelled,
        _ => ExtraTimeStatus.pending,
      },
      requestedAt: requestedAt.toLocal(),
      requestedMinutes: jsonInt(json['requestedMinutes']),
      grantedMinutes: jsonInt(json['grantedMinutes']),
      reason: jsonNonEmpty(json['reason']),
    );
  }

  final String id;
  final ExtraTimeStatus status;
  final DateTime requestedAt;
  final int? requestedMinutes;
  final int? grantedMinutes;
  final String? reason;
}

class ExtraTimeException implements Exception {
  const ExtraTimeException({this.network = false, this.alreadyDecided = false});

  final bool network;
  final bool alreadyDecided;
}

class ExtraTimeRepository {
  ExtraTimeRepository(this._dio);

  final Dio _dio;

  /// So'nggi ekran vaqti so'rovi (`null` — oxirgi 24 soatda yo'q).
  Future<ExtraTimeRequest?> latest() => _guard(() async {
    final res = await _dio.get<Object?>('/unlock-requests/mine');
    final data = res.data;
    final rows = data is Map ? data['requests'] : null;
    if (rows is! List) return null;
    for (final row in rows) {
      final request = ExtraTimeRequest.tryFromJson(row);
      if (request != null) return request;
    }
    return null;
  });

  Future<void> ask({required int minutes, String? reason}) => _guard(() async {
    await _dio.post<Object?>(
      '/unlock-requests',
      data: {
        'kind': 'SCREEN_TIME',
        'requestedMinutes': minutes,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  });

  Future<void> cancel(String id) => _guard(() async {
    await _dio.post<Object?>(
      '/unlock-requests/${Uri.encodeComponent(id)}/cancel',
    );
  });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      debugPrint('[oila] ${e.requestOptions.path}: ${e.response?.statusCode}');
      final data = e.response?.data;
      throw ExtraTimeException(
        network: e.response == null,
        alreadyDecided: data is Map && data['code'] == 'ALREADY_DECIDED',
      );
    }
  }
}

final extraTimeRepositoryProvider = Provider<ExtraTimeRepository>(
  (ref) => ExtraTimeRepository(ref.watch(dioClientProvider)),
);

final latestExtraTimeProvider = FutureProvider.autoDispose<ExtraTimeRequest?>(
  (ref) => ref.watch(extraTimeRepositoryProvider).latest(),
);
