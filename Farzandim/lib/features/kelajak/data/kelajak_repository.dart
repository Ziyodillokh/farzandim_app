// ─────────────────────────────────────────────────────────────────────
// KelajakRepository — Kelajak (qiziqish va kelajak) xulosasi, ota-ona API
// ─────────────────────────────────────────────────────────────────────
//
// Endpoint: GET /api/children/:childId/kelajak/summary (PARENT tokeni,
// bola egasi). Xatolar Growth va maktab bo'limi bilan bir xil
// `SchoolFailure`ga aylanadi: 404 `code`siz (bola topilmadi yoki
// backend'da Kelajak hali yo'q) → `unavailable` — UI bo'limni yashiradi;
// begona bola → 403 `forbidden`.

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_summary.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final kelajakRepositoryProvider = Provider<KelajakRepository>((ref) {
  return KelajakRepository(dio: ref.watch(dioClientProvider));
});

class KelajakRepository {
  KelajakRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Bolaning xulosasi: qiziqishlar, kuchli tomonlar, Career Lab,
  /// qo'llab-quvvatlash signali va progress.
  Future<KelajakSummary> fetchSummary(String childId) =>
      guardSchoolCall('kelajakSummary', () async {
        final res = await _dio.get<Object?>('${_base(childId)}/summary');
        return KelajakSummary.fromJson(asJsonMap(res.data) ?? const {});
      });

  /// `/children/:childId/kelajak`; bo'sh id 404 berib bo'lim noto'g'ri
  /// yashirilmasin — oldindan rad etiladi.
  static String _base(String childId) {
    final id = childId.trim();
    if (id.isEmpty) throw const SchoolFailure(SchoolFailureKind.validation);
    return '/children/${Uri.encodeComponent(id)}/kelajak';
  }
}
