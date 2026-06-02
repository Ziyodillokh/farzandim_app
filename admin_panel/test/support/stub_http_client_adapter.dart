import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Deterministic [HttpClientAdapter] for Dio unit tests (no real network).
final class StubHttpClientAdapter implements HttpClientAdapter {
  StubHttpClientAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      _handler(options);
}
