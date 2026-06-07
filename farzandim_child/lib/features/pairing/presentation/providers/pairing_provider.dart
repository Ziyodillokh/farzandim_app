// ─────────────────────────────────────────────────────────────────────
// PairingProvider — Riverpod state va providerlar
// ─────────────────────────────────────────────────────────────────────
//
// 4 ta provider:
//   1. authRepositoryProvider     — AnonAuthRepository singleton
//   2. pairingRepositoryProvider  — PairingRepository singleton
//   3. authStateProvider          — Stream<User?> (auth state)
//   4. pairingStateProvider       — StateNotifier<AppPairingState>
//
// `PairingNotifier` ilova ochilganda SharedPreferences'dan
// avvalgi pairing ma'lumotini tiklaydi. tryPair() butun pairing
// flow'ini bajaradi: Auth → Firestore → SharedPreferences → state.
// Pairing tugagach DeviceInfoService boshlanadi va Firestore'ga
// telefon ma'lumotlarini har 60 sekundda yuborib turadi.

import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/restrictions_sync_provider.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:farzandim_child/features/auth/data/repositories/anon_auth_repository.dart';
import 'package:farzandim_child/features/auth/presentation/providers/child_recovery_provider.dart';
import 'package:farzandim_child/features/background/presentation/providers/background_service_provider.dart';
import 'package:farzandim_child/features/device_info/presentation/providers/device_info_provider.dart';
import 'package:farzandim_child/features/location/presentation/providers/location_provider.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/pairing/data/repositories/pairing_repository.dart';
import 'package:farzandim_child/features/sim_info/presentation/providers/sim_info_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Repositorylar ───────────────────────────────────────────────────

final authRepositoryProvider = Provider<AnonAuthRepository>((ref) {
  return AnonAuthRepository();
});

// Eski pairingRepositoryProvider — endi pairing_repository.dart'da
// Dio + TokenStorage bilan to'liq tarzda yoziladi. Bu yerda eski
// chaqiruvlar uchun re-export (oddiy aliasing):
//   ref.read(pairingRepositoryProvider) — pairing_repository.dart'dagi.

// ─── Auth state stream ───────────────────────────────────────────────

/// Real-vaqt auth holatini kuzatadi. UI'da ishlatish uchun:
///   final authState = ref.watch(authStateProvider);
///   authState.when(data: (user) => ..., loading: ..., error: ...);
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// ─── Pairing state ───────────────────────────────────────────────────

final pairingStateProvider =
    StateNotifierProvider<PairingNotifier, AppPairingState>((ref) {
  return PairingNotifier(
    ref.read(pairingRepositoryProvider),
    ref.read(authRepositoryProvider),
    ref,
  );
});

class PairingNotifier extends StateNotifier<AppPairingState> {
  PairingNotifier(this._repository, this._auth, this._ref)
      : super(const AppPairingState()) {
    _loadFromStorage();
  }

  final PairingRepository _repository;
  final AnonAuthRepository _auth;
  final Ref _ref;

  /// Ilova qayta ochilganda SharedPreferences'dan tiklash.
  ///
  /// Bola allaqachon pairing qilgan bo'lsa, qayta kod kiritmasligi
  /// uchun darhol `paired` holatga o'tamiz — routing Dashboard'ga
  /// yo'naltiradi. Pairing tiklanganidan keyin DeviceInfoService
  /// avtomatik boshlanadi.
  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final parentUid = prefs.getString('parentUid');
    final childId = prefs.getString('childId');
    final childName = prefs.getString('childName');
    var currentUserId = prefs.getString('currentUserId');

    // Sprint 4.4.5 fallback: eski pair'larda `currentUserId` saqlanmagan.
    // Backend'dan `GET /api/users/me` orqali olib, prefs'ga saqlaymiz.
    if (currentUserId == null && parentUid != null && childId != null) {
      try {
        final me = await _repository.getMeUserId();
        if (me != null && me.isNotEmpty) {
          currentUserId = me;
          await prefs.setString('currentUserId', me);
        }
      } catch (_) {/* ignore — keyingi pair'da olinadi */}
    }

