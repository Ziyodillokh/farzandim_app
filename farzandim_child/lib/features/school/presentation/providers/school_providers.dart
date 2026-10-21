// ─────────────────────────────────────────────────────────────────────
// Maktab providerlari
// ─────────────────────────────────────────────────────────────────────
//
// Manba — server (`ApiSchoolRepository`, `/api/child/school`). Barcha maktab
// UI'si `isSchoolLinkedProvider` bilan yashiriladi: bola maktabga
// bog'lanmagan yoki server bu funksiyani hali bilmaydi (404, kodsiz).
// Bolaga yangi test / so'rovnoma haqida push kelmaydi — ma'lumot ochilganda,
// ilovaga qaytganda va pastga tortib yangilanadi (`refreshSchool`).
//
// Hammasi ulangan bolaga bog'langan (`schoolAccountProvider`): boshqa bolaga
// qayta ulanganda oldingi bolaning maktabi, testlari va psixologga
// murojaatlari (yangisi yuklanayotganda ham) ko'rinmaydi. Ro'yxatlar ekran
// yopilganda xotiradan tashlanadi (`autoDispose`).

import 'dart:async';

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/account/presentation/providers/language_sync_provider.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/school/data/api_school_repository.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final schoolRepositoryProvider = Provider<SchoolRepository>(
  (ref) => ApiSchoolRepository(ref.watch(dioClientProvider)),
);

/// Server funksiyani hali bilmasa (`unavailable`) — [fallback], ya'ni
/// "bog'lanmagan" holat; boshqa xatolar provider holatida qoladi.
Future<T> _unlessUnavailable<T>(Future<T> Function() load, T fallback) async {
  try {
    return await load();
  } on SchoolException catch (e) {
    if (e.code == SchoolErrorCode.unavailable) return fallback;
    rethrow;
  }
}

/// Maktab ma'lumoti tegishli hisob — ulangan bolaning `childId`si
/// (`null` — ulanmagan: maktab UI'si yo'q, so'rov ham yo'q).
final schoolAccountProvider = Provider<String?>(
  (ref) => ref.watch(
    pairingStateProvider.select((s) => s.isPaired ? s.childId : null),
  ),
);

/// Bugungi maktab holati (`null` — bog'lanmagan yoki funksiya hali yo'q).
final schoolTodayProvider =
    AsyncNotifierProvider<SchoolTodayNotifier, SchoolToday?>(
      SchoolTodayNotifier.new,
    );

class SchoolTodayNotifier extends AsyncNotifier<SchoolToday?> {
  /// Joriy holat qaysi hisobniki (oxirgi build).
  String? _account;

  @override
  FutureOr<SchoolToday?> build() {
    final account = ref.watch(schoolAccountProvider);
    final previous = _account;
    _account = account;
    if (account == null) return null;
    // Boshqa bolaga o'tildi, oldingisining holati hali turibdi: Riverpod uni
    // yangisi yuklanayotganda ham ko'rsatardi. Avval bo'sh holat (darhol),
    // so'ng shu bolaniki yuklanadi.
    if (previous != null && previous != account && state.valueOrNull != null) {
      _reloadSoon();
      return null;
    }
    return _unlessUnavailable(
      ref.watch(schoolRepositoryProvider).loadToday,
      null,
    );
  }

  /// Bo'sh holat o'rnatilgach (keyingi microtask) shu bolaniki yuklanadi —
  /// oraliqda provider qayta qurilsa yoki yopilsa, kerak emas.
  void _reloadSoon() {
    var isStale = false;
    ref.onDispose(() => isStale = true);
    scheduleMicrotask(() {
      if (!isStale) ref.invalidateSelf();
    });
  }

  /// Kiosk QR bilan kirish / chiqish — javobdagi bugungi holat darhol
  /// ko'rinadi (qayta yuklashsiz). Xato `SchoolException` bo'lib qaytadi.
  Future<CheckInResult> checkIn(String token) async {
    final result = await ref.read(schoolRepositoryProvider).checkIn(token);
    final today = result.today;
    if (today == null) return result;
    // Skanerlashdan oldin boshlangan yuklash eski holatni qaytaradi va uni
    // bosib ketardi — o'sha so'rov bekor qilinib, qayta so'raladi.
    final hadPendingLoad = state.isLoading;
    state = AsyncData(today);
    if (hadPendingLoad) ref.invalidateSelf();
    return result;
  }
}

