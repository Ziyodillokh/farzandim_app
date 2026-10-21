import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/utils/polling.dart';
import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/iq/data/iq_summary.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final iqRepositoryProvider = Provider<IqRepository>((ref) {
  return IqRepository(dio: ref.watch(dioClientProvider));
});

/// IQ xulosasi; bo'lim backend'da yo'q (404, kodsiz) — null, karta yashirinadi.
final iqSummaryProvider = FutureProvider.autoDispose.family<IqSummary?, String>(
  (ref, childId) async {
    keepAliveFor(ref, const Duration(minutes: 2));
    try {
      return await ref.watch(iqRepositoryProvider).fetchSummary(childId);
    } on SchoolFailure catch (failure) {
      if (failure.isUnavailable) return null;
      rethrow;
    }
  },
);

class IqRepository {
  IqRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<IqSummary> fetchSummary(String childId) =>
      guardSchoolCall('iqSummary', () async {
        final id = childId.trim();
        if (id.isEmpty) throw const SchoolFailure(SchoolFailureKind.validation);
        final res = await _dio.get<Object?>(
          '/children/${Uri.encodeComponent(id)}/iq/summary',
        );
        return IqSummary.fromJson(asJsonMap(res.data) ?? const {});
      });
}
