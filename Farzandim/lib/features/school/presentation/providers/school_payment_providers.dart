// ─────────────────────────────────────────────────────────────────────
// school_payment_providers — to'lov eslatmalari va tekshiruv so'rovlari
// ─────────────────────────────────────────────────────────────────────
//
// Eslatmalar ataylab summasiz: faqat maktab tasdiqlagan keyingi sana,
// oldindan to'langan oylar, to'xtatilganligi va farzandlar. Ota-ona
// "To'laganman, tekshiring" so'rovini yuboradi (bitta eslatmada bitta
// ochiq so'rov — aks holda 409); maktab javobi so'rovlar tarixida.
// WS event yo'q: push, resume va pull-to-refresh.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/data/school_repository.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/shared/models/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// To'lov eslatmalari (login'ga bog'langan; ekran yopilsa tozalanadi).
final schoolPaymentsProvider =
    FutureProvider.autoDispose<List<SchoolPaymentReminder>>((ref) async {
      final signedIn = ref.watch(schoolSignedInProvider);
      if (signedIn == null) return untilSignInKnown();
      if (!signedIn) {
        throw const SchoolFailure(SchoolFailureKind.sessionExpired);
      }
      return ref.watch(schoolRepositoryProvider).fetchPayments();
    });

/// "To'laganman, tekshiring" so'rovlarim va maktab javoblari.
final schoolVerificationsProvider =
    FutureProvider.autoDispose<List<PaymentVerification>>((ref) async {
      final signedIn = ref.watch(schoolSignedInProvider);
      if (signedIn == null) return untilSignInKnown();
      if (!signedIn) {
        throw const SchoolFailure(SchoolFailureKind.sessionExpired);
      }
      return ref.watch(schoolRepositoryProvider).fetchVerifications();
    });

/// To'lov amallari. `Result` qaytaradi (xato — tarjima qilingan xabar).
class PaymentActionsNotifier extends StateNotifier<AsyncValue<void>> {
  PaymentActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  /// Tekshiruv so'rovi (xabar ≤ 500). Muvaffaqiyatda va eskirgan holatda
  /// (409 — ochiq so'rov bor, 404 — eslatma yo'q) ikkala ro'yxat
  /// yangilanadi: tugma "ko'rib chiqilmoqda" holatiga o'tadi.
  Future<Result<PaymentVerification>> requestVerification({
    required String paymentReminderId,
    required String message,
  }) async {
    state = const AsyncValue.loading();
    try {
      final created = await _ref
          .read(schoolRepositoryProvider)
          .createVerification(
            paymentReminderId: paymentReminderId,
            message: message,
          );
      if (mounted) state = const AsyncValue.data(null);
      _refreshLists();
      return Result.success(created);
    } catch (e, st) {
      final failure = SchoolFailure.fromError(e);
      if (mounted) state = AsyncValue.error(failure, st);
      if (failure.shouldRefresh) _refreshLists();
      return Result.failure(failure.messageKey.tr());
    }
  }

  /// Faqat ochiq ekrandagi ro'yxatlar qayta so'raladi (yopilganlarni
  /// qayta yaratmaydi).
  void _refreshLists() {
    _ref.container
      ..invalidate(schoolPaymentsProvider)
      ..invalidate(schoolVerificationsProvider);
  }
}

final paymentActionsProvider =
    StateNotifierProvider<PaymentActionsNotifier, AsyncValue<void>>(
      PaymentActionsNotifier.new,
    );