/// Bola maktabga bog'langan — maktab UI'si faqat shunda ko'rinadi.
/// Yangilanayotganda / tarmoq xatosida oxirgi ma'lum holat saqlanadi.
final isSchoolLinkedProvider = Provider<bool>(
  (ref) => ref.watch(schoolTodayProvider).valueOrNull != null,
);

/// Ochiq psixologik testlar (bog'lanmagan bo'lsa so'rovsiz bo'sh). Matni
/// bola tilida — til serverga yozilgach qayta yuklanadi.
final psychAssignmentsProvider =
    FutureProvider.autoDispose<List<PsychAssignmentSummary>>((ref) {
      if (!ref.watch(isSchoolLinkedProvider)) return const [];
      ref.watch(syncedLanguageRevisionProvider);
      return _unlessUnavailable(
        ref.watch(schoolRepositoryProvider).loadPsychAssignments,
        const [],
      );
    });

/// Yechish uchun test (savollar). Sahifa yopilganda tashlanadi — savollar
/// va javoblar xotirada qolmaydi; xato (409, 404) sahifada ko'rsatiladi.
final psychTestProvider = FutureProvider.autoDispose.family<PsychTest, String>(
  (ref, assignmentId) =>
      ref.read(schoolRepositoryProvider).loadPsychTest(assignmentId),
);

/// "Bola ovozi" so'rovnomasi holati (savollar bola tilida — til serverga
/// yozilgach qayta yuklanadi).
final careSurveyProvider = FutureProvider.autoDispose<CareSurveyStatus>((ref) {
  if (!ref.watch(isSchoolLinkedProvider)) return CareSurveyStatus.notEnrolled;
  ref.watch(syncedLanguageRevisionProvider);
  return _unlessUnavailable(
    ref.watch(schoolRepositoryProvider).loadCareSurvey,
    CareSurveyStatus.notEnrolled,
  );
});

/// Psixologga murojaatlar — yangisi birinchi.
final careRequestsProvider = FutureProvider.autoDispose<List<CareRequest>>((
  ref,
) {
  if (!ref.watch(isSchoolLinkedProvider)) return const [];
  return _unlessUnavailable(
    ref.watch(schoolRepositoryProvider).loadCareRequests,
    const [],
  );
});

/// Maktab topshiriqlari (muddati bo'yicha).
final schoolAssignmentsProvider =
    FutureProvider.autoDispose<List<SchoolAssignment>>((ref) {
      if (!ref.watch(isSchoolLinkedProvider)) return const [];
      return _unlessUnavailable(
        ref.watch(schoolRepositoryProvider).loadAssignments,
        const [],
      );
    });

/// Maktab bergan, hali yechilmagan test fanlari — "Bugungi testlar"
/// plitkalarida belgi (yuklanmagan / xato bo'lsa bo'sh).
final schoolTestSubjectsProvider = Provider.autoDispose<Set<Subject>>(
  (ref) => pendingTestSubjects(
    ref.watch(schoolAssignmentsProvider).valueOrNull ?? const [],
  ),
);

/// Pastga tortib yangilash / ilovaga qaytish: maktab ma'lumotlari serverdan
/// qayta yuklanadi. Kuzatilayotgan ro'yxatlar o'zi yangilanadi, qolganlari —
/// keyingi ochilishda. Tarmoq xatosi indikatorni to'xtatmaydi.
Future<void> refreshSchool(WidgetRef ref) async {
  ref
    ..invalidate(schoolTodayProvider)
    ..invalidate(psychAssignmentsProvider)
    ..invalidate(careSurveyProvider)
    ..invalidate(careRequestsProvider)
    ..invalidate(schoolAssignmentsProvider);
  try {
    await ref.read(schoolTodayProvider.future);
  } on SchoolException {
    // Oflayn — kartalar avvalgi holatda qoladi.
  }
}
