// Faol akkauntga qarab ilova ildizi.
//
// Qurilma egasining konteyneri (asosiy) ilova umri davomida tirik: haqiqiy
// PairingNotifier, nazorat xizmatlari, FCM tokeni, socket va cheklovlar
// sinxroni mehmon akkaunt ochiq paytda ham egasi nomidan ishlayveradi (D3 —
// umumiy qurilmada nazorat egasida qoladi). Mehmon akkaunt — alohida
// konteyner: o'z tokenlari, «juftlash» holati va socket'i; qurilma
// xizmatlari (FCM, cheklovlar) unda o'chirilgan. Mehmon almashganda uning
// konteyneri xotiradagi barcha ma'lumoti bilan birga yopiladi.

import 'dart:async';

import 'package:farzandim_child/core/auth/session_events.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/realtime/socket_providers.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_unlock_request_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restrictions_sync.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/restrictions_sync_provider.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/unlock_request_provider.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/fcm_provider.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/growth/kirish/data/account_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ro'yxat; o'zgarganda kuzatuvchi vidjetlar qayta quriladi.
final accountRegistryProvider = Provider<AccountRegistry>(
  (ref) => _bindRegistry(ref, AccountRegistry.instance),
);

/// [registry] ni konteynerga ulaydi (ilova va testlar uchun).
Override accountRegistryOverride(AccountRegistry registry) =>
    accountRegistryProvider.overrideWith((ref) => _bindRegistry(ref, registry));

AccountRegistry _bindRegistry(Ref ref, AccountRegistry registry) {
  registry.addListener(ref.notifyListeners);
  ref.onDispose(() => registry.removeListener(ref.notifyListeners));
  return registry;
}

/// Mehmon konteynerida — shu akkaunt; qurilma egasi konteynerida `null`.
final activeGuestProvider = Provider<DeviceAccount?>((_) => null);

/// Qurilma egasining haqiqiy PairingNotifier'i (mehmon konteyneridan ham).
final ownerPairingProvider = Provider<PairingNotifier>(
  (ref) => ref.watch(pairingStateProvider.notifier),
);

/// Mehmon konteyneri sozlamalari: o'z tokenlari va «juftlash» holati;
/// qurilma egasining xizmatlari ([base] konteynerda) unga o'tmaydi.
List<Override> guestOverrides(
  DeviceAccount guest, {
  required ProviderContainer base,
  required AccountRegistry registry,
}) => [
  accountRegistryOverride(registry),
  activeGuestProvider.overrideWithValue(guest),
  tokenStorageProvider.overrideWithValue(guestTokenStorage(guest.childId)),
  pairingStateProvider.overrideWith(
    (ref) => GuestPairingNotifier(guest, registry),
  ),
  ownerPairingProvider.overrideWith(
    (ref) => base.read(pairingStateProvider.notifier),
  ),
  // Qurilmada FCM tokeni bitta — u egasiniki: ota-onaning qo'ng'irog'i,
  // joylashuv so'rovi va cheklovlar shu orqali keladi.
  fcmInitializerProvider.overrideWith((ref) async {}),
  // Cheklovlar qurilma egasiniki — mehmonning ota-onasi hodisalari ularni
  // almashtirib yubormasin.
  restrictionsSyncServiceProvider.overrideWithValue(
    const _NoRestrictionsSync(),
  ),
  // Bloklangan ilova egasining qoidasi bilan bloklangan — «Ruxsat so'rash»
  // egasining ota-onasiga boradi.
  backendUnlockRequestRepositoryProvider.overrideWith(
    (ref) => base.read(backendUnlockRequestRepositoryProvider),
  ),
];

class AccountScope extends StatefulWidget {
  const AccountScope({
    super.key,
    required this.registry,
    required this.child,
    this.overrides = const [],
    this.ownerServices,
  });

  final AccountRegistry registry;
  final Widget child;

  /// Asosiy (egasi) konteyneriga qo'shimcha sozlamalar — testlar uchun.
  final List<Override> overrides;

  /// Egasi uchun doim tirik saqlanadigan xizmatlar (`null` — standart).
  final List<ProviderListenable<Object?>>? ownerServices;

  @override
  State<AccountScope> createState() => _AccountScopeState();
}

class _AccountScopeState extends State<AccountScope> {
  late final ProviderContainer _base = ProviderContainer(
    overrides: [accountRegistryOverride(registry), ...widget.overrides],
  );
  ProviderContainer? _guest;
  String? _guestId;
  final _keepAlive = <ProviderSubscription<Object?>>[];
  StreamSubscription<SessionRevoked>? _revoked;

  AccountRegistry get registry => widget.registry;

