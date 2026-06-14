// ─────────────────────────────────────────────────────────────────────
// AiMessage — Faro AI hamroh suhbat xabari (#64/#65)
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

@immutable
class AiMessage {
  const AiMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.flagged,
    required this.createdAt,
  });

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'assistant',
      text: json['text'] as String? ?? '',
      flagged: json['flagged'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')
              ?.toLocal() ??
          DateTime.now(),
    );
  }

  /// Optimistik (yuborilayotgan) bola xabari uchun lokal konstruktor.
  factory AiMessage.localUser(String text) {
    return AiMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      role: 'user',
      text: text,
      flagged: false,
      createdAt: DateTime.now(),
    );
  }

  final String id;

  /// 'user' (bola) | 'assistant' (Faro).
  final String role;
  final String text;

  /// Xavfsizlik filtri ishladimi.
  final bool flagged;
  final DateTime createdAt;

  bool get isUser => role == 'user';
}
