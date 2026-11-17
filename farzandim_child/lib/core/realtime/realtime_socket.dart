// ─────────────────────────────────────────────────────────────────────
// RealtimeSocket — socket.io ulanishining yupqa yuzasi (testda soxtasi)
// ─────────────────────────────────────────────────────────────────────
//
// `SocketClient` faqat shu interfeysni biladi: haqiqiy ilovada
// `socket_io_client` adapteri, testlarda soxta socket (handshake, server
// uzishi va qayta ulanishni simulyatsiya qilish uchun).

import 'package:socket_io_client/socket_io_client.dart' as io;

/// Har (qayta) ulanishda handshake `auth` ma'lumotini so'raydi —
/// [send] ga `{'token': ...}` beriladi (eskirgan JWT yuborilmasin).
typedef SocketAuthProvider =
    void Function(void Function(Map<String, dynamic> auth) send);

/// [url] ga ulanadigan socket (avtomatik ulanmaydi — `connect()` kutadi).
typedef RealtimeSocketFactory =
    RealtimeSocket Function(String url, SocketAuthProvider auth);

abstract interface class RealtimeSocket {
  bool get connected;

  /// `false` — server uzgan (`io server disconnect`) yoki biz yopganmiz:
  /// kutubxona o'zi qayta ulanmaydi.
  bool get active;

  String? get id;

  void on(String event, void Function(dynamic data) handler);
  void off(String event);
  void emitWithAck(
    String event,
    Object? data, {
    required void Function(dynamic data) ack,
  });
  void connect();
  void disconnect();
  void dispose();
}

/// Kutubxona qayta ulanish oralig'i: 2 s dan 60 s gacha, cheksiz urinish
/// (ilova ekranda bo'lgan paytda; fonda socket umuman yopiq).
const _kReconnectDelayMs = 2000;
const _kReconnectDelayMaxMs = 60000;

RealtimeSocket createIoSocket(String url, SocketAuthProvider auth) {
  final options = io.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .enableForceNew()
      .setAuthFn(auth)
      .setReconnectionDelay(_kReconnectDelayMs)
      .setReconnectionDelayMax(_kReconnectDelayMaxMs)
      .build();
  return _IoRealtimeSocket(io.io(url, options));
}

class _IoRealtimeSocket implements RealtimeSocket {
  _IoRealtimeSocket(this._socket);

  final io.Socket _socket;

  @override
  bool get connected => _socket.connected;

  @override
  bool get active => _socket.active;

  @override
  String? get id => _socket.id;

  @override
  void on(String event, void Function(dynamic data) handler) =>
      _socket.on(event, handler);

  @override
  void off(String event) => _socket.off(event);

  @override
  void emitWithAck(
    String event,
    Object? data, {
    required void Function(dynamic data) ack,
  }) => _socket.emitWithAck(event, data, ack: ack);

  @override
  void connect() => _socket.connect();

  @override
  void disconnect() => _socket.disconnect();

  @override
  void dispose() => _socket.dispose();
}
