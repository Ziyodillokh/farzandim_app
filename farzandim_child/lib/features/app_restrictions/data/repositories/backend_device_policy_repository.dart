// ─────────────────────────────────────────────────────────────────────
// BackendDevicePolicyRepository — qurilma siyosati (Child o'qiydi)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   GET /api/children/:childId/device-policy
//     → { blockUnknownSources, blockAllApps }
//
// Ota-ona "Notanish manbalardan ilovalar" yoki "Barcha ilovalarni bloklash"
// toggle'ini yoqsa, bola qurilmasi shu siyosatni o'qib enforce qiladi:
//   blockUnknownSources → Play'dan boshqa manbadagi ilovalar bloklanadi
//   blockAllApps        → barcha foreground ilovalar bloklanadi ('*' wildcard)

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

  /// Qurilma siyosatini BITTA so'rovda oladi: `blockUnknownSources`,
  /// `blockAllApps`, `blockUninstall`. Xato bo'lsa maydonlar `null` — sync
  /// eski qiymatni saqlaydi (tarmoq uzilishida bloklash o'chib qolmasin).
  Future<
    ({bool? blockUnknownSources, bool? blockAllApps, bool? blockUninstall})
  >
  getDevicePolicy(String childId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/device-policy',
      );
      return (
        blockUnknownSources: res.data?['blockUnknownSources'] as bool?,
        blockAllApps: res.data?['blockAllApps'] as bool?,
        blockUninstall: res.data?['blockUninstall'] as bool?,
      );
    } on DioException catch (e) {
      debugPrint('BackendDevicePolicyRepository: $e');
      return (
        blockUnknownSources: null,
        blockAllApps: null,
        blockUninstall: null,
      );
    }
  }

  /// Bola "O'chirishni taqiqlash" (Device Admin)ni o'chirganini backend'ga
  /// xabar qiladi → ota-onaga push (Play-mos deterrent). Xato yutiladi.
  Future<void> reportUninstallGuardDisabled(String childId) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/children/$childId/uninstall-guard-disabled',
      );
    } on DioException catch (e) {
      debugPrint('reportUninstallGuardDisabled: $e');
    }
  }
}
