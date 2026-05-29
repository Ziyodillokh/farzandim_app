// ─────────────────────────────────────────────────────────────────────
// SocketClient — Backend Socket.io (Sprint 4.4)
// ─────────────────────────────────────────────────────────────────────
//
// Backend 6 ta server-side event emit qiladi:
//   - schedule:created/updated/deleted     → child room
//   - routine:created/updated/deleted      → child room
//   - geo_zone:created/updated/deleted     → child room
//   - geo_zone:alert                       → user + child room
//   - location:updated                     → user + child room
//   - voice:received                       → user room (receiver)
//
// Connection flow:
//   1. Auth: handshake.auth.token = JWT accessToken
//   2. Auto-join: user:<userId> room (Backend cookie ham yoqilgan)
//   3. Manual: socket.emitWithAck('join:child', childId) — bola room'i
//   4. Disconnect/reconnect avtomatik (socket.io built-in)
//
// Foydalanish (Riverpod):
//   final socket = ref.watch(socketClientProvider);
//   socket.connect();
//
//   socket.on('schedule:updated', (data) {
//     final schedule = Schedule.fromJson(data as Map<String, dynamic>);
//     ref.read(schedulesProvider.notifier).upsert(schedule);
//   });
//
// Eslatma: Socket.io path default `/socket.io/` — Nginx config'da shu
// path uchun proxy bor (Sprint 4.2.10 Backend Claude tomonidan qo'yilgan).

// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:farzandim/core/auth/token_storage.dart';
import 'package:farzandim/core/config/env_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Singleton Socket provider. App ichida bitta connection yashaydi.
/// Logout vaqtida `dispose()` chaqirilishi shart (token'siz qolmaslik).
final socketClientProvider = Provider<SocketClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final client = SocketClient(tokenStorage: tokenStorage);
  ref.onDispose(client.dispose);
  return client;
});

/// Connection state — UI'da "Real-time uzilgan" indikator uchun.
enum SocketConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class SocketClient {
  SocketClient({required TokenStorage tokenStorage})
      : _tokenStorage = tokenStorage;

  final TokenStorage _tokenStorage;
  io.Socket? _socket;
  SocketConnectionState _state = SocketConnectionState.disconnected;

  /// State o'zgarishini UI'ga uzatadigan broadcast stream.
  /// `socketConnectionProvider` (StreamProvider) shu yerdan o'qiydi.
  final _stateController =
      StreamController<SocketConnectionState>.broadcast();

  SocketConnectionState get state => _state;

  /// Broadcast stream — UI debug indicator uchun.
  Stream<SocketConnectionState> get stateStream => _stateController.stream;

  /// Joriy socket. `connect()` chaqirilmagan bo'lsa `null`.
  io.Socket? get socket => _socket;

  void _setState(SocketConnectionState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  /// JWT accessToken bilan socket.io handshake qilib ulanadi.
  /// Avval ulangan bo'lsa — qaytaradi.
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await _tokenStorage.readAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint("SocketClient: token yo'q, ulanish o'tkazib yuborildi");
      return;
    }

    _setState(SocketConnectionState.connecting);

    _socket = io.io(
      EnvConfig.wsBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .build(),
    );

    _socket!
      ..onConnect((_) {
        _setState(SocketConnectionState.connected);
        debugPrint('SocketClient: ulandi (${_socket!.id})');
        // Yangi socket — eventStream'lar uchun listener'larni qayta ulash.
        _reattachAllListeners();
      })
      ..onDisconnect((_) {
        _setState(SocketConnectionState.disconnected);
        debugPrint('SocketClient: uzildi');
      })
      ..onConnectError((err) {
        _setState(SocketConnectionState.error);
        debugPrint('SocketClient: connect error — $err');
      })
      ..onError((err) {
        debugPrint('SocketClient: error — $err');
      });

