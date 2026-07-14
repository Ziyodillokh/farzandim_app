// ─────────────────────────────────────────────────────────────────────
// Socket.io Riverpod providers (Sprint 4.4.1 Day 2)
// ─────────────────────────────────────────────────────────────────────
//
// 2 ta provider:
//   1. socketConnectionProvider — StreamProvider, UI debug indicator
//      uchun real-time state (connecting/connected/disconnected/error).
//   2. socketLifecycleProvider — auth state'ga listen qiladi va
//      automatic connect/disconnect qiladi (login → connect,
//      logout → disconnect).
//
// Lifecycle provider'ni app'ning bootstrap qatlamida bir marta `watch`
// qilish kifoya (`main.dart` yoki app shell). Side-effect ishlatadi.

import 'dart:async';

import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// UI'da watch qilish uchun connection state.
///
/// ```dart
/// final connection = ref.watch(socketConnectionProvider);
/// connection.when(
///   data: (state) => Text(state.label),
///   loading: () => CircularProgressIndicator(),
///   error: (e, _) => Text(friendlyError(e)),
/// );
/// ```
final socketConnectionProvider = StreamProvider<SocketConnectionState>((ref) {
  final client = ref.watch(socketClientProvider);
  // Initial state — stream'ni state bilan boshlash.
  return client.stateStream.asBroadcastStream(
    onListen: (sub) {
      // Bir marta hozirgi state'ni yuborish (yangi listener uchun).
      // Bu shartli: agar broadcast bo'lmasa double-event ham yuboriladi.
    },
  );
});

/// Auth state'ga listen qiladi: login → socket.connect(), logout →
/// socket.disconnect(). Bu provider hech qanday value qaytarmaydi
/// (Provider<void>) — faqat side-effect uchun.
///
/// **Foydalanish:** App shell (masalan `app.dart` yoki splash bilan
/// keyingi widget)'da bir marta `ref.watch(socketLifecycleProvider)`.
final socketLifecycleProvider = Provider<void>((ref) {
  final client = ref.watch(socketClientProvider);

  // Bolalar room'iga qo'shilish — avval HECH QAERDA chaqirilmagan edi
  // (faqat `joinChildRoom` metodi yozilgan, lekin ishlatilmagan). Natijada
  // backend `emitToChild` (gamification profile:updated, app_limit,
  // geo_zone, notification, routine, unlock_request, schedule, sos,
  // location) — bittasi ham WS orqali yetib kelmasdi, faqat ekran qayta
  // ochilganda (HTTP refetch) ko'rinardi. DON/XP "real-time kelmayapti"
  // shikoyatining asosiy sababi shu edi.
  final joinedRooms = <String>{};

  void joinAllChildRooms() {
    if (client.state != SocketConnectionState.connected) return;
    for (final c in ref.read(childrenListProvider)) {
      if (joinedRooms.add(c.id)) {
        unawaited(client.joinChildRoom(c.id));
      }
    }
  }

  ref.listen<BackendAuthState>(backendAuthProvider, (previous, next) {
    final wasAuthenticated = previous is AuthAuthenticated;
    final isAuthenticated = next is AuthAuthenticated;

    if (!wasAuthenticated && isAuthenticated) {
      debugPrint('SocketLifecycle: auth → connecting');
      client.connect();
    } else if (wasAuthenticated && !isAuthenticated) {
      debugPrint('SocketLifecycle: logout → disconnect');
      joinedRooms.clear();
      client.disconnect();
    }
  }, fireImmediately: true);

  // Har CONNECT/RECONNECT'da qaytadan join — socket.io reconnect yangi
  // session (yangi socket.id) yaratadi, eski room a'zoligi saqlanmaydi.
  final connSub = client.stateStream.listen((state) {
    if (state == SocketConnectionState.connected) {
      joinedRooms.clear();
      joinAllChildRooms();
    }
  });

  // Yangi bola qo'shilsa (yoki ro'yxat yangilansa) — shu bola room'iga ham.
  ref
    ..listen<List<Child>>(childrenListProvider, (previous, next) {
      joinAllChildRooms();
    })
    ..onDispose(connSub.cancel);
});
