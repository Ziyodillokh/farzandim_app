// ─────────────────────────────────────────────────────────────────────
// VideoMessage — bola yoki ota-ona yuborgan video xabar (Sprint 4.4.18)
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

/// Video xabar holati.
enum VideoMessageStatus { sent, seen }

/// Parent ↔ Child video xabar (Voice pattern bilan parallel).
@immutable
class VideoMessage {
  /// `VideoMessage` konstruktor.
  const VideoMessage({
    required this.id,
    required this.childId,
    required this.sender,
    required this.durationSeconds,
    required this.status,
    required this.createdAt,
    this.videoUrl = '',
    this.thumbnailUrl,
  });

  /// Backend REST `VideoMessage` JSON'idan parse (Sprint 4.4.18).
  ///
  /// Backend kontract (Prisma `VideoMessage`):
  /// ```json
  /// {
  ///   "id": "uuid",
  ///   "senderId": "uuid",
  ///   "receiverId": "uuid",
  ///   "storagePath": "...",
  ///   "thumbnailPath": null,
  ///   "durationSeconds": 12,
  ///   "isRead": false,
  ///   "createdAt": "ISO 8601"
  /// }
  /// ```
  ///
  /// `sender` UI direction (chap/o'ng bubble) uchun:
  /// - `currentUserId == senderId` → 'parent' (Parent App o'zining)
  /// - boshqa → 'child'
  ///
  /// `childId` UI grouping uchun caller'dan keladi (Backend response'da
  /// child ID alohida emas — sender/receiver based).
  factory VideoMessage.fromBackendJson(
    Map<String, dynamic> json, {
    required String currentUserId,
    required String childId,
  }) {
    final senderId = json['senderId'] as String? ?? '';
    return VideoMessage(
      id: json['id'] as String? ?? '',
      childId: childId,
      sender: senderId == currentUserId ? 'parent' : 'child',
      durationSeconds: (json['durationSeconds'] as int?) ?? 0,
      status: (json['isRead'] as bool? ?? false)
          ? VideoMessageStatus.seen
          : VideoMessageStatus.sent,
      createdAt: _parseIso(json['createdAt'] as String?) ?? DateTime.now(),
    );
  }

  static DateTime? _parseIso(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Backend message ID.
  final String id;

  /// Qaysi bola bilan suhbat (UI grouping).
  final String childId;

  /// 'parent' (o'zi yuborgan) yoki 'child' (boshqa yuborgan).
  final String sender;

  /// Davomiyligi sekundlarda.
  final int durationSeconds;

  /// Ko'rilgan/yangi.
  final VideoMessageStatus status;

  /// Yaratilgan vaqt (local).
  final DateTime createdAt;

  /// Signed URL — lazy fetch (`getFileUrl` chaqirilgach).
  final String videoUrl;

  /// Backend `thumbnailPath` signed URL (kelajakda thumbnail generation).
  final String? thumbnailUrl;

  bool get isOwn => sender == 'parent';
}
