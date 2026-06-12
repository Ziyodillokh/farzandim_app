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

import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
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
final socketConnectionProvider =
    StreamProvider<SocketConnectionState>((ref) {
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

  ref.listen<BackendAuthState>(backendAuthProvider, (previous, next) {
    final wasAuthenticated = previous is AuthAuthenticated;
    final isAuthenticated = next is AuthAuthenticated;

    if (!wasAuthenticated && isAuthenticated) {
      debugPrint('SocketLifecycle: auth → connecting');
      client.connect();
    } else if (wasAuthenticated && !isAuthenticated) {
      debugPrint('SocketLifecycle: logout → disconnect');
      client.disconnect();
    }
  }, fireImmediately: true);
});
