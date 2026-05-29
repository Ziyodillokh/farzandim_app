// ─────────────────────────────────────────────────────────────────────
// SocketClient — Child App Backend Socket.io (Sprint 4.4.11)
// ─────────────────────────────────────────────────────────────────────
//
// Parent App'dagi pattern bilan parallel. Child JWT handshake +
// `user:<childUserId>` auto-join.
//
// Backend WS event'lari (Child App listenchi):
//   - schedule:created/updated/deleted    → child room
//   - routine:created/updated/deleted     → child room
//   - voice:received                      → user room (parent yuborganda)
//   - video:received                      → user room
//   - photo_request:received              → user room (parent so'rov)
//   - photo_request:created               → child room
//   - notification:created                → child room
//   - sos:resolved                        → child room (parent yopdi)
//
// Lifecycle: pairing.status == paired → connect; logout/unpair → disconnect.

// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/config/env_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

final socketClientProvider = Provider<SocketClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final client = SocketClient(tokenStorage: tokenStorage);
  ref.onDispose(client.dispose);
  return client;
});

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

  final _stateController =
      StreamController<SocketConnectionState>.broadcast();

  SocketConnectionState get state => _state;
  Stream<SocketConnectionState> get stateStream => _stateController.stream;
  io.Socket? get socket => _socket;

  void _setState(SocketConnectionState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  /// JWT accessToken bilan socket.io handshake qilib ulanadi.
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await _tokenStorage.readAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('SocketClient (Child): token yo\'q, skip');
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
        debugPrint('SocketClient (Child): ulandi (${_socket!.id})');
        _reattachAllListeners();
      })
      ..onDisconnect((_) {
        _setState(SocketConnectionState.disconnected);
        debugPrint('SocketClient (Child): uzildi');
      })
      ..onConnectError((err) {
        _setState(SocketConnectionState.error);
        debugPrint('SocketClient (Child): connect error — $err');
      })
      ..onError((err) {
        debugPrint('SocketClient (Child): error — $err');
      });

    _socket!.connect();
  }

  // ── Event broadcast streams (Sprint 4.4.11) ──
  //
  // Repository'lar `socket.on(event, fn)` o'rniga broadcast stream'larga
  // obuna bo'ladi (Dart `EventHandler` typedef konfliktini chetlab o'tadi).

  final _eventControllers = <String, StreamController<dynamic>>{};
  final _attachedEvents = <String>{};

  /// Backend WS event'iga obuna bo'lish stream'i.
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
    socket.on(event, (data) {
      final controller = _eventControllers[event];
      if (controller != null && !controller.isClosed) {
        controller.add(data);
      }
    });
  }

  void _reattachAllListeners() {
    final events = List<String>.from(_eventControllers.keys);
    _attachedEvents.clear();
    for (final event in events) {
      _attachListener(event);
    }
  }

  /// Bola room'iga qo'shilish (Backend ownership tekshiradi).
  /// Child App o'z child room'iga avtomatik ulanmaydi — kerak bo'lsa
  /// explicit chaqirish (masalan, parent yuborgan schedule eshitish).
  Future<bool> joinChildRoom(String childId) async {
    if (_socket == null || !_socket!.connected) return false;

    final completer = Completer<bool>();
    _socket!.emitWithAck('join:child', childId, ack: (dynamic data) {
      final ok = data is List && data.isNotEmpty && data[0] == true;
      if (!completer.isCompleted) completer.complete(ok);
    });

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => false,
    );
  }

  /// Logout / unpair — socket yopiladi.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _attachedEvents.clear();
    _setState(SocketConnectionState.disconnected);
  }

  /// App tugaganda full cleanup.
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
}
