// ─────────────────────────────────────────────────────────────────────
// Socket.io Riverpod providers — Child App (Sprint 4.4.11 + 4.4.25)
// ─────────────────────────────────────────────────────────────────────
//
// Parent App'dagi pattern bilan parallel:
//   socketConnectionProvider — UI debug indicator
//   socketLifecycleProvider — pairing + ilova holatiga qarab connect/
//                             disconnect + restrictions WS event'larini
//                             fon ishlari egasiga (FGS yoki UI) uzatish
//
// 1.0.20: socket faqat ilova EKRANDA bo'lganda ochiq. Fonda (paused/hidden)
// qisqa kutishdan keyin yopiladi — 25 s ping radio'ni uyg'otib turmasin;
// fondagi o'zgarishlar FCM push orqali keladi. Qaytganda yangi token bilan
// darhol qayta ulanadi.

import 'dart:async';

import 'package:farzandim_child/app/app_lifecycle_provider.dart';
import 'package:farzandim_child/core/realtime/socket_client.dart';
import 'package:farzandim_child/features/background/data/services/parvoz_messages.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/background_owner_provider.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/growth/kirish/data/session_close.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ilova fonga o'tgach socket shuncha vaqtdan keyin yopiladi (tez
/// ilova almashtirishda uzilib-ulanish bo'lmasin).
const kSocketBackgroundGrace = Duration(seconds: 30);

/// Cheklovlar o'zgarganini bildiruvchi WS hodisalari.
const kRestrictionEvents = [
  // AppLimit (per-package quota) — Sprint 4.4.25.
  'app_limit:created',
  'app_limit:updated',
  'app_limit:deleted',
  // Schedule (vaqt-window BLOCK/ALLOW) — eski.
  'schedule:created',
  'schedule:updated',
  'schedule:deleted',
  // Rejim (Routine) — "Ilova cheklovlar" oynalari (Android per-app, iOS
  // virtual "tanlangan ilovalar" elementi).
  'routine:created',
  'routine:updated',
  'routine:deleted',
];

/// UI'da watch qilish uchun connection state (debug indicator).
final socketConnectionProvider = StreamProvider<SocketConnectionState>((ref) {
  final client = ref.watch(socketClientProvider);
  return client.stateStream;
});

/// Pairing state va ilova holatiga listen qiladi: paired + ekranda →
/// connect, fon → (kutib) disconnect, notPaired → disconnect. Side-effect —
/// value qaytarmaydi.
///
/// `main.dart` ChildApp build'da bir marta `ref.watch(socketLifecycleProvider)`.
///
/// **Sprint 4.4.25:** restrictions WS event'lari ham shu yerda
/// ulanadi — `app_limit:*`, `schedule:*` yoki `routine:*` paytida fon
/// ishlari egasiga uzatiladi (FGS ishlasa — unga, aks holda UI isolate).
final socketLifecycleProvider = Provider<void>((ref) {
  final client = ref.watch(socketClientProvider);

  // WS subscription'lar (paired bo'lganda boshlanadi, unpair'da yopiladi).
  final subs = <StreamSubscription<dynamic>>[];
  var isPaired = false;
  var isForeground = ref.read(isAppInForegroundProvider);
  Timer? backgroundTimer;

  void cancelAll() {
    for (final s in subs) {
      s.cancel();
    }
    subs.clear();
  }

  /// Ulanish holatini pairing + ilova holatiga moslaydi.
  void syncConnection() {
    if (!isPaired) {
      backgroundTimer?.cancel();
      backgroundTimer = null;
      client.disconnect();
      return;
    }
    if (isForeground) {
      backgroundTimer?.cancel();
      backgroundTimer = null;
      unawaited(client.connect());
      return;
    }
    backgroundTimer ??= Timer(kSocketBackgroundGrace, () {
      backgroundTimer = null;
      debugPrint('SocketLifecycle (Child): fon → disconnect');
      client.disconnect();
    });
  }

  void wireRestrictionListeners() {
    // Bitta egasi: FGS ishlasa `parvoz:restrictions_sync` unga ketadi
    // (o'zi 2 s debounce qiladi), aks holda UI isolate'dagi BackgroundJobs.
    final owner = ref.read(backgroundOwnerProvider);
    for (final event in kRestrictionEvents) {
      subs.add(
        client
            .eventStream(event)
            .listen(
              (_) => unawaited(owner.forward(ParvozMessages.restrictionsSync)),
            ),
      );
    }
  }

  // Sessiya signallari — har konteyner faqat o'z akkauntiga javob beradi
  // (v5: qurilma egasi yoki mehmon akkaunt).
  void wireSessionListeners() {
    // "Bir bola = bir qurilma" qoidasi: backend bola yangi qurilmaga
    // (parent tasdiqi yoki QR re-pair orqali) ko'chgan paytda eski qurilma
    // shu signalni oladi. Lokal pairing'ni avtomatik tozalab, /pairing
    // ekraniga qaytarish — eski telefon foydalanuvchi profili bilan
    // ishlashda davom etmaydi.
    subs.add(
      client.eventStream('child:unpaired').listen((payload) {
        debugPrint('SocketLifecycle (Child): child:unpaired');
        // «Bu qurilmada chiqildi» (A12) — sabab bilan.
        unawaited(
          handleChildUnpaired(
            payload,
            guest: ref.read(activeGuestProvider),
            registry: ref.read(accountRegistryProvider),
            pairing: ref.read(pairingStateProvider.notifier),
            pairedChildId: ref.read(pairingStateProvider).childId,
          ),
        );
      }),
    );

    // Login sessiyasi yopildi (tiklash, boshqa qurilmada kirish, ruxsat
    // o'zgarishi) — faqat shu akkauntning shu qurilmadagi sessiyasi bo'lsa.
    subs.add(
      client.eventStream('session:closed').listen((payload) {
        unawaited(
          handleSessionClosed(
            payload,
            guest: ref.read(activeGuestProvider),
            registry: ref.read(accountRegistryProvider),
            pairing: ref.read(pairingStateProvider.notifier),
          ),
        );
      }),
    );
  }

  // O'ZINING room'iga qo'shilish — avval HECH QAERDA chaqirilmagan edi
  // (faqat `joinChildRoom` metodi yozilgan, lekin ishlatilmagan). Natijada
  // backend `emitToChild` (gamification profile:updated va h.k.) WS orqali
  // hech qachon yetib kelmasdi — faqat ekran qayta ochilganda (HTTP
  // refetch) ko'rinardi. DON "real-time kelmayapti" shikoyatining asosiy
  // sababi shu edi.
  void joinOwnRoom() {
    final childId = ref.read(pairingStateProvider).childId;
    if (childId == null || childId.isEmpty) return;
    unawaited(client.joinChildRoom(childId));
  }

  ref.listen<AppPairingState>(pairingStateProvider, (previous, next) {
    final wasPaired = previous?.status == PairingStatus.paired;
    isPaired = next.status == PairingStatus.paired;

    if (!wasPaired && isPaired) {
      debugPrint('SocketLifecycle (Child): paired → connecting');
      // Cheklovlar qurilma egasiniki — mehmon konteyneri ularni olmaydi.
      if (ref.read(activeGuestProvider) == null) wireRestrictionListeners();
      wireSessionListeners();
    } else if (wasPaired && !isPaired) {
      debugPrint('SocketLifecycle (Child): unpair → disconnect');
      cancelAll();
    }
    syncConnection();
  }, fireImmediately: true);

  // Ilova fonga o'tdi / qaytdi.
  ref.listen<bool>(isAppInForegroundProvider, (_, next) {
    if (next == isForeground) return;
    isForeground = next;
    syncConnection();
  });

  // Har CONNECT/RECONNECT'da qaytadan join — socket.io reconnect yangi
  // session yaratadi, eski room a'zoligi saqlanmaydi. Bu subscription
  // `subs`ga QO'SHILMAYDI — unpair/re-pair davomida ham (cancelAll butun
  // umr davomida faqat restriction listener'larni tozalaydi) tirik qolishi
  // kerak, aks holda qayta pairing'dan keyin join-on-reconnect ishlamay
  // qoladi.
  final connSub = client.stateStream.listen((state) {
    if (state == SocketConnectionState.connected) joinOwnRoom();
  });

  ref.onDispose(() {
    backgroundTimer?.cancel();
    cancelAll();
    connSub.cancel();
  });
});
