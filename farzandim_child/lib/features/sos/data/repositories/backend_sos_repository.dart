// ─────────────────────────────────────────────────────────────────────
// BackendSosRepository — Child App SOS trigger (Sprint 4.4.9.5)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt (Child JWT bilan):
//   POST /api/children/:childId/sos-alerts → SosAlert (ACTIVE)
//
// Backend o'zi WS `sos:received` parent rooms'ga emit qiladi +
// FCM HIGH priority push (ringtone + vibrate).

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendSosRepositoryProvider = Provider<BackendSosRepository>((ref) {
  return BackendSosRepository(dio: ref.watch(dioClientProvider));
});

class BackendSosRepository {
  BackendSosRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// SOS trigger — bola yordam so'rashi.
  ///
  /// Backend o'zi parent'ga FCM push + WS event yuboradi.
  /// Frontend `lat/lng/accuracy/deviceInfo` ixtiyoriy.
  Future<String?> triggerAlert({
    required String childId,
    double? latitude,
    double? longitude,
    double? accuracy,
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/children/$childId/sos-alerts',
        data: {
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (accuracy != null) 'accuracy': accuracy,
          if (deviceInfo != null) 'deviceInfo': deviceInfo,
        },
      );
      final id = response.data?['id'] as String?;
      debugPrint('BackendSos: alert sent ($id)');
      return id;
    } on DioException catch (e) {
      debugPrint(
        'BackendSosRepository.triggerAlert xato '
        '${e.response?.statusCode}',
      );
      return null;
    }
  }
}
