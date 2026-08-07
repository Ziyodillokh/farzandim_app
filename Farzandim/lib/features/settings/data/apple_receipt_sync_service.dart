// AppleReceiptSyncService — iOS obuna RENEWAL/bekor qilinishini "poll"
// qiladigan fon servisi.
//
// SABAB: backend Apple IAP'ni legacy `verifyReceipt` API bilan tekshiradi
// (App Store Server Notifications webhook YO'Q — bu ataylab tanlangan
// yechim, qarang apple-iap.service.ts izohi). Ya'ni Apple obunani
// avtomatik yangilaganda (har oy/yil pul yechilganda) backend buni
// PROAKTIV bilmaydi — faqat foydalanuvchi keyingi safar xarid/restore
// qilganda bilib qoladi.
//
// YECHIM: iOS'ning LOKAL App Store kvitansiyasi — bu fayl iOS tomonidan
// AVTOMATIK yangilanadi har safar renewal/refund/cancel bo'lganda (StoreKit
// buni operatsion tizim darajasida qiladi, ilova kodisiz). Shu sabab uni
// ilova FOREGROUND'GA qaytganda (resume) va sovuq ishga tushishda qayta
// o'qib, backend'ga jim yuborish — App Store Server API/webhook'siz ham
// renewal/expiry holatini backend bilan sinxronlashtiradi.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:farzandim/features/settings/data/entitlement.dart';
import 'package:farzandim/features/settings/data/repositories/backend_payments_repository.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

class AppleReceiptSyncService {
  AppleReceiptSyncService(this._ref);

  final Ref _ref;
  AppLifecycleListener? _listener;
  bool _syncing = false;

  bool get _isApple => !kIsWeb && Platform.isIOS;

  /// Ilova umrining boshida BIR MARTA chaqiriladi (`app.dart` orqali,
  /// [appleReceiptSyncServiceProvider] watch qilinganda).
  void start() {
    if (!_isApple) return;
    _listener = AppLifecycleListener(onResume: _sync);
    // Sovuq ishga tushishda ham darhol — foydalanuvchi "Tariflar" ekranini
    // umuman ochmasa ham renewal/expiry backend'da aks etsin.
    unawaited(_sync());
  }

  void dispose() {
    _listener?.dispose();
    _listener = null;
  }

  /// Lokal kvitansiyani o'qib backend'ga yuboradi. `productId` bermaymiz —
  /// backend kvitansiya ichidan eng so'nggi (aktiv) mos yozuvni o'zi
  /// aniqlaydi (apple-iap.service.ts: candidates/resolvedProductId).
  Future<void> _sync() async {
    // Bir vaqtning o'zida bir nechta chaqiruv (masalan tez-tez resume)
    // qatorlashmasin — busiz backend'ga ortiqcha so'rov ketishi mumkin.
    if (_syncing) return;
    _syncing = true;
    try {
      final addition = InAppPurchase.instance
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      final data = await addition.refreshPurchaseVerificationData();
      // `null` — hech qachon Apple orqali xarid qilinmagan (yangi
      // o'rnatilgan ilova) yoki kvitansiya hali yo'q. Bu XATO EMAS.
      if (data == null) return;
      final ok = await _ref
          .read(backendPaymentsRepositoryProvider)
          .verifyApplePurchase(verificationData: data.serverVerificationData);
      if (ok) {
        _ref.invalidate(entitlementProvider);
      }
    } catch (e) {
      // Jim — bu FON tekshiruvi, foydalanuvchiga xato ko'rsatilmaydi
      // (tarmoq yo'q bo'lishi mumkin). Keyingi resume'da qayta uriniladi.
      debugPrint('AppleReceiptSyncService._sync xato: $e');
    } finally {
      _syncing = false;
    }
  }
}

/// [AppleReceiptSyncService] — ilova umri davomida BITTA nusxa (default
/// keepAlive, `autoDispose` EMAS) — `app.dart` root darajada watch qilib
/// ishga tushiradi, faqat "Tariflar" ekrani ochiq bo'lgandagina EMAS.
final appleReceiptSyncServiceProvider = Provider<AppleReceiptSyncService>((
  ref,
) {
  final service = AppleReceiptSyncService(ref)..start();
  ref.onDispose(service.dispose);
  return service;
});