    _socket!.connect();
  }

  // ── Event streams (Sprint 4.4.2) ──
  //
  // Repository'lar `socket.on(event, fn)` o'rniga broadcast stream'larga
  // obuna bo'ladi. Bu Dart strict typing'da `EventHandler` typedef
  // konfliktini chetlab o'tadi va bir nechta listener'lar uchun toza
  // multiplex beradi.
  //
  // Lazy attach: birinchi marta `eventStream(event)` chaqirilganda
  // socket'ga inline listener qo'shiladi (typing problem yo'q).

  final _eventControllers = <String, StreamController<dynamic>>{};
  final _attachedEvents = <String>{};

  /// Backend WS event'iga obuna bo'lish stream'i. Bir nechta listener
  /// bir paytda subscribe bo'la oladi.
  ///
  /// Eslatma: agar socket null bo'lsa (login qilinmagan), stream paydo
  /// bo'ladi lekin event'lar kelmaydi. Socket connect bo'lganda listener
  /// qo'shilmaydi (chunki connect oldidan socket null) — bu cheklov.
  /// Real foydalanish: repository'lar `joinChildRoom`'dan oldin auth
  /// tugaganini kutadi (UI screen open bo'lganda socket allaqachon bor).
  Stream<dynamic> eventStream(String event) {
    final controller = _eventControllers.putIfAbsent(
      event,
      () => StreamController<dynamic>.broadcast(),
    );
    _attachListener(event);
    return controller.stream;
  }

  void _attachListener(String event) {
    if (_attachedEvents.contains(event)) return;
    final socket = _socket;
    if (socket == null) return;
    _attachedEvents.add(event);
    // Inline anonymous function — Dart analyzer to'g'ri infer qiladi
    // (`EventHandler<dynamic>` ga match).
    socket.on(event, (data) {
      final controller = _eventControllers[event];
      if (controller != null && !controller.isClosed) {
        controller.add(data);
      }
    });
  }

  /// Connection tiklangach — har bir cached event'ga qaytadan listener
  /// qo'shamiz (yangi socket instance'da). Bu `connect()` ichidan
  /// chaqiriladi.
  void _reattachAllListeners() {
    final events = List<String>.from(_eventControllers.keys);
    _attachedEvents.clear();
    for (final event in events) {
      _attachListener(event);
    }
  }

  /// Bola room'iga qo'shilish — Parent App'da bola tanlangach chaqiriladi.
  /// Backend `join:child` event'ini eshitadi va ownership tekshiradi.
  /// Ack: `true` (qo'shildi) yoki `false` (xato message bilan).
  Future<bool> joinChildRoom(String childId) async {
    if (_socket == null || !_socket!.connected) {
      debugPrint('SocketClient: socket ulanmagan — joinChildRoom skip');
      return false;
    }

    final completer = Completer<bool>();
    _socket!.emitWithAck('join:child', childId, ack: (dynamic data) {
      final ok = data is List && data.isNotEmpty && data[0] == true;
      if (!ok) {
        debugPrint('SocketClient: joinChildRoom rad etildi — $data');
      }
      if (!completer.isCompleted) completer.complete(ok);
    });

    // Timeout — backend javob bermasa hang qilib qolmaslik uchun.
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('SocketClient: joinChildRoom timeout');
        return false;
      },
    );
  }

  /// Bola room'idan chiqish (Parent App boshqa bolaga o'tganda).
  void leaveChildRoom(String childId) {
    _socket?.emit('leave:child', childId);
  }

  /// Logout / app tugaganda — socket yopiladi.
  void dispose() {
    _socket?.dispose();
    _socket = null;
    _setState(SocketConnectionState.disconnected);
    _stateController.close();
    for (final c in _eventControllers.values) {
      c.close();
    }
    _eventControllers.clear();
    _attachedEvents.clear();
  }

  /// Logout — socket'ni yopadi, lekin client obyektini saqlaydi (qayta
  /// `connect()` chaqirsa yangi token bilan ulanadi). Event controllers
  /// saqlanadi (broadcast subscribers yo'qolmasin).
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _attachedEvents.clear(); // yangi socket'da qayta attach kerak
    _setState(SocketConnectionState.disconnected);
  }
}