  @override
  void initState() {
    super.initState();
    // Egasining xizmatlari UI qaysi akkauntda bo'lishidan qat'i nazar
    // ishlaydi: juftlash holati (xizmatlarni tiklaydi), FCM va socket.
    for (final service
        in widget.ownerServices ??
            <ProviderListenable<Object?>>[
              pairingStateProvider,
              fcmInitializerProvider,
              socketLifecycleProvider,
            ]) {
      _keepAlive.add(
        _base.listen<Object?>(
          service,
          (_, _) {},
          onError: (e, _) =>
              debugPrint('[accounts] egasi xizmati: ${e.runtimeType}'),
        ),
      );
    }
    _revoked = SessionEvents.revoked.listen(_onRevoked);
    registry.addListener(_onRegistry);
    _guest = _containerFor(registry.activeGuest);
  }

  /// Qurilma egasining sessiyasi yopildi — ro'yxatdan chiqariladi (A12).
  /// Juftlashni egasi konteyneridagi PairingNotifier o'zi tozalaydi.
  void _onRevoked(SessionRevoked event) {
    if (!event.isOwner || registry.owner == null) return;
    unawaited(registry.ownerClosed(notice: closedReasonFromWire(event.reason)));
  }

  ProviderContainer? _containerFor(DeviceAccount? guest) {
    _guestId = guest?.childId;
    if (guest == null) return null;
    return ProviderContainer(
      overrides: guestOverrides(guest, base: _base, registry: registry),
    );
  }

  void _onRegistry() {
    final guest = registry.activeGuest;
    if (guest?.childId == _guestId) return;
    final previous = _guest;
    setState(() => _guest = _containerFor(guest));
    if (previous == null) return;
    // Eski daraxt shu kadrda yechiladi — uning konteyneri keyin yopiladi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previous.dispose();
      if (guest == null) {
        // Egasiga qaytdik: native «Ruxsat so'rash» kanali yana egasining
        // oqimiga ulansin (oxirgi yaratilgan ko'prik kanalni egallaydi).
        _base.invalidate(unlockRequestBridgeProvider);
        _base.read(unlockRequestBridgeProvider);
      }
    });
  }

  @override
  void dispose() {
    registry.removeListener(_onRegistry);
    unawaited(_revoked?.cancel());
    for (final subscription in _keepAlive) {
      subscription.close();
    }
    _guest?.dispose();
    _base.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final container = _guest ?? _base;
    return UncontrolledProviderScope(
      key: ObjectKey(container),
      container: container,
      child: widget.child,
    );
  }
}

class _NoRestrictionsSync implements RestrictionsSync {
  const _NoRestrictionsSync();

  @override
  void start({required String childId}) {}

  @override
  Future<void> sync() async {}

  @override
  void dispose() {}
}

/// Mehmon akkaunt uchun «juftlash» holati: faqat bola kimligi. Nazorat
/// xizmatlarini ishga tushirmaydi va qurilma egasining saqlangan juftlashiga
/// tegmaydi. Sessiyasi bekor qilinsa — akkaunt shu qurilmadan chiqariladi (A12).
class GuestPairingNotifier extends StateNotifier<AppPairingState>
    implements PairingNotifier {
  GuestPairingNotifier(this.account, this._registry)
    : super(
        AppPairingState(
          status: PairingStatus.paired,
          // Yozishmalar (SOS, oila) mehmonning o'z ota-onasiga boradi.
          parentUid: account.parentId ?? '',
          childId: account.childId,
          childName: account.name,
          currentUserId: account.userId,
        ),
      ) {
    final scope = guestTokenScope(account.childId);
    _revoked = SessionEvents.revoked.listen((event) {
      if (event.scope == scope) unawaited(_closed(event.reason));
    });
  }

  final DeviceAccount account;
  final AccountRegistry _registry;
  StreamSubscription<SessionRevoked>? _revoked;

  Future<void> _closed(String? reason) => _registry.signOutGuest(
    account.childId,
    notice: closedReasonFromWire(reason),
  );

  @override
  void dispose() {
    unawaited(_revoked?.cancel());
    super.dispose();
  }

  @override
  Future<void> unpair() => _registry.signOutGuest(account.childId);

  @override
  Future<void> handleSessionRevoked() => _closed(null);

  @override
  Future<void> updateChildName(String name) async {
    state = state.copyWith(childName: name);
    await _registry.upsert(account.copyWith(name: name));
  }

  @override
  void clearSessionEndedNotice() {}

  @override
  void resetToNotPaired() {
    unawaited(unpair());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Juftlash amallari (kod, QR, tiklash) mehmon akkauntda ma'nosiz.
    debugPrint('[accounts] mehmon akkauntda ${invocation.memberName}');
    return super.noSuchMethod(invocation);
  }
}
