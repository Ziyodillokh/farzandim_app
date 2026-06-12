// ─────────────────────────────────────────────────────────────────────
// SupportMessagesRepository — support chat xabarlari (Telegram ko'prigi)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   GET  /api/support/messages  → { messages: [...] }  (oxirgi 200, eski→yangi)
//   POST /api/support/messages  → { message, ack? }
//     body: { text? , attachmentKey?, attachmentType?, fileName?, fileSize?,
//             mimeType? }
//
// Server xabari user yozganini operatorlar Telegram GURUHIGA yetkazadi;
// operator javobi shu tarixda `sender: "operator"` bo'lib keladi (ilova
// 10s polling bilan o'qiydi). `isAutoAck` — "tez orada javob beramiz"
// avto-javobi: klient uni o'z tilida ko'rsatadi (textKey).

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/features/support/data/models/support_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supportMessagesRepositoryProvider =
    Provider<SupportMessagesRepository>((ref) {
  return SupportMessagesRepository(ref.watch(dioClientProvider));
});

class SupportMessagesRepository {
  SupportMessagesRepository(this._dio);

  final Dio _dio;

  /// Suhbat tarixi (eskidan yangiga).
  Future<List<SupportMessage>> list() async {
    final res = await _dio.get<Map<String, dynamic>>('/support/messages');
    final raw = res.data?['messages'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SupportMessage.fromServer)
        .toList();
  }

  /// Xabar yuborish. Qaytadi: (server xabari, avto-ack yoki null).
  Future<({SupportMessage message, SupportMessage? ack})> send({
    String? text,
    String? attachmentKey,
    String? attachmentType,
    String? fileName,
    int? fileSize,
    String? mimeType,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/support/messages',
      data: <String, dynamic>{
        if (text != null && text.isNotEmpty) 'text': text,
        if (attachmentKey != null) 'attachmentKey': attachmentKey,
        if (attachmentType != null) 'attachmentType': attachmentType,
        if (fileName != null) 'fileName': fileName,
        if (fileSize != null) 'fileSize': fileSize,
        if (mimeType != null) 'mimeType': mimeType,
      },
    );
    final data = res.data ?? const <String, dynamic>{};
    final msg = SupportMessage.fromServer(
      (data['message'] as Map<String, dynamic>?) ?? const {},
    );
    final ackRaw = data['ack'];
    final ack = ackRaw is Map<String, dynamic>
        ? SupportMessage.fromServer(ackRaw)
        : null;
    return (message: msg, ack: ack);
  }
}
