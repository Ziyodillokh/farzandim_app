// ─────────────────────────────────────────────────────────────────────
// school_early_exit_providers — erta ketish so'rovlari (ota-ona)
// ─────────────────────────────────────────────────────────────────────
//
// Ro'yxat (≤ 50, yangisi oldin; maktab xodimi kiritganlari ham) va yangi
// so'rov. So'rov har doim BUGUN uchun — sanani server qo'yadi. Bir
// o'quvchiga kunida bitta kutilayotgan so'rov (aks holda 409).
// WS event yo'q: push (`school_early_exit`), resume va pull-to-refresh.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/data/school_repository.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/shared/models/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Erta ketish so'rovlarim (login'ga bog'langan; ekran yopilsa tozalanadi).
final schoolEarlyExitsProvider =
    FutureProvider.autoDispose<List<EarlyExitRequest>>((ref) async {
      // Hisobdan chiqilganda boshqa hisobga eski ro'yxat o'tmaydi.
      final signedIn = ref.watch(schoolSignedInProvider);
      if (signedIn == null) return untilSignInKnown();
      if (!signedIn) {
        throw const SchoolFailure(SchoolFailureKind.sessionExpired);
      }
      return ref.watch(schoolRepositoryProvider).fetchEarlyExits();
    });

/// Yangi erta ketish so'rovi. `Result` qaytaradi (xato — tarjima qilingan
/// xabar) va ro'yxatni yangilaydi.
class EarlyExitActionsNotifier extends StateNotifier<AsyncValue<void>> {
  EarlyExitActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  /// [time] — "HH:MM" (24 soat). 409 → "bugun kutilayotgan so'rov bor".
  Future<Result<EarlyExitRequest>> request({
    required String studentId,
    required String time,
    required String reason,
    required String pickupBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final created = await _ref
          .read(schoolRepositoryProvider)
          .requestEarlyExit(
            studentId: studentId,
            time: time,
            reason: reason,
            pickupBy: pickupBy,
          );
      if (mounted) state = const AsyncValue.data(null);
      _refreshIfAlive(schoolEarlyExitsProvider);
      return Result.success(created);
    } catch (e, st) {
      final failure = SchoolFailure.fromError(e);
      if (mounted) state = AsyncValue.error(failure, st);
      // Kutilayotgan so'rov bor (409) yoki o'quvchi endi bog'lanmagan
      // (404) — ro'yxatlar eskirgan.
      if (failure.shouldRefresh) {
        _refreshIfAlive(schoolEarlyExitsProvider);
        _ref.invalidate(schoolLinksProvider);
      }
      return Result.failure(failure.messageKey.tr());
    }
  }

  /// Faqat ochiq ekrandagi ro'yxat qayta so'raladi (yopilganini qayta
  /// yaratmaydi).
  void _refreshIfAlive(ProviderOrFamily provider) =>
      _ref.container.invalidate(provider);
}

final earlyExitActionsProvider =
    StateNotifierProvider<EarlyExitActionsNotifier, AsyncValue<void>>(
      EarlyExitActionsNotifier.new,
    );
