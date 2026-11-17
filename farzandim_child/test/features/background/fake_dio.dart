// Test yordamchisi: so'rovlarni yozib boradigan soxta Dio (tarmoqsiz).

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class RecordedRequest {
  RecordedRequest(this.method, this.path, this.data);

  final String method;
  final String path;
  final Object? data;

  Map<String, dynamic> get json => (data as Map).cast<String, dynamic>();
}

class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter([this.respond]);

  /// (status, body) — standart: 200 va bo'sh obyekt.
  (int, Object?) Function(RequestOptions options)? respond;
  final List<RecordedRequest> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(RecordedRequest(options.method, options.path, options.data));
    final (status, body) = respond?.call(options) ?? (200, null);
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

(Dio, RecordingAdapter) recordingDio([
  (int, Object?) Function(RequestOptions options)? respond,
]) {
  final adapter = RecordingAdapter(respond);
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
    ..httpClientAdapter = adapter;
  return (dio, adapter);
}
