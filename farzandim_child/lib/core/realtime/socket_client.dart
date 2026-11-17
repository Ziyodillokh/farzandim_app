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
// Lifecycle: pairing.status == paired VA ilova ekranda → connect;
// fon / logout / unpair → disconnect (`socket_providers.dart`).
//
// Token (1.0.20): handshake `auth` HAR (qayta) ulanishda yangidan olinadi —
// avval birinchi ulanishdagi JWT nusxasi ishlatilardi va 15 daqiqadan keyingi
// har qanday tarmoq uzilishidan so'ng server ulanishni rad etib, realtime
// sessiya oxirigacha o'lik qolardi. Server uzsa (`io server disconnect`,
// kutubxona o'zi qayta ulanmaydi) — token yangilanib, cheklangan backoff
// bilan qayta ulanadi.

// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/config/env_config.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/core/realtime/realtime_socket.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final socketClientProvider = Provider<SocketClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final dio = ref.watch(dioClientProvider);
  final client = SocketClient(
    tokenStorage: tokenStorage,
    // Eskirgan access token'ni yangilash: umumiy Dio'dagi refresh
    // interceptor 401'da o'zi yangilaydi (yengil `GET /users/me`).
    refreshSession: () => dio.get<void>('/users/me'),
  );
  ref.onDispose(client.dispose);
  return client;
});

enum SocketConnectionState { disconnected, connecting, connected, error }

/// Server uzgandan keyingi qayta ulanish kechikishi: 2, 4, 8 … 60 s
/// (+ 0–25% tasodifiy — server qayta ishga tushganda hamma bir paytda
/// ulanmasin).
Duration defaultReconnectDelay(int attempt, [math.Random? random]) {
  const base = Duration(seconds: 2);
  const max = Duration(seconds: 60);
  final exp = base * math.pow(2, math.min(attempt, 6)).toInt();
  final capped = exp > max ? max : exp;
  final jitter = (random ?? math.Random()).nextDouble() * 0.25;
  return capped * (1 + jitter);
}

class SocketClient {
  SocketClient({
    required TokenStorage tokenStorage,
    Future<void> Function()? refreshSession,
    RealtimeSocketFactory socketFactory = createIoSocket,
    String? url,
    Duration Function(int attempt)? reconnectDelay,
    DateTime Function()? clock,
  }) : _tokenStorage = tokenStorage,
       _refreshSession = refreshSession,
       _socketFactory = socketFactory,
       _url = url ?? EnvConfig.wsBaseUrl,
       _reconnectDelay = reconnectDelay ?? defaultReconnectDelay,
       _clock = clock ?? DateTime.now;

  /// Token tugashiga shundan kam qolgan bo'lsa — ulanishdan oldin yangilanadi.
  static const tokenRefreshMargin = Duration(seconds: 30);

  /// Shuncha vaqt barqaror ulanib turgandan keyin backoff qaytadan boshlanadi
  /// (server ulanishi bilanoq uzsa — tez aylanma bo'lmasin).
  static const stableConnection = Duration(seconds: 30);

  final TokenStorage _tokenStorage;
  final Future<void> Function()? _refreshSession;
  final RealtimeSocketFactory _socketFactory;
  final String _url;
  final Duration Function(int attempt) _reconnectDelay;
  final DateTime Function() _clock;

  RealtimeSocket? _socket;
  SocketConnectionState _state = SocketConnectionState.disconnected;

  /// Ulanish kerakmi (connect chaqirilgan, disconnect qilinmagan).
  bool _wantConnected = false;

  /// Har connect/disconnect'da oshadi — eski async ishlar natijasi tashlanadi.
  int _generation = 0;

  /// Server ulanishni rad etdi — keyingi handshake'dan oldin token majburan
  /// yangilanadi.
  bool _forceTokenRefresh = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  DateTime? _connectedAt;

  final _stateController = StreamController<SocketConnectionState>.broadcast();

  SocketConnectionState get state => _state;
  Stream<SocketConnectionState> get stateStream => _stateController.stream;

