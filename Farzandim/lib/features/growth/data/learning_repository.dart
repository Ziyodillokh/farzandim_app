// ─────────────────────────────────────────────────────────────────────
// LearningRepository — Growth (kunlik testlar), ota-ona API
// ─────────────────────────────────────────────────────────────────────
//
// Endpoint'lar (`/api/children/:childId/learning`, PARENT tokeni):
//   GET summary?days=7|30 · GET results?limit=&before=&subject= ·
//   GET profile · PUT profile
//
// Backend noma'lum query parametrini rad etadi (forbidNonWhitelisted) —
// faqat shu parametrlar yuboriladi. Xatolar maktab bo'limi bilan bir xil
// `SchoolFailure`ga aylanadi: 404 `code`siz (bola topilmadi yoki backend'da
// Growth hali yo'q) → `unavailable` — UI bo'limni yashiradi.
//
// Mavjud `/children/:id/development-summary` olimpiada urinishlarini
// sanaydi, Growth testlarini EMAS.

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/growth/data/models/learning_profile.dart';
import 'package:farzandim/features/growth/data/models/learning_result.dart';
import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:farzandim/features/growth/data/models/learning_summary.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final learningRepositoryProvider = Provider<LearningRepository>((ref) {
  return LearningRepository(dio: ref.watch(dioClientProvider));
});

class LearningRepository {
  LearningRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// 7 yoki 30 kunlik xulosa.
  Future<LearningSummary> fetchSummary(String childId, {int days = 7}) =>
      guardSchoolCall('learningSummary', () async {
        if (!kGrowthPeriods.contains(days)) {
          throw const SchoolFailure(SchoolFailureKind.validation);
        }
        final res = await _dio.get<Object?>(
          '${_base(childId)}/summary',
          queryParameters: {'days': days},
        );
        return LearningSummary.fromJson(asJsonMap(res.data) ?? const {});
      });

  /// Natijalar (yangisi oldin). Keyingi sahifa: [before] = `nextBefore`.
  Future<LearningResultsPage> fetchResults(
    String childId, {
    int limit = kLearningResultsPageSize,
    String? before,
    LearningSubject? subject,
  }) => guardSchoolCall('learningResults', () async {
    if (subject == LearningSubject.unknown) {
      throw const SchoolFailure(SchoolFailureKind.validation);
    }
    final res = await _dio.get<Object?>(
      '${_base(childId)}/results',
      queryParameters: {
        'limit': limit.clamp(1, kMaxLearningResultsPageSize),
        if (before != null && before.isNotEmpty) 'before': before,
        if (subject != null) 'subject': subject.name,
      },
    );
    return LearningResultsPage.fromJson(asJsonMap(res.data) ?? const {});
  });

  /// Bolaning profili; hali tanlanmagan → `null`.
  Future<LearningProfile?> fetchProfile(String childId) =>
      guardSchoolCall('learningProfile', () async {
        final res = await _dio.get<Object?>('${_base(childId)}/profile');
        return LearningProfile.tryParse(asJsonMap(res.data)?['profile']);
      });

  /// Sinf va fanlarni saqlash (qoidalar so'rovdan oldin tekshiriladi).
  Future<LearningProfile> saveProfile(
    String childId,
    LearningProfile profile,
  ) => guardSchoolCall('saveLearningProfile', () async {
    if (!profile.isValid) {
      throw const SchoolFailure(SchoolFailureKind.validation);
    }
    final res = await _dio.put<Object?>(
      '${_base(childId)}/profile',
      data: profile.toJson(),
    );
    return LearningProfile.tryParse(asJsonMap(res.data)?['profile']) ?? profile;
  });

  /// `/children/:childId/learning`; bo'sh id 404 berib bo'lim noto'g'ri
  /// yashirilmasin — oldindan rad etiladi.
  static String _base(String childId) {
    final id = childId.trim();
    if (id.isEmpty) throw const SchoolFailure(SchoolFailureKind.validation);
    return '/children/${Uri.encodeComponent(id)}/learning';
  }
}
