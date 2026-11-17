// ─────────────────────────────────────────────────────────────────────
// RecoveryRequest — bolaning "parolni unutdim" so'rovi
// ─────────────────────────────────────────────────────────────────────
//
// Backend: GET /api/children/:childId/recovery-requests (ochiq so'rovlar).
// Element: { id, channel: 'PARENT'|'SCHOOL', status: 'RECEIVED'|'RESTORED'|
// 'REJECTED', createdAt, ... }. Javob shakli shartnomada qat'iy yozilmagan:
// to'g'ridan-to'g'ri massiv yoki `{ requests | items: [...] }` ham
// qabul qilinadi. Parse hech qachon otmaydi; id'siz element tashlanadi.

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:flutter/foundation.dart';

/// So'rov qaysi kanalga yuborilgan.
enum RecoveryChannel {
  parent,
  school,
  unknown;

  static RecoveryChannel fromApi(Object? raw) => switch (raw) {
    'PARENT' => parent,
    'SCHOOL' => school,
    _ => unknown,
  };
}

/// So'rov holati: qabul qilingan (ochiq), tiklangan yoki rad etilgan.
enum RecoveryStatus {
  received,
  restored,
  rejected,
  unknown;

  static RecoveryStatus fromApi(Object? raw) => switch (raw) {
    'RECEIVED' => received,
    'RESTORED' => restored,
    'REJECTED' => rejected,
    _ => unknown,
  };
}

@immutable
class RecoveryRequest {
  const RecoveryRequest({
    required this.id,
    required this.channel,
    required this.status,
    this.createdAt,
  });

  /// Element JSON'i; `id` yo'q bo'lsa `null`.
  static RecoveryRequest? tryParse(Map<String, dynamic> json) {
    final id = json.readStringOrNull('id');
    if (id == null) return null;
    return RecoveryRequest(
      id: id,
      channel: RecoveryChannel.fromApi(json['channel']),
      status: RecoveryStatus.fromApi(json['status']),
      createdAt: json.readDateTime('createdAt'),
    );
  }

  final String id;
  final RecoveryChannel channel;
  final RecoveryStatus status;
  final DateTime? createdAt;

  /// Hali hal qilinmagan (ota-ona javobini kutmoqda).
  bool get isOpen => status == RecoveryStatus.received;

  @override
  bool operator ==(Object other) =>
      other is RecoveryRequest &&
      other.id == id &&
      other.channel == channel &&
      other.status == status &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, channel, status, createdAt);

  @override
  String toString() => 'RecoveryRequest($id, ${channel.name}, ${status.name})';
}

/// Ro'yxat javobini o'qiydi (massiv yoki `{requests|items: [...]}`);
/// yangisi birinchi. Noto'g'ri shakl → bo'sh ro'yxat.
List<RecoveryRequest> parseRecoveryRequests(Object? raw) {
  final list = switch (raw) {
    final List<dynamic> items => items,
    final Map<dynamic, dynamic> map => switch (map['requests'] ??
        map['items']) {
      final List<dynamic> items => items,
      _ => const <dynamic>[],
    },
    _ => const <dynamic>[],
  };
  // Yangi so'rov tepada; sanasi noma'lumlar oxirida.
  final parsed = [
    for (final item in list)
      if (asJsonMap(item) case final json?)
        if (RecoveryRequest.tryParse(json) case final request?) request,
  ]..sort(_newestFirst);
  return List.unmodifiable(parsed);
}

int _newestFirst(RecoveryRequest a, RecoveryRequest b) {
  final x = a.createdAt;
  final y = b.createdAt;
  if (x == null && y == null) return 0;
  if (x == null) return 1;
  if (y == null) return -1;
  return y.compareTo(x);
}
