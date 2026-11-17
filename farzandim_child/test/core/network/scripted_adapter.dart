import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Soxta javob: holat kodi, JSON tana, qo'shimcha sarlavhalar yoki tarmoq
/// xatosi (javobsiz).
class FakeReply {
  const FakeReply(this.status, [this.body, this.headers = const {}])
    : networkError = false;

  const FakeReply.networkError()
    : status = 0,
      body = null,
      headers = const {},
      networkError = true;

  final int status;
  final Object? body;
  final Map<String, String> headers;
  final bool networkError;
}

/// Har so'rovga (async bo'lishi mumkin) [handler] javobini qaytaradi va
/// so'rovlarni (yo'l, Bearer token) yozib boradi.
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.handler);

  final FutureOr<FakeReply> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  List<String> get paths => [for (final r in requests) r.path];

  int countOf(String path) => paths.where((p) => p == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final reply = await handler(options);
    if (reply.networkError) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(reply.body ?? <String, dynamic>{}),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        for (final e in reply.headers.entries) e.key: [e.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// So'rovdagi Bearer token.
String? bearerOf(RequestOptions options) {
  final value = options.headers['Authorization'];
  return value is String && value.startsWith('Bearer ')
      ? value.substring(7)
      : null;
}
