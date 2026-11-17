// Repository testlari uchun soxta HTTP qatlam: haqiqiy Dio (interceptor va
// JSON dekodlash bilan) ishlaydi, faqat tarmoq o'rniga [FakeHttpAdapter]
// oldindan berilgan javobni qaytaradi va so'rovlarni yozib oladi.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Soxta javob: status + JSON tana (`String` — xom matn, masalan HTML).
class FakeReply {
  const FakeReply(this.status, [this.body]);

  /// Javob umuman kelmaydi (internet yo'q).
  const FakeReply.offline() : status = 0, body = null;

  final int status;
  final Object? body;

  bool get isOffline => status == 0;
}

class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this._handler);

  final FakeReply Function(RequestOptions options) _handler;

  /// Yuborilgan so'rovlar (tartib bilan).
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final reply = _handler(options);
    if (reply.isOffline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final body = reply.body;
    final isRaw = body is String;
    return ResponseBody.fromString(
      switch (body) {
        null => '',
        final String text => text,
        _ => jsonEncode(body),
      },
      reply.status,
      headers: {
        Headers.contentTypeHeader: [
          if (isRaw) 'text/html' else Headers.jsonContentType,
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Ilovadagi kabi sozlangan Dio (faqat 2xx muvaffaqiyat).
Dio fakeDio(FakeHttpAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://api.test/api'))
      ..httpClientAdapter = adapter;
