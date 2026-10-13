// ─────────────────────────────────────────────────────────────────────
// AccountDeletion — "Ulanishni uzish va ma'lumotlarni o'chirish" oqimi
// ─────────────────────────────────────────────────────────────────────
//
// App Store 5.1.1(v): ulanish paytida avtomatik yaratilgan bola hisobini
// ilova ichidan o'chirish imkoni bo'lishi shart. Tartib:
//   1. DELETE /users/me — server bola hisobini va ma'lumotlarini o'chiradi,
//      ota-onadagi bola profilini qayta ulash mumkin holatga qaytaradi.
//      Xato bo'lsa — lokal hech narsa o'zgarmaydi, UI xabar ko'rsatadi.
//   2. Anonim Firebase foydalanuvchisi o'chiriladi (best-effort).
//   3. Lokal uzish (servislar, Ekran vaqti cheklovlari, PIN, prefs).
//   4. Tokenlar va ota-ona roziligi tozalanadi — router bolani boshlang'ich
//      (rozilik → ulanish) ekraniga qaytaradi.

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/features/account/presentation/providers/child_repository_provider.dart';
import 'package:farzandim_child/features/consent/presentation/providers/consent_provider.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase o'chirishini kutish chegarasi — tarmoq sekin bo'lsa ham
/// lokal tozalash cheksiz kutib qolmasin.
const _firebaseDeleteTimeout = Duration(seconds: 5);

final accountDeletionProvider = Provider<AccountDeletion>(AccountDeletion.new);

class AccountDeletion {
  AccountDeletion(this._ref);

  final Ref _ref;

  /// Server o'chirishi muvaffaqiyatsiz bo'lsa istisno tashlaydi va lokal
  /// holatga tegmaydi. Muvaffaqiyatli bo'lsa qurilma to'liq uziladi.
  Future<void> deleteAndDisconnect() async {
    await _ref.read(childRepositoryProvider).deleteMyAccount();

    await _bestEffort(
      'Firebase user',
      () => _ref
          .read(authRepositoryProvider)
          .deleteCurrentUser()
          .timeout(_firebaseDeleteTimeout),
    );

    final pairing = _ref.read(pairingStateProvider.notifier);
    try {
      await pairing.unpair();
    } finally {
      await _bestEffort(
        'tokens',
        () => _ref.read(tokenStorageProvider).clear(),
      );
      await _ref.read(consentStateProvider.notifier).reset();
      // Hisob o'chirildi — "sessiya tugadi" xabari kerak emas (fon so'rovi
      // 401 olib, signal bergan bo'lishi mumkin).
      pairing.clearSessionEndedNotice();
    }
  }

  Future<void> _bestEffort(String name, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('[AccountDeletion] $name tozalanmadi: $e');
    }
  }
}