    if (parentUid != null && childId != null) {
      state = state.copyWith(
        status: PairingStatus.paired,
        parentUid: parentUid,
        childId: childId,
        childName: childName,
        currentUserId: currentUserId,
      );

      // Saqlangan pairing'da qurilma ma'lumotini yangilashni boshlash.
      final deviceInfoService = _ref.read(deviceInfoServiceProvider);
      await deviceInfoService.start(
        parentUid: parentUid,
        childId: childId,
      );

      // Location stream'ni boshlash (ruxsat berilgan bo'lsa).
      final locationService = _ref.read(locationServiceProvider);
      await locationService.start(
        parentUid: parentUid,
        childId: childId,
        childName: childName ?? 'Bola',
      );

      // SIM kartadan telefon raqamini olish + Firestore'ga yozish
      // (Sprint 4.1 — SOS dialog callButton uchun). Idempotent —
      // allaqachon bor bo'lsa skip qiladi. Xato bo'lsa jim chiqadi.
      await _ref.read(simInfoServiceProvider).syncPhoneNumberIfNeeded(
            parentUid: parentUid,
            childId: childId,
          );

      // App usage sync timer'ini ishga tushirish (Sprint 4.1 bugfix).
      // Avval faqat PermissionSetupScreen'da chaqirilardi → app
      // restart'da Timer.periodic yo'qolib qolardi. Endi har pair
      // tiklanishda qaytadan boshlanadi. PACKAGE_USAGE_STATS yo'q
      // bo'lsa _syncNow ichida jim chiqadi (non-critical).
      _ref.read(usageSyncServiceProvider)?.start();
      _ref.read(stepCounterServiceProvider)?.start();

      // Sprint 4.2: Firestore app_restrictions → SharedPreferences sync.
      // Kotlin RestrictionService SharedPreferences'dan o'qib bloklangan
      // ilovalar ustiga overlay ko'rsatadi.
      _ref.read(restrictionsSyncServiceProvider).start(
            childId: childId,
          );

      // Foreground Service — app yopilsa ham kuzatuvni davom ettirish.
      await _ref.read(backgroundServiceProvider).start();

      // App Restrictions Foreground Service — sozlamalardan o'tilgan
      // bo'lsa, qayta o'rnatishdan keyin avtomatik tiklanadi.
      await _startRestrictionServiceIfReady();
      return;
    }

    // SharedPreferences bo'sh — agar persistent Auth UID bo'lsa,
    // collectionGroup query orqali eski child hujjatini topishga
    // urinamiz (uninstall keyin qayta o'rnatishda mavjud bo'lmaydi
    // anonim auth uchun, lekin Phone Auth migratsiyasidan keyin
    // ishlaydi). Topilmasa state o'zgarmaydi.
    final user = _auth.currentUser;
    if (user == null) return;

    final recovered = await _ref
        .read(childRecoveryServiceProvider)
        .findExistingChild(user.uid);
    if (recovered == null) return;

