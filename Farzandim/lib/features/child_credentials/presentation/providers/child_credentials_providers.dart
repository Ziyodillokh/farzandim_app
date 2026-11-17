// ─────────────────────────────────────────────────────────────────────
// child_credentials_providers — kirish ma'lumotlari holati va amallari
// ─────────────────────────────────────────────────────────────────────
//
// Holat (login, kim bergan, birinchi kirish, oxirgi kirish) va ochiq
// "parolni unutdim" so'rovlari — ekran ochiq turganda tirik (`autoDispose`).
// Vaqtinchalik parol bu yerda SAQLANMAYDI: `issue`/`reset` uni faqat
// natijada qaytaradi, ekran uni ochiq "parol varag'i"ga beradi.

import 'package:farzandim/features/child_credentials/data/child_credentials_repository.dart';
import 'package:farzandim/features/child_credentials/data/credentials_failure.dart';
import 'package:farzandim/features/child_credentials/data/models/child_credentials.dart';
import 'package:farzandim/features/child_credentials/data/models/issued_credentials.dart';
import 'package:farzandim/features/child_credentials/data/models/recovery_request.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Bolaning kirish ma'lumotlari; hali berilmagan → `null`. Xato →
/// [CredentialsFailure] (ekran tarjima qilingan xabar va "Qayta urinish"
/// ko'rsatadi).
final childCredentialsProvider = FutureProvider.autoDispose
    .family<ChildCredentials?, String>(
      (ref, childId) => ref
          .watch(childCredentialsRepositoryProvider)
          .fetchCredentials(childId),
    );

/// Hal bo'lmagan "parolni unutdim" so'rovlari (yangisi birinchi). Yopilgan
/// (tiklangan/rad etilgan) so'rovlar server bergan taqdirda ham chiqmaydi.
final childRecoveryRequestsProvider = FutureProvider.autoDispose
    .family<List<RecoveryRequest>, String>((ref, childId) async {
      final all = await ref
          .watch(childCredentialsRepositoryProvider)
          .fetchRecoveryRequests(childId);
      return List.unmodifiable(all.where((request) => request.isOpen));
    });

/// Amal natijasi: muvaffaqiyat ([data]) yoki tipli xato ([failure]).
@immutable
class CredentialsResult<T> {
  const CredentialsResult.success([this.data]) : failure = null;

  const CredentialsResult.failure(CredentialsFailure this.failure)
    : data = null;

  final T? data;
  final CredentialsFailure? failure;

  bool get isSuccess => failure == null;
}

/// Kirish ma'lumotlari amallari: berish, yangilash, so'rovni rad etish.
/// Muvaffaqiyatda ekrandagi holat va so'rovlar ro'yxati qayta o'qiladi.
class ChildCredentialsActions {
  ChildCredentialsActions(this._ref);

  final Ref _ref;

  ChildCredentialsRepository get _repo =>
      _ref.read(childCredentialsRepositoryProvider);

  /// Birinchi marta login va parol berish ([login] ixtiyoriy).
  Future<CredentialsResult<IssuedCredentials>> issue(
    String childId, {
    String? login,
  }) => _run(childId, () => _repo.issueCredentials(childId, login: login));

  /// Yangi vaqtinchalik parol. [signOutDevices] yoqilgan bo'lsa, bolaning
  /// ulangan telefoni ham tizimdan chiqadi — bolalar ro'yxati tezroq
  /// yangilanadi (ulanish holati o'zgaradi).
  Future<CredentialsResult<IssuedCredentials>> reset(
    String childId, {
    required bool signOutDevices,
  }) async {
    final result = await _run(
      childId,
      () => _repo.resetCredentials(childId, signOutDevices: signOutDevices),
    );
    if (result.isSuccess && signOutDevices) {
      _ref.read(childrenRefreshTickProvider.notifier).state++;
    }
    return result;
  }

