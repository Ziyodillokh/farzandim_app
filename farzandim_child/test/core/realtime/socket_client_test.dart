// Socket.IO: har (qayta) ulanish handshake'i JORIY tokenni yuboradi,
// eskirgan token ulanishdan oldin yangilanadi, server uzsa (`io server
// disconnect`) token yangilanib backoff bilan qayta ulanadi.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/realtime/realtime_socket.dart';
import 'package:farzandim_child/core/realtime/socket_client.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 11, 14, 12);

String _jwt(DateTime expiresAt, {String sub = 'u1'}) {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.'
      '${part({'sub': sub, 'exp': expiresAt.millisecondsSinceEpoch ~/ 1000})}'
      '.sig';
}

class _FakeTokens implements TokenStorage {
  String? access;
  int reads = 0;

  @override
  Future<String?> readAccessToken() async {
    reads++;
    return access;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSocket implements RealtimeSocket {
  _FakeSocket(this._auth);

  final SocketAuthProvider _auth;
  final _handlers = <String, void Function(dynamic)>{};
  int connectCalls = 0;
  bool isDisposed = false;

  @override
  bool connected = false;

  @override
  bool active = false;

  @override
  String? get id => connected ? 'sock-1' : null;

  @override
  void on(String event, void Function(dynamic data) handler) =>
      _handlers[event] = handler;

  @override
  void off(String event) => _handlers.remove(event);

  @override
  void emitWithAck(
    String event,
    Object? data, {
    required void Function(dynamic data) ack,
  }) => ack([true]);

  @override
  void connect() {
    connectCalls++;
    active = true;
  }

  @override
  void disconnect() {
    active = false;
    connected = false;
  }

  @override
  void dispose() => isDisposed = true;

  /// Transport ochildi — kutubxona handshake uchun `auth` so'raydi.
  Future<Map<String, dynamic>> handshake() {
    final sent = Completer<Map<String, dynamic>>();
    _auth(sent.complete);
    return sent.future;
  }

  void serverAccepts() {
    connected = true;
    _handlers['connect']?.call(null);
  }

  /// Server ulanishni yopdi — kutubxona o'zi qayta ulanmaydi.
  void serverDisconnects() {
    connected = false;
    active = false;
    _handlers['disconnect']?.call('io server disconnect');
  }

  /// Tarmoq uzildi — kutubxona o'zi qayta ulanadi (socket faol qoladi).
  void transportDrops() {
    connected = false;
    _handlers['disconnect']?.call('transport close');
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeTokens tokens;
  late List<_FakeSocket> sockets;
  late int refreshes;
  late Future<void> Function() onRefresh;

  SocketClient build({Duration reconnectDelay = Duration.zero}) {
    final client = SocketClient(
      tokenStorage: tokens,
      refreshSession: () async {
        refreshes++;
        await onRefresh();
      },
      socketFactory: (url, auth) {
        final socket = _FakeSocket(auth);
        sockets.add(socket);
        return socket;
      },
      url: 'wss://example.test',
      reconnectDelay: (_) => reconnectDelay,
      clock: () => _now,
    );
    addTearDown(client.dispose);
    return client;
  }

  setUp(() {
    tokens = _FakeTokens();
    sockets = [];
    refreshes = 0;
    onRefresh = () async {};
  });

  test('har (qayta) ulanishda joriy token yuboriladi', () async {
    final client = build();
    final first = _jwt(_now.add(const Duration(minutes: 10)));
    tokens.access = first;

    await client.connect();
    final socket = sockets.single;
    expect(await socket.handshake(), {'token': first});
    socket.serverAccepts();
    expect(client.state, SocketConnectionState.connected);

    // Boshqa isolate tokenni yangiladi, keyin tarmoq uzilib qayta ulandi.
    final rotated = _jwt(_now.add(const Duration(minutes: 15)), sub: 'u1-b');
    tokens.access = rotated;
    socket.transportDrops();
    expect(await socket.handshake(), {'token': rotated});
    expect(refreshes, 0);
  });

  test('eskirgan token handshake\'dan oldin yangilanadi', () async {
    final client = build();
    tokens.access = _jwt(_now.subtract(const Duration(minutes: 1)));
    final fresh = _jwt(_now.add(const Duration(minutes: 15)));
    onRefresh = () async => tokens.access = fresh;

    await client.connect();

    expect(await sockets.single.handshake(), {'token': fresh});
    expect(refreshes, 1);
  });

  test('server uzsa token majburan yangilanib qayta ulanadi', () async {
    final client = build();
    final stale = _jwt(_now.add(const Duration(minutes: 5)));
    final fresh = _jwt(_now.add(const Duration(minutes: 15)), sub: 'u1-b');
    tokens.access = stale;

    await client.connect();
    final socket = sockets.single;
    await socket.handshake();
    socket.serverAccepts();

    onRefresh = () async => tokens.access = fresh;
    socket.serverDisconnects();
    await _settle();

    expect(socket.connectCalls, 2);
    expect(await socket.handshake(), {'token': fresh});
    expect(refreshes, 1);
  });

  test('disconnect qayta ulanishni bekor qiladi', () async {
    final client = build(reconnectDelay: const Duration(milliseconds: 30));
    tokens.access = _jwt(_now.add(const Duration(minutes: 10)));

    await client.connect();
    final socket = sockets.single;
    await socket.handshake();
    socket
      ..serverAccepts()
      ..serverDisconnects();
    client.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(socket.connectCalls, 1);
    expect(socket.isDisposed, isTrue);
    expect(client.state, SocketConnectionState.disconnected);
  });

  test('fondan qaytganda yangi socket bilan ulanadi', () async {
    final client = build();
    tokens.access = _jwt(_now.add(const Duration(minutes: 10)));

    await client.connect();
    await sockets.first.handshake();
    sockets.first.serverAccepts();
    client.disconnect(); // ilova fonga o'tdi

    final later = _jwt(_now.add(const Duration(minutes: 14)), sub: 'later');
    tokens.access = later;
    await client.connect(); // ilova qaytdi

    expect(sockets, hasLength(2));
    expect(await sockets.last.handshake(), {'token': later});
  });

  test(
    'token yo\'q bo\'lsa avval yangilanadi, baribir yo\'q — ulanmaydi',
    () async {
      final client = build();
      tokens.access = null;

      await client.connect();

      expect(refreshes, 1);
      expect(sockets, isEmpty);
    },
  );

  test('event stream qayta ulanishdan keyin ham ishlaydi', () async {
    final client = build();
    tokens.access = _jwt(_now.add(const Duration(minutes: 10)));
    final received = <dynamic>[];
    final sub = client.eventStream('app_limit:updated').listen(received.add);

    await client.connect();
    await sockets.single.handshake();
    sockets.single.serverAccepts();
    sockets.single._handlers['app_limit:updated']?.call({'id': 1});
    await _settle();

    expect(received, [
      {'id': 1},
    ]);
    await sub.cancel();
  });

  test('backoff 2 s dan boshlanib 60 s da to\'xtaydi', () {
    final random = math.Random(1);
    final first = defaultReconnectDelay(0, random);
    final capped = defaultReconnectDelay(20, random);

    expect(first.inMilliseconds, inInclusiveRange(2000, 2500));
    expect(capped.inMilliseconds, inInclusiveRange(60000, 75000));
  });

  test('JWT exp o\'qiladi, buzuq token — null', () {
    final exp = DateTime.utc(2026, 11, 14, 12, 15);

    expect(jwtExpiry(_jwt(exp)), exp);
    expect(jwtExpiry('not-a-jwt'), isNull);
  });
}
