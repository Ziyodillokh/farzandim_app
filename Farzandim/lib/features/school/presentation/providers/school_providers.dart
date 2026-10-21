// ─────────────────────────────────────────────────────────────────────
// school_providers — maktab bog'lanishi va o'quvchi ↔ farzand moslash
// ─────────────────────────────────────────────────────────────────────
//
// WS event yo'q: ro'yxat push, resume va pull-to-refresh'da
// `ref.invalidate(schoolLinksProvider)` bilan yangilanadi.
//
// Backend'da bo'lim bo'lmasa (404, `code`siz) ro'yxat
// `SchoolLinks.unavailable` bo'ladi va maktab UI'si (sozlamalar qatori,
// dashboard kartasi) yashiriladi. Diskka keshlanmaydi (logolar katta).

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/data/school_repository.dart';
import 'package:farzandim/shared/models/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kirgan (`true`), kirmagan (`false`) yoki hali aniqlanmagan (`null` —
/// sovuq startda saqlangan sessiya o'qilmoqda). Faqat shu o'zgarganda qayta
/// hisoblanadi — user obyekti yangilanishi maktab so'rovini qayta
/// yubormaydi. Testlarda override.
final schoolSignedInProvider = Provider<bool?>((ref) {
  return ref.watch(
    backendAuthProvider.select(
      (s) => switch (s) {
        AuthUnknown() => null,
        AuthAuthenticated() => true,
        AuthAnonymous() || AuthError() => false,
      },
    ),
  );
});

/// Kirish holati hali aniqlanmagan: provider yuklanish holatida qoladi va
/// holat aniqlangach ([schoolSignedInProvider] o'zgaradi) qayta quriladi.
/// Push'dan sovuq startda "mavjud emas" / "sessiya tugadi" chiqmaydi va
/// push'dagi amal (masalan, School Mode yo'l-yo'rig'i) yo'qolmaydi.
Future<T> untilSignInKnown<T>() => Completer<T>().future;

/// Maktab bog'lanishlari (login'ga bog'langan). Bo'lim yo'q yoki
/// kirilmagan → `SchoolLinks.unavailable`; boshqa xato → `SchoolFailure`.
final schoolLinksProvider = FutureProvider<SchoolLinks>((ref) async {
  final signedIn = ref.watch(schoolSignedInProvider);
  if (signedIn == null) return untilSignInKnown();
  if (!signedIn) return SchoolLinks.unavailable;
  final repo = ref.watch(schoolRepositoryProvider);
  try {
    return await repo.fetchLinks();
  } on SchoolFailure catch (failure) {
    if (failure.isUnavailable) return SchoolLinks.unavailable;
    rethrow;
  }
});

/// Maktab UI'sini ko'rsatish mumkinmi: ro'yxat yuklangan VA backend'da
/// bo'lim bor. Yuklanayotganda va xatoda `false`; yangilash paytida oldingi
/// qiymat saqlanadi (miltillamaydi).
final schoolAvailableProvider = Provider<bool>((ref) {
  return ref.watch(
    schoolLinksProvider.select(
      (links) => links.valueOrNull?.available ?? false,
    ),
  );
});

/// Shu farzandga (`childId`) moslangan o'quvchi; yo'q → `null`.
final studentForChildProvider = Provider.family<LinkedStudent?, String>((
  ref,
  childId,
) {
  return ref.watch(
    schoolLinksProvider.select(
      (links) => links.valueOrNull?.studentForChild(childId),
    ),
  );
});

/// Hali hech kimga moslanmagan o'quvchilar (moslash varag'i uchun).
final unmatchedStudentsProvider = Provider<List<LinkedStudent>>((ref) {
  return ref.watch(schoolLinksProvider).valueOrNull?.unmatchedStudents ??
      const <LinkedStudent>[];
});

/// Bog'lanish amallari: kod kiritish, moslash, aloqani uzish. Har biri
/// `Result` qaytaradi (xato — tarjima qilingan xabar) va muvaffaqiyatda
/// ro'yxatni yangilaydi.
class SchoolActionsNotifier extends StateNotifier<AsyncValue<void>> {
  SchoolActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  SchoolRepository get _repo => _ref.read(schoolRepositoryProvider);

  /// Taklif kodini kiritish ("abcd-2345" ham bo'ladi).
  Future<Result<SchoolLinks>> redeem(String rawCode) =>
      _run(() => _repo.redeemInvite(rawCode));

  /// O'quvchini farzand bilan moslash (`childId: null` — moslashni olish).
  Future<Result<SchoolLinks>> setChild({
    required String studentId,
    required String? childId,
  }) =>
      _run(() => _repo.setStudentChild(studentId: studentId, childId: childId));

  /// Maktab bilan aloqani uzish.
  Future<Result<void>> unlink(String guardianId) =>
      _run(() => _repo.unlink(guardianId));

  Future<Result<T>> _run<T>(Future<T> Function() action) async {
    state = const AsyncValue.loading();
    try {
      final data = await action();
      state = const AsyncValue.data(null);
      _ref.invalidate(schoolLinksProvider);
      return Result.success(data);
    } catch (e, st) {
      final failure = SchoolFailure.fromError(e);
      state = AsyncValue.error(failure, st);
      // Eskirgan ro'yxat (o'quvchi/aloqa yo'q, boshqa oila moslagan,
      // bo'lim olib tashlangan) qayta yuklanadi. Tarmoq xatosida EMAS —
      // aks holda ekran butunlay xato holatiga o'tib qolardi.
      if (failure.shouldRefresh) _ref.invalidate(schoolLinksProvider);
      return Result.failure(failure.messageKey.tr());
    }
  }
}

final schoolActionsProvider =
    StateNotifierProvider<SchoolActionsNotifier, AsyncValue<void>>(
      SchoolActionsNotifier.new,
    );
