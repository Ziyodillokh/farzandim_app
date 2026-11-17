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
// flow'ini bajaradi: Auth → Backend → SharedPreferences → state.
// Pairing tugagach fon ishlari `BackgroundOwner` orqali boshlanadi:
// Android'da FGS va native bloklash darhol yoqiladi, FGS ishlasa fon
// ishlarini faqat uning isolate'i bajaradi (UI nusxa ochmaydi).
//
// Uzish siyosati (1.0.20): faqat server TASDIQLAGAN bekor qilish
// (SESSION_REVOKED / 'Token revoked' / 'User not found or inactive',
// WS child:unpaired / session:closed) yoki bolaning o'z amali. Lokal
// tokenni o'qib bo'lmasligi yoki 'Session rotated' juftlashni O'CHIRMAYDI —
// nazorat keshdagi reja bilan davom etadi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/auth/session_events.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/features/account/data/language_sync_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restrictions_sync_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/restrictions_sync_provider.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:farzandim_child/features/auth/data/repositories/anon_auth_repository.dart';
import 'package:farzandim_child/features/auth/presentation/providers/child_recovery_provider.dart';
import 'package:farzandim_child/features/background/presentation/providers/background_service_provider.dart';
import 'package:farzandim_child/features/onboarding/data/interests_sync_service.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/pairing/data/repositories/pairing_repository.dart';
import 'package:farzandim_child/features/pairing/data/services/background_owner.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/background_owner_provider.dart';
import 'package:farzandim_child/features/screen_time/presentation/providers/screen_time_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
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
    // Faqat qurilma egasining (standart token kalitlari) sessiyasi —
    // mehmon akkauntlarning hodisalari bu yerga tegishli emas.
    _revokedSub = SessionEvents.revoked.listen((event) {
      if (event.isOwner) unawaited(handleSessionRevoked());
    });
    unawaited(
      _loadFromStorage().catchError((Object e) {
        debugPrint('[Pairing] saqlangan juftlashni tiklash xato: $e');
      }),
    );
  }

  final PairingRepository _repository;
  final AnonAuthRepository _auth;
  final Ref _ref;
  StreamSubscription<SessionRevoked>? _revokedSub;

  /// Davom etayotgan uzish — parallel chaqiruvlar (socket signali, sessiya
  /// bekor bo'lishi, hisobni o'chirish) bitta tozalashni bo'lishadi.
  Future<void>? _unpairing;

  @override
  void dispose() {
    unawaited(_revokedSub?.cancel());
    super.dispose();
  }

  /// Ilova qayta ochilganda SharedPreferences'dan tiklash.
  ///
  /// Bola allaqachon pairing qilgan bo'lsa, qayta kod kiritmasligi
  /// uchun darhol `paired` holatga o'tamiz — routing Dashboard'ga
  /// yo'naltiradi. Fon ishlari (FGS + native bloklash) tarmoq so'rovidan
  /// OLDIN boshlanadi — OEM o'ldirgandan keyin himoya darhol tiklansin.
  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final parentUid = prefs.getString('parentUid');
    final childId = prefs.getString('childId');
    final childName = prefs.getString('childName');
    final currentUserId = prefs.getString('currentUserId');

    if (parentUid != null && childId != null) {
      // Server sessiyani ANIQ bekor qilgan (masalan fon isolate'i refresh'da
      // SESSION_REVOKED olgan) — eski ulanish bilan "ulangan, lekin
      // ishlamaydi" holatda qolmaymiz. Tokenni o'qib bo'lmasligi (Keystore
      // nosozligi) "noma'lum" — juftlash va bloklash saqlanadi.
      if (await _isOwnerRevocationConfirmed()) {
        await _endRevokedSession();
        return;
      }

      state = state.copyWith(
        status: PairingStatus.paired,
        parentUid: parentUid,
        childId: childId,
        childName: childName,
        currentUserId: currentUserId,
      );

      // Web — preview rejimi (telefonsiz brauzerda). Background xizmatlar
      // (location/device-info/usage/restriction) — Android/iOS specific.
      // Web'da chaqirilsa permission_handler / battery / device_info_plus
      // platforma-spetsifik kod throw qiladi → konsol xato bilan to'lib
      // ketadi. Web'da skip qilamiz, navigatsiya esa ishlaydi.
      if (kIsWeb) return;

      // ESLATMA: SIM'dan telefon raqamini AVTOMATIK o'qish OLIB TASHLANDI
      // (Google Play Families siyosati — bolalar ilovasida shaxsiy
      // identifikator yig'ish cheklangan; READ_PHONE_* ruxsatlari ham
      // manifestdan chiqarildi). Raqamni ota-ona o'z ilovasida qo'lda
      // kiritadi — SOS qo'ng'iroq tugmasi shundan ishlaydi.
      await _startPairedServices(
        parentUid: parentUid,
        childId: childId,
        childName: childName ?? 'common.fallbackChildName'.tr(),
      );

      // Sprint 4.4.5 fallback: eski pair'larda `currentUserId` saqlanmagan.
      // Backend'dan `GET /api/users/me` orqali olib, prefs'ga saqlaymiz
      // (fon xizmatlari ishga tushgandan KEYIN — tarmoq ularni kechiktirmasin).
      if (currentUserId == null) await _backfillCurrentUserId(prefs);
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

  /// Bolaning ismini yangilaydi (profil tahrirlangandan keyin).
  ///
  /// NEGA KERAK: ekranlarda ism `pairingState.childName` dan o'qiladi
  /// (`profile_screen.dart`), u esa SharedPreferences'da saqlanib, FAQAT
  /// juftlashuv paytida yozilardi — keyin yangilaydigan yo'l umuman yo'q edi.
  /// Shu sabab bola profilda ismini o'zgartirsa, backend (`PUT /children/me`)
  /// to'g'ri yangilanardi-yu, ilovada eski ism qolaverardi.
  ///
  /// Faqat mahalliy holatni yangilaydi — backendga yozish chaqiruvchida
  /// (`ChildRepository.updateMyProfile`).
  Future<void> updateChildName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == state.childName) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('childName', trimmed);
    state = state.copyWith(childName: trimmed);
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
    String? currentUserId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parentUid', parentUid);
    await prefs.setString('childId', childId);
    await prefs.setString('childName', childName);
    // Login bilan kirgan ega (v5): yozishmalarda yo'nalish darhol to'g'ri.
    if (currentUserId != null) {
      await prefs.setString('currentUserId', currentUserId);
    }

    state = state.copyWith(
      status: PairingStatus.paired,
      parentUid: parentUid,
      childId: childId,
      childName: childName,
      currentUserId: currentUserId,
    );

    if (kIsWeb) return;
    await _startPairedServices(
      parentUid: parentUid,
      childId: childId,
      childName: childName,
    );
  }

  /// Ruxsat berilgach (PermissionSetupScreen) yoki ilova qaytganda fon
  /// xizmatlarini darhol ishga tushiradi: FGS + native RestrictionService,
  /// so'ng fon ishlarining egasi qayta hal qilinadi. Idempotent — ishlab
  /// turgan xizmatga bir necha arzon platforma chaqiruvi xolos.
  ///
  /// Ilova qaytishi (resume) buni `backgroundOwnerProvider` orqali o'zi
  /// bajaradi; ruxsat ekrani ham "Davom etish"dan oldin chaqirishi mumkin.
  Future<void> ensureBackgroundRunning() async {
    if (kIsWeb || !state.isPaired) return;
    await _ref.read(backgroundOwnerProvider).ensureRunning();
  }

  /// Juftlangan bola uchun fon ishlari — barcha 4 oqim (saqlangandan
  /// tiklash, kod, tasdiqlangan juftlash, login/tiklash) shu yerdan o'tadi.
  ///
  /// Android: FGS va native RestrictionService DARHOL yoqiladi (keyingi
  /// sovuq startni kutmasdan). FGS ishlasa — heartbeat, cheklovlar, usage
  /// va joylashuvni faqat uning isolate'i bajaradi; ishlamasa UI isolate
  /// bitta BackgroundJobs yuritadi (5 daqiqalik tik + resume).
  /// iOS: UI isolate BackgroundJobs'ga ega; cheklovlar Family Controls
  /// sinxroni (IosRestrictionsSyncService) orqali — avvalgidek.
  Future<void> _startPairedServices({
    required String parentUid,
    required String childId,
    required String childName,
  }) async {
    if (PlatformCapabilities.isIOS) {
      _ref.read(restrictionsSyncServiceProvider).start(childId: childId);
    }
    // Qadamlar — UI isolate'da: Health Connect ruxsati va o'qishi ilova
    // ekranda bo'lishini talab qiladi, FGS isolate qadamlarni yuritmaydi
    // (dublikat yo'q). Davriy taymer yo'q — tik `syncIfDue`, qaytish
    // `syncNow`. Idempotent.
    final steps = _ref.read(stepCounterServiceProvider);
    if (steps != null) {
      unawaited(
        steps.start().catchError((Object e) {
          debugPrint('[Pairing] qadamlar xizmati: $e');
        }),
      );
    }
    await _ref
        .read(backgroundOwnerProvider)
        .attach(
          BackgroundSession(
            childId: childId,
            parentUid: parentUid,
            childName: childName,
          ),
        );
  }

  /// Server tasdiqlagan bekor qilish (fon isolate'i ko'rgan bo'lsa ham).
  /// `TokenStorage` semantikasi: "aniq yo'q" faqat server javobidan keyin;
  /// o'qish xatosi yoki bo'sh o'qish — "noma'lum" (false).
  Future<bool> _isOwnerRevocationConfirmed() async {
    try {
      return await _ref.read(tokenStorageProvider).isSessionDefinitelyMissing();
    } catch (e) {
      debugPrint('[Pairing] sessiya holati noma\'lum: $e');
      return false;
    }
  }

  Future<void> _backfillCurrentUserId(SharedPreferences prefs) async {
    try {
      final me = await _repository.getMeUserId();
      if (me == null || me.isEmpty) return;
      await prefs.setString('currentUserId', me);
      if (mounted && state.isPaired) {
        state = state.copyWith(currentUserId: me);
      }
    } catch (_) {
      /* ignore — keyingi ochilishda qayta urinadi */
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
  ///   6. Fon xizmatlari (FGS + native bloklash, yagona egasi)
  ///
  /// `true` — muvaffaqiyatli, `false` — xato (state.errorMessage'da sabab).
  Future<bool> tryPair(String code) async {
    state = state.copyWith(
      status: PairingStatus.pairing,
      isSessionEnded: false,
    );

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
            errorMessage: 'pairing.errorFallback'.tr(),
          );
          return false;
        case PairingFailureAlreadyUsed():
          state = state.copyWith(
            status: PairingStatus.error,
            errorMessage:
                '${'pairing.errorCodeUsed'.tr()} '
                '${'pairing.errorAskNewCode'.tr()}',
          );
          return false;
        case PairingFailureRateLimited():
          // 429 — "tarmoq xatosi" emas: necha daqiqa kutish kerakligini
          // aniq aytamiz (aks holda "kod/server ishlamayapti" deb o'ylanadi).
          state = state.copyWith(
            status: PairingStatus.error,
            errorMessage: 'pairing.tooManyAttempts'.tr(),
          );
          return false;
        case PairingFailureNetwork():
          state = state.copyWith(
            status: PairingStatus.error,
            errorMessage: 'common.networkError'.tr(),
          );
          return false;
        case PairingAwaitingParent(:final pairRequestId, :final expiresAt):
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
        childData?['name'] as String? ?? 'common.fallbackChildName'.tr(),
      );

      // 6. State yangilash
      state = state.copyWith(
        status: PairingStatus.paired,
        parentUid: result.parentUid,
        childId: result.childId,
        childName:
            childData?['name'] as String? ?? 'common.fallbackChildName'.tr(),
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

      // 7-9. Fon ishlari: FGS + native bloklash darhol, keyin yagona egasi
      // (FGS isolate yoki UI isolate) — dublikat heartbeat/GPS/sync yo'q.
      if (!kIsWeb) {
        await safe('BackgroundServices', () async {
          await _startPairedServices(
            parentUid: result.parentUid,
            childId: result.childId,
            childName:
                childData?['name'] as String? ??
                'common.fallbackChildName'.tr(),
          );
        });
      }

      // 10. Onboarding'da tanlangan qiziqishlarni backend'ga yuborish
      // (pending bo'lsa). Xato bo'lsa keyingi pair/restart'da qayta urinadi.
      await safe('InterestsSync', () async {
        await _ref.read(interestsSyncServiceProvider).syncPendingInterests();
      });

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
        childData?['name'] as String? ?? 'common.fallbackChildName'.tr(),
      );

      state = state.copyWith(
        status: PairingStatus.paired,
        parentUid: parentUid,
        childId: childId,
        childName:
            childData?['name'] as String? ?? 'common.fallbackChildName'.tr(),
        currentUserId: currentUserId,
      );

      if (!kIsWeb) {
        await _startPairedServices(
          parentUid: parentUid,
          childId: childId,
          childName:
              childData?['name'] as String? ?? 'common.fallbackChildName'.tr(),
        );
      }

      // Onboarding qiziqishlarini backend'ga yuborish (pending bo'lsa).
      try {
        await _ref.read(interestsSyncServiceProvider).syncPendingInterests();
      } catch (e) {
        debugPrint('[DEV] InterestsSync skipped: $e');
      }

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
  Future<void> unpair() {
    return _unpairing ??= _doUnpair().whenComplete(() => _unpairing = null);
  }

  /// Server sessiyani bekor qildi (refresh aniq rad etildi). Ulangan bo'lsak —
  /// lokal ulanish va cheklovlar tozalanadi, pairing ekrani sababni aytadi.
  /// Boshqa uzish allaqachon ketayotgan bo'lsa (masalan bola hisobini o'zi
  /// o'chirmoqda) — e'tiborsiz qoldiramiz.
  Future<void> handleSessionRevoked() async {
    if (!state.isPaired || _unpairing != null) return;
    await _endRevokedSession();
  }

  /// Pairing ekrani "sessiya tugadi" xabarini ko'rsatgach chaqiradi.
  void clearSessionEndedNotice() {
    if (!state.isSessionEnded) return;
    state = state.copyWith(isSessionEnded: false);
  }

  Future<void> _endRevokedSession() async {
    try {
      await unpair();
    } catch (e) {
      debugPrint('[Pairing] bekor qilingan sessiyani tozalash xato: $e');
    }
    if (!mounted) return;
    state = const AppPairingState(isSessionEnded: true);
  }

  Future<void> _doUnpair() async {
    // Har qadam alohida himoyalangan — bitta servis xatosi pairing
    // ma'lumotini (pastda) tozalashga to'sqinlik qilmasin, aks holda ilova
    // keyingi ochilishda yana "ulangan" bo'lib qolardi.

    // UI isolate'dagi fon ishlari (BackgroundJobs) va 5 daqiqalik tik.
    await _safeReset(() => _ref.read(backgroundOwnerProvider).detach());
    // Eski bola uchun yaratilgan UI xizmatlari (qadamlar, usage) yopiladi —
    // qayta juftlashda yangi bola uchun yangidan yaratiladi.
    _ref
      ..invalidate(usageSyncServiceProvider)
      ..invalidate(stepCounterServiceProvider);

    final prefs = await SharedPreferences.getInstance();
    // Juftlik kalitlari BIRINCHI o'chadi: kech qolgan FGS yozuvi va native
    // tekshiruv (BootReceiver / RestrictionService `flutter.childId`) uzilganini
    // darhol ko'rsin — tozalangan cheklov holati qayta tiklanmasin.
    await prefs.remove('parentUid');
    await prefs.remove('childId');
    await prefs.remove('childName');
    if (PlatformCapabilities.hasAndroidControls) {
      await _releaseAndroidControls(prefs);
    } else {
      if (PlatformCapabilities.isIOS) {
        // Family Controls: tanlov, siyosat, jadvallar va ota-ona PIN'i
        // tozalanadi — boshqa oilaga ulanganda eski cheklovlar qolmasin.
        await _safeReset(
          () async => _ref.read(restrictionsSyncServiceProvider).dispose(),
        );
        await _safeReset(() => _ref.read(screenTimeChannelProvider).reset());
        await _safeReset(() => _ref.read(parentPinStoreProvider).clear());
      }
      await prefs.remove('restriction.blocked_packages');
      await prefs.remove('restriction.limits');
    }

    // Keyingi ulanishda server yangi bola hisobini yaratadi (tili "uz") —
    // ilova tili unga qayta yozilsin.
    await prefs.remove(kSyncedLanguageKey);

    await _safeReset(_auth.signOut);

    if (mounted) state = const AppPairingState();
  }

  /// Android'da haqiqiy uzish — telefonda eski bolaning nazoratidan hech
  /// narsa qolmasin (reboot yoki ilova yangilanishidan keyin ham).
  Future<void> _releaseAndroidControls(SharedPreferences prefs) async {
    // 1. UI'dagi cheklov sinxroni (bo'lsa, taymerlari bilan) yopiladi.
    _ref.invalidate(restrictionsSyncServiceProvider);
    // 2. FGS (uning isolate'idagi sinxron ham) va native bloklash servisi
    //    ATAYIN to'xtatiladi (ACTION_STOP → watchdog alarmi ham bekor
    //    bo'ladi) — aks holda o'z-o'zini tiklovchi watchdog eski bloklarni
    //    enforce qilaverardi.
    await _safeReset(() => _ref.read(backgroundServiceProvider).stop());
    await _safeReset(() => UsageStatsService().stopRestrictionService());
    // 3. Butun cheklov holati (restriction.*, school_zone.*, game.pending,
    //    limit_warned) — sinxron to'xtagandan KEYIN, hech kim qayta yozmasin.
    await _safeReset(
      () => RestrictionsSyncService.clearEnforcementState(prefs),
    );
    // 4. Egasining tokenlari — yangi juftlash/login yangisini yozadi.
    await _safeReset(() => _ref.read(tokenStorageProvider).clear());
  }

  Future<void> _safeReset(Future<void> Function() reset) async {
    try {
      await reset();
    } catch (e) {
      debugPrint('[Pairing] unpair tozalash xato: $e');
    }
  }
}