  /// "Parolni unutdim" so'rovini rad etish. Xatodan keyin (tarmoqdan
  /// tashqari) ro'yxat qayta o'qiladi — so'rov allaqachon hal bo'lgan
  /// bo'lishi mumkin.
  Future<CredentialsResult<void>> rejectRecovery(
    String childId,
    String requestId,
  ) async {
    final result = await _run(
      childId,
      () => _repo.rejectRecoveryRequest(childId, requestId),
    );
    final failure = result.failure;
    if (failure != null && failure.kind != CredentialsFailureKind.network) {
      _ref.invalidate(childRecoveryRequestsProvider(childId));
    }
    return result;
  }

  /// So'rovni bajaradi. `try` ichida FAQAT so'rovning o'zi: muvaffaqiyatdan
  /// keyingi yangilash nima bo'lsa ham vaqtinchalik parolni yo'qotmasligi
  /// kerak. Faqat `Exception` ushlanadi — dastur xatosi (`Error`) yashirilmaydi
  /// (chaqiruvchi varaq uni ushlab, qotib qolmaydi).
  Future<CredentialsResult<T>> _run<T>(
    String childId,
    Future<T> Function() action,
  ) async {
    final T data;
    try {
      data = await action();
    } on Exception catch (error) {
      final failure = CredentialsFailure.fromError(error);
      if (_mayHaveChanged(failure)) {
        _ref.invalidate(childCredentialsProvider(childId));
      }
      return CredentialsResult.failure(failure);
    }
    _refreshAfterSuccess(childId);
    return CredentialsResult.success(data);
  }

  /// Yaroqsiz yoki band login (400/409) — serverda hech narsa o'zgarmagan.
  /// Boshqa xatodan keyin (tarmoq uzilishi, 5xx, boshqa qurilma allaqachon
  /// login bergan...) so'rov bajarilgan bo'lishi mumkin: ekran holatni qayta
  /// o'qiydi.
  static bool _mayHaveChanged(CredentialsFailure failure) =>
      switch (failure.kind) {
        CredentialsFailureKind.validation ||
        CredentialsFailureKind.loginTaken => false,
        _ => true,
      };

  /// Muvaffaqiyatdan keyin ekran holati va so'rovlar ro'yxati qayta o'qiladi.
  /// Bu qadam xato bersa ham natija (parol) qaytadi — u BIR MARTA beriladi.
  void _refreshAfterSuccess(String childId) {
    try {
      _ref
        ..invalidate(childCredentialsProvider(childId))
        ..invalidate(childRecoveryRequestsProvider(childId));
    } on Object catch (error) {
      debugPrint('[credentials] refresh: ${error.runtimeType}');
    }
  }
}

final childCredentialsActionsProvider = Provider<ChildCredentialsActions>(
  ChildCredentialsActions.new,
);

/// Matnni tizimning "Ulashish" oynasi orqali yuboradi. `true` — foydalanuvchi
/// biror ilovani tanladi; oyna yopilsa yoki natija noma'lum bo'lsa — `false`
/// (parol yuborilgan deb hisoblanmaydi). Provayder sifatida beriladi —
/// testlarda platforma kanalisiz almashtiriladi.
typedef ShareText = Future<bool> Function(String text, {String? subject});

final shareTextProvider = Provider<ShareText>(
  (ref) => (text, {subject}) async {
    final result = await Share.share(text, subject: subject);
    return result.status == ShareResultStatus.success;
  },
);

/// Bolaning "parolni unutdim" push'i kelganda (ilova ochiq) shu bolaning
/// "Kirish ma'lumotlari" ekranidagi so'rovlar ro'yxati qayta o'qiladi.
/// Ekran yopiq bo'lsa — hech narsa qilinmaydi (`invalidate` faqat tirik
/// provayderga ta'sir qiladi). [invalidate] — `ref.invalidate`.
void refreshForCredentialsPush(
  AppNotification notification,
  void Function(ProviderOrFamily provider) invalidate,
) {
  if (notification.type != NotificationType.childRecoveryRequest) return;
  final childId = notification.childId.trim();
  if (childId.isEmpty) return;
  invalidate(childRecoveryRequestsProvider(childId));
}
