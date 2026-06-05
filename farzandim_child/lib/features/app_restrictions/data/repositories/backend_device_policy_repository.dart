// ─────────────────────────────────────────────────────────────────────
// BackendDevicePolicyRepository — qurilma siyosati (Child o'qiydi)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   GET /api/children/:childId/device-policy → { blockUnknownSources }
//
// Ota-ona "Notanish manbalardan ilovalar" toggle'ini yoqsa, bola qurilmasi
// shu siyosatni o'qib SharedPreferences'ga yozadi; native RestrictionService
// Play'dan boshqa manbadagi ilovalarni bloklaydi.

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendDevicePolicyRepositoryProvider =
    Provider<BackendDevicePolicyRepository>((ref) {
  return BackendDevicePolicyRepository(dio: ref.watch(dioClientProvider));
});

class BackendDevicePolicyRepository {
  BackendDevicePolicyRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// `blockUnknownSources` qiymatini oladi. Xato bo'lsa `null` — sync
  /// eski qiymatni saqlab qoladi (tarmoq uzilishida bloklash o'chmasin).
  Future<bool?> getBlockUnknownSources(String childId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/device-policy',
      );
      return res.data?['blockUnknownSources'] as bool?;
    } on DioException catch (e) {
      debugPrint('BackendDevicePolicyRepository: $e');
      return null;
    }
  }
}