  void _setState(SocketConnectionState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  /// JWT accessToken bilan socket.io handshake qilib ulanadi. Idempotent.
  Future<void> connect() async {
    _wantConnected = true;
    if (_socket != null) {
      // Socket bor: ulangan yoki kutubxona o'zi qayta ulanmoqda.
      if (_socket!.connected || _socket!.active) return;
      _cancelReconnect();
      _setState(SocketConnectionState.connecting);
      _socket!.connect();
      return;
    }

    final generation = ++_generation;
    var token = await _readToken();
    if (token == null || token.isEmpty) {
      // Access token yo'q, lekin sessiya tirik bo'lishi mumkin — refresh
      // interceptor yangisini oladi (bekor bo'lsa server shuni aytadi).
      _forceTokenRefresh = true;
      token = await _freshToken();
    }
    if (generation != _generation || !_wantConnected || _socket != null) {
      return;
    }
    if (token == null || token.isEmpty) {
      debugPrint('SocketClient (Child): token yo\'q, skip');
      return;
    }

    _setState(SocketConnectionState.connecting);
    final socket = _socketFactory(_url, _authenticate);
    _socket = socket;
    socket
      ..on('connect', (_) => _onConnected(socket))
      ..on('disconnect', (reason) => _onDisconnected(socket, reason))
      ..on('connect_error', (err) => _onConnectError(socket, err))
      ..on('error', (err) {
        debugPrint('SocketClient (Child): error — $err');
      });
    socket.connect();
  }

  void _onConnected(RealtimeSocket socket) {
    if (!identical(socket, _socket)) return;
    _connectedAt = _clock();
    _cancelReconnect();
    _setState(SocketConnectionState.connected);
    debugPrint('SocketClient (Child): ulandi (${socket.id})');
    _reattachAllListeners();
  }

  void _onDisconnected(RealtimeSocket socket, Object? reason) {
    if (!identical(socket, _socket)) return;
    final connectedAt = _connectedAt;
    _connectedAt = null;
    if (connectedAt != null &&
        _clock().difference(connectedAt) >= stableConnection) {
      _reconnectAttempt = 0;
    }
    _setState(SocketConnectionState.disconnected);
    debugPrint('SocketClient (Child): uzildi ($reason)');
    // Server o'zi uzdi (eskirgan/bekor token yoki server qayta ishga tushdi):
    // kutubxona qayta ulanmaydi — token yangilanib, backoff bilan ulanamiz.
    if (reason == 'io server disconnect') {
      _forceTokenRefresh = true;
      _scheduleReconnect();
    }
  }

  void _onConnectError(RealtimeSocket socket, Object? err) {
    if (!identical(socket, _socket)) return;
    _setState(SocketConnectionState.error);
    debugPrint('SocketClient (Child): connect error — $err');
    // Transport xatosida kutubxona o'zi (cheklangan backoff bilan) qayta
    // urinadi; socket faol bo'lmasa — biz ulaymiz.
    if (!socket.active) {
      _forceTokenRefresh = true;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_wantConnected || _reconnectTimer != null) return;
    final delay = _reconnectDelay(_reconnectAttempt++);
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      final socket = _socket;
      if (!_wantConnected || socket == null) return;
      if (socket.connected || socket.active) return;
      _setState(SocketConnectionState.connecting);
      socket.connect();
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Handshake `auth`: har (qayta) ulanishda joriy token. Eskirgan (yoki
  /// server rad etgan) bo'lsa avval yangilanadi.
  void _authenticate(void Function(Map<String, dynamic> auth) send) {
    unawaited(
      _freshToken().then(
        (token) => _sendAuth(send, token),
        onError: (Object e) {
          debugPrint('SocketClient (Child): token olinmadi — $e');
          _sendAuth(send, null);
        },
      ),
    );
  }

  void _sendAuth(void Function(Map<String, dynamic>) send, String? token) {
    try {
      send({'token': token ?? ''});
    } catch (e) {
      // Socket shu orada yopilgan bo'lishi mumkin.
      debugPrint('SocketClient (Child): handshake yuborilmadi — $e');
    }
  }

  Future<String?> _freshToken() async {
    final token = await _readToken();
    final mustRefresh = _forceTokenRefresh || _expiresSoon(token);
    final refresh = _refreshSession;
    if (!mustRefresh || refresh == null) return token;
    _forceTokenRefresh = false;
    try {
      await refresh();
    } catch (e) {
      // 401 bo'lsa refresh interceptor'da yangilangan bo'ladi; tarmoq xatosi
      // bo'lsa — keyingi urinishda.
      debugPrint('SocketClient (Child): token yangilash — $e');
    }
    return _readToken();
  }

  Future<String?> _readToken() async {
    try {
      return await _tokenStorage.readAccessToken();
    } catch (e) {
      debugPrint('SocketClient (Child): token o\'qilmadi — $e');
      return null;
    }
  }

  /// JWT `exp` (soniya) — [tokenRefreshMargin] dan kam qolganmi. O'qib
  /// bo'lmasa `false` (server o'zi tekshiradi).
  bool _expiresSoon(String? token) {
    if (token == null || token.isEmpty) return false;
    final exp = jwtExpiry(token);
    if (exp == null) return false;
    return exp.difference(_clock()) < tokenRefreshMargin;
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
    // socket.on() handler'ni ALMASHTIRMAY USTIGA qo'shadi. Reconnect'da
    // _reattachAllListeners har event uchun qayta on() chaqirardi → N ta
    // reconnect'dan keyin bitta backend emission handler'ni N+1 marta ishga
    // tushirib, controller'ga takror .add() qilardi (voice:received,
    // child:unpaired va h.k. ko'p marta bajarilardi). Eski handler'ni olib
    // tashlaymiz — bizda har event uchun bitta handler.
    socket
      ..off(event)
      ..on(event, (data) {
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
    final socket = _socket;
    if (socket == null || !socket.connected) return false;

    final completer = Completer<bool>();
    socket.emitWithAck(
      'join:child',
      childId,
      ack: (dynamic data) {
        final ok = data is List && data.isNotEmpty && data[0] == true;
        if (!completer.isCompleted) completer.complete(ok);
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => false,
    );
  }

  /// Fon / logout / unpair — socket yopiladi, qayta ulanish to'xtaydi.
  /// Event stream'lar tirik qoladi (keyingi connect'da qayta ulanadi).
  void disconnect() {
    _wantConnected = false;
    _generation++;
    _cancelReconnect();
    _reconnectAttempt = 0;
    _forceTokenRefresh = false;
    _connectedAt = null;
    final socket = _socket;
    _socket = null;
    _attachedEvents.clear();
    if (socket != null) {
      try {
        socket
          ..disconnect()
          ..dispose();
      } catch (e) {
        debugPrint('SocketClient (Child): yopishda xato — $e');
      }
    }
    _setState(SocketConnectionState.disconnected);
  }

  /// App tugaganda full cleanup.
  void dispose() {
    disconnect();
    _stateController.close();
    for (final c in _eventControllers.values) {
      c.close();
    }
    _eventControllers.clear();
  }
}

/// JWT payload'idagi `exp` (UTC). Noto'g'ri token — `null`.
@visibleForTesting
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final json = jsonDecode(payload);
    if (json is! Map) return null;
    final exp = json['exp'];
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      (exp * 1000).toInt(),
      isUtc: true,
    );
  } catch (_) {
    return null;
  }
}