    await restoreFromRecovery(
      parentUid: recovered.parentUid,
      childId: recovered.childId,
      childName: recovered.childName,
    );
  }

  /// Auth UID bo'yicha topilgan bola hujjatidan pairing'ni tiklash.
  ///
  /// SharedPreferences yoziladi, state `paired` ga ko'tariladi va
  /// barcha background service'lar ishga tushadi. Caller (auth flow
  /// yoki `_loadFromStorage`) shu metodni `findExistingChild` natijasi
  /// bilan chaqiradi.
  Future<void> restoreFromRecovery({
    required String parentUid,
    required String childId,
    required String childName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parentUid', parentUid);
    await prefs.setString('childId', childId);
    await prefs.setString('childName', childName);

    state = state.copyWith(
      status: PairingStatus.paired,
      parentUid: parentUid,
      childId: childId,
      childName: childName,
    );

    final deviceInfoService = _ref.read(deviceInfoServiceProvider);
    await deviceInfoService.start(
      parentUid: parentUid,
      childId: childId,
    );

    final locationService = _ref.read(locationServiceProvider);
    await locationService.start(
      parentUid: parentUid,
      childId: childId,
      childName: childName,
    );

    // SIM phone number sync (Sprint 4.1). Idempotent.
    await _ref.read(simInfoServiceProvider).syncPhoneNumberIfNeeded(
          parentUid: parentUid,
          childId: childId,
        );

    // App usage sync (Sprint 4.1 bugfix — restart'da yo'qolardi).
    _ref.read(usageSyncServiceProvider)?.start();
      _ref.read(stepCounterServiceProvider)?.start();

    await _ref.read(backgroundServiceProvider).start();
    await _startRestrictionServiceIfReady();
  }

  /// PACKAGE_USAGE_STATS va SYSTEM_ALERT_WINDOW yoqilgan bo'lsa
  /// RestrictionService'ni avtomatik ishga tushiradi va Firestore
  /// sync timer'ini yoqadi (app_usage + installed_apps). Aks holda
  /// jim qaytadi — foydalanuvchi PermissionSetupScreen'da yoqishi
  /// kerak (u yer Service'ni o'zi ham boshlaydi).
  Future<void> _startRestrictionServiceIfReady() async {
    final usage = UsageStatsService();
    final hasUsage = await usage.hasPermission();
    final hasOverlay = await usage.hasOverlayPermission();
    if (hasUsage && hasOverlay) {
      await usage.startRestrictionService();
    }
    if (hasUsage) {
      _ref.read(usageSyncServiceProvider)?.start();
      _ref.read(stepCounterServiceProvider)?.start();

      // Sprint 4.2: Firestore app_restrictions → SharedPreferences sync.
      // Kotlin RestrictionService SharedPreferences'dan o'qib bloklangan
      // ilovalar ustiga overlay ko'rsatadi. State'dan parentUid/childId
      // o'qiymiz — pairing tugagan bo'lsa to'ldirilgan.
      final pParent = state.parentUid;
      final pChild = state.childId;
      if (pParent != null && pChild != null) {
        _ref.read(restrictionsSyncServiceProvider).start(
              childId: pChild,
            );
      }
    }
  }

  /// Bola kiritgan kodni tekshirish va pairing'ni tugatish.
  ///
  /// Bosqichlar:
  ///   1. Anonymous Auth (yoki mavjud UID)
  ///   2. Firestore: kod tekshirish + bola hujjatiga linkedDeviceUid
  ///   3. Bola ma'lumotini olish (ism)
  ///   4. SharedPreferences'ga saqlash
  ///   5. State'ni `paired` ga o'tkazish
  ///   6. DeviceInfoService boshlash
  ///
  /// `true` — muvaffaqiyatli, `false` — xato (state.errorMessage'da sabab).
  Future<bool> tryPair(String code) async {
    state = state.copyWith(status: PairingStatus.pairing);

    try {
      // 1. Anonymous Auth — bola UID oladi (Firestore eski xulq;
      //    Backend mode JWT'ni PairingRepository'da saqlaydi).
      //    DEV stub Firebase keys bilan bu chaqiruv 400 beradi —
      //    backend verifyCode uchun UID kerak emas (signature ignored),
      //    shuning uchun xatosini yutib placeholder ishlatamiz.
      String childUid;
      try {
        final user = await _auth.signInAnonymously();
        childUid = user.uid;
      } catch (e) {
        debugPrint('[DEV] Anonymous auth skipped: $e');
        childUid = 'dev-no-firebase';
      }

      // 2. Backend'da kod tekshirish (POST /api/auth/child-pair)
      final result = await _repository.verifyCode(code, childUid);

      // 3. Natija turini ushlash — har biriga maxsus xabar
      switch (result) {
        case PairingFailureInvalidCode():
          state = state.copyWith(
            status: PairingStatus.error,
            errorMessage: "Kod noto'g'ri",
          );
          return false;
        case PairingFailureAlreadyUsed():
          state = state.copyWith(
            status: PairingStatus.error,
            errorMessage: 'Bu kod allaqachon ishlatilgan. '
                "Ota-onangizdan yangi kod so'rang "
                '(Parent App → Bola → Yangi kod yaratish).',
          );
          return false;
        case PairingFailureNetwork(:final message):
          state = state.copyWith(
            status: PairingStatus.error,
            errorMessage: 'Tarmoq xatosi: $message',
          );
          return false;
        case PairingAwaitingParent(
              :final pairRequestId,
              :final expiresAt,
            ):
          // Backend 0.6.0: parent tasdiqi kutilmoqda.
          state = state.copyWith(
            status: PairingStatus.awaitingParent,
            pairRequestId: pairRequestId,
            pairRequestExpiresAt: expiresAt,
          );
          return false;
        case PairingSuccess():
          break;
      }

      // 4. Bola ma'lumotini olish (ism)
      final childData = await _repository.getChildData(
        result.parentUid,
        result.childId,
      );

      // 5. SharedPreferences'ga saqlash (offline tiklash uchun)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('parentUid', result.parentUid);
      await prefs.setString('childId', result.childId);
      await prefs.setString('currentUserId', result.currentUserId);
      await prefs.setString(
        'childName',
        childData?['name'] as String? ?? 'Bola',
      );

      // 6. State yangilash
      state = state.copyWith(
        status: PairingStatus.paired,
        parentUid: result.parentUid,
        childId: result.childId,
        childName: childData?['name'] as String? ?? 'Bola',
        currentUserId: result.currentUserId,
      );

      // Quyidagi service'lar Android/iOS-only plugin'larga tayanadi
      // (permission_handler, geolocator, flutter_foreground_task, ...).
      // Web preview'da har biri UnimplementedError tashlaydi — bu pairing
      // muvaffaqiyatini bekor qilmasligi kerak. Har birini alohida try/catch
      // bilan o'rab, web'da jim o'tkazib yuboramiz.
      Future<void> safe(String name, Future<void> Function() fn) async {
        try {
          await fn();
        } catch (e) {
          debugPrint('[DEV] $name skipped: $e');
        }
      }

      // 6. Device Info service'ni boshlash
      await safe('DeviceInfoService', () async {
        await _ref.read(deviceInfoServiceProvider).start(
              parentUid: result.parentUid,
              childId: result.childId,
            );
      });

      // 7. Location stream'ni boshlash (Permission ekrani ruxsat olgach
      // ishlaydi — yo'q bo'lsa LocationService jim qaytadi).
      await safe('LocationService', () async {
        await _ref.read(locationServiceProvider).start(
              parentUid: result.parentUid,
              childId: result.childId,
              childName: childData?['name'] as String? ?? 'Bola',
            );
      });

      // 7b. SIM phone number sync (Sprint 4.1 — SOS dialog uchun).
      // Idempotent + xato bo'lsa jim chiqadi (non-critical).
      await safe('SimInfoService', () async {
        await _ref.read(simInfoServiceProvider).syncPhoneNumberIfNeeded(
              parentUid: result.parentUid,
              childId: result.childId,
            );
      });

      // 7c. App usage sync (Sprint 4.1 bugfix).
      try {
        _ref.read(usageSyncServiceProvider)?.start();
      _ref.read(stepCounterServiceProvider)?.start();
      } catch (e) {
        debugPrint('[DEV] UsageSyncService skipped: $e');
      }

      // Sprint 4.2: Firestore app_restrictions → SharedPreferences sync.
      try {
        _ref
            .read(restrictionsSyncServiceProvider)
            .start(childId: result.childId);
      } catch (e) {
        debugPrint('[DEV] RestrictionsSync skipped: $e');
      }

      // 8. Foreground Service — app yopilsa ham davom etadi.
      await safe('BackgroundService', () async {
        await _ref.read(backgroundServiceProvider).start();
      });

      // 9. RestrictionService — agar oldin sozlamalarda yoqilgan bo'lsa.
      await safe('RestrictionService', _startRestrictionServiceIfReady);

      return true;
    } catch (e) {
      state = state.copyWith(
        status: PairingStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Backend 0.6.0 — PairWaitingScreen approve polling muvaffaqiyatli
  /// bo'lganda chaqiriladi. tryPair success path bilan teng — child data
  /// fetch + state + services start.
  Future<bool> completeFromApprovedPair({
    required String parentUid,
    required String childId,
    required String currentUserId,
  }) async {
    try {
      final childData = await _repository.getChildData(parentUid, childId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('parentUid', parentUid);
      await prefs.setString('childId', childId);
      await prefs.setString('currentUserId', currentUserId);
      await prefs.setString(
        'childName',
        childData?['name'] as String? ?? 'Bola',
      );

      state = state.copyWith(
        status: PairingStatus.paired,
        parentUid: parentUid,
        childId: childId,
        childName: childData?['name'] as String? ?? 'Bola',
        currentUserId: currentUserId,
      );

      final deviceInfoService = _ref.read(deviceInfoServiceProvider);
      await deviceInfoService.start(
        parentUid: parentUid,
        childId: childId,
      );

      final locationService = _ref.read(locationServiceProvider);
      await locationService.start(
        parentUid: parentUid,
        childId: childId,
        childName: childData?['name'] as String? ?? 'Bola',
      );

      await _ref.read(simInfoServiceProvider).syncPhoneNumberIfNeeded(
            parentUid: parentUid,
            childId: childId,
          );

      _ref.read(usageSyncServiceProvider)?.start();
      _ref.read(stepCounterServiceProvider)?.start();
      _ref.read(restrictionsSyncServiceProvider).start(childId: childId);

      await _ref.read(backgroundServiceProvider).start();
      await _startRestrictionServiceIfReady();

      return true;
    } catch (e) {
      state = state.copyWith(
        status: PairingStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// PairWaitingScreen rejected/expired/bekor bo'lganda chaqiriladi.
  void resetToNotPaired() {
    state = const AppPairingState();
  }

  /// Pairing'ni bekor qilish: SharedPreferences tozalash + signOut.
  ///
  /// Bola qaytadan kod kiritishi uchun (yoki test/debug uchun).
  /// DeviceInfoService oldindan `markOffline` qilinadi — Parent App
  /// real-vaqt online holatini yangilaydi.
  Future<void> unpair() async {
    final deviceInfoService = _ref.read(deviceInfoServiceProvider);
    await deviceInfoService.markOffline();

    final locationService = _ref.read(locationServiceProvider);
    locationService.stop();

    await _ref.read(backgroundServiceProvider).stop();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('parentUid');
    await prefs.remove('childId');
    await prefs.remove('childName');

    await _auth.signOut();

    state = const AppPairingState();
  }
}
