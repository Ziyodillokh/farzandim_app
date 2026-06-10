// ─────────────────────────────────────────────────────────────────────
// Socket.io Riverpod providers — Child App (Sprint 4.4.11 + 4.4.25)
// ─────────────────────────────────────────────────────────────────────
//
// Parent App'dagi pattern bilan parallel:
//   socketConnectionProvider — UI debug indicator
//   socketLifecycleProvider — pairing state'ga listen, auto connect/disconnect
//                             + restrictions WS event'larini
//                             `RestrictionsSyncService.sync()` ga ulash

import 'dart:async';

import 'package:farzandim_child/core/realtime/socket_client.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/restrictions_sync_provider.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// UI'da watch qilish uchun connection state (debug indicator).
final socketConnectionProvider =
    StreamProvider<SocketConnectionState>((ref) {
  final client = ref.watch(socketClientProvider);
  return client.stateStream;
});

/// Pairing state'ga listen qiladi: paired → connect, notPaired/error →
/// disconnect. Side-effect — value qaytarmaydi.
///
/// `main.dart` ChildApp build'da bir marta `ref.watch(socketLifecycleProvider)`.
///
/// **Sprint 4.4.25:** restrictions WS event'lari ham shu yerda
/// ulanadi — `app_limit:*` yoki `schedule:*` event paytida
/// `RestrictionsSyncService.sync()` chaqiriladi.
final socketLifecycleProvider = Provider<void>((ref) {
  final client = ref.watch(socketClientProvider);

  // WS subscription'lar (paired bo'lganda boshlanadi, unpair'da yopiladi).
  final subs = <StreamSubscription<dynamic>>[];

  void cancelAll() {
    for (final s in subs) {
      s.cancel();
    }
    subs.clear();
  }

  void wireRestrictionListeners() {
    final sync = ref.read(restrictionsSyncServiceProvider);
    // AppLimit (per-package quota) — Sprint 4.4.25.
    subs.add(client.eventStream('app_limit:created').listen(
          (_) => unawaited(sync.sync()),
        ));
    subs.add(client.eventStream('app_limit:updated').listen(
          (_) => unawaited(sync.sync()),
        ));
    subs.add(client.eventStream('app_limit:deleted').listen(
          (_) => unawaited(sync.sync()),
        ));
    // Schedule (vaqt-window BLOCK/ALLOW) — eski.
    subs.add(client.eventStream('schedule:created').listen(
          (_) => unawaited(sync.sync()),
        ));
    subs.add(client.eventStream('schedule:updated').listen(
          (_) => unawaited(sync.sync()),
        ));
    subs.add(client.eventStream('schedule:deleted').listen(
          (_) => unawaited(sync.sync()),
        ));

    // "Bir bola = bir qurilma" qoidasi: backend bola yangi qurilmaga
    // (parent tasdiqi yoki QR re-pair orqali) ko'chgan paytda eski qurilma
    // shu signalni oladi. Lokal pairing'ni avtomatik tozalab, /pairing
    // ekraniga qaytarish — eski telefon foydalanuvchi profili bilan
    // ishlashda davom etmaydi.
    subs.add(client.eventStream('child:unpaired').listen((_) {
      debugPrint('SocketLifecycle (Child): child:unpaired — local unpair');
      unawaited(ref.read(pairingStateProvider.notifier).unpair());
    }));
  }

  ref.listen<AppPairingState>(pairingStateProvider, (previous, next) {
    final wasPaired = previous?.status == PairingStatus.paired;
    final isPaired = next.status == PairingStatus.paired;

    if (!wasPaired && isPaired) {
      debugPrint('SocketLifecycle (Child): paired → connecting');
      client.connect();
      wireRestrictionListeners();
    } else if (wasPaired && !isPaired) {
      debugPrint('SocketLifecycle (Child): unpair → disconnect');
      cancelAll();
      client.disconnect();
    }
  }, fireImmediately: true);

  ref.onDispose(cancelAll);
});
