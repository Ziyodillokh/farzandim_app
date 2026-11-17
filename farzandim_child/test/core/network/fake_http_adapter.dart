import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Har so'rovga [handler] javobini qaytaradi va yo'llarni yozib boradi.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  final (int, Object?) Function(RequestOptions options) handler;
  final List<String> requestedPaths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    final (status, body) = handler(options);
    return ResponseBody.fromString(
      jsonEncode(body ?? <String, dynamic>{}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
