// ─────────────────────────────────────────────────────────────────────
// VideoMessage — bola yoki ota-ona yuborgan yumaloq video xabar
// ─────────────────────────────────────────────────────────────────────
//
// Eski: Firestore `video_messages/{messageId}` — Parent App barcha
// bolalar uchun bitta query'da kuzatadi.
// Yangi (Sprint 4.4.18 child port): Backend REST + WS. `fromBackendJson`
// orqali Backend JSON'idan parse, `sender` field UI direction uchun
// ('parent' kelgan/'child' yuborgan — chap/o'ng bubble).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum VideoMessageStatus { uploading, sent, seen, failed }

@immutable
class VideoMessage {
  /// `VideoMessage` konstruktor.
  const VideoMessage({
    this.id,
    required this.parentUid,
    required this.childId,
    required this.childName,
    required this.videoUrl,
    required this.durationSeconds,
    this.sender = 'child',
    this.status = VideoMessageStatus.sent,
    this.createdAt,
    this.seenAt,
    this.thumbnailUrl,
  });

  /// Firestore (legacy) modelidan parse.
  factory VideoMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return VideoMessage(
      id: doc.id,
      parentUid: data['parentUid'] as String? ?? '',
      childId: data['childId'] as String? ?? '',
      childName: data['childName'] as String? ?? '',
      videoUrl: data['videoUrl'] as String? ?? '',
      durationSeconds: data['durationSeconds'] as int? ?? 0,
      sender: data['sender'] as String? ?? 'child',
      status: VideoMessageStatus.values.firstWhere(
        (s) => s.name == (data['status'] as String?),
        orElse: () => VideoMessageStatus.sent,
      ),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      seenAt: data['seenAt'] != null
          ? (data['seenAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Backend REST `VideoMessage` JSON'idan parse (Sprint 4.4.18 child).
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
  /// `sender` UI direction:
  /// - `currentUserId == senderId` → 'child' (Child App o'zining yuborgan)
  /// - boshqa → 'parent' (Parent App'dan kelgan)
  factory VideoMessage.fromBackendJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final senderId = json['senderId'] as String? ?? '';
    return VideoMessage(
      id: json['id'] as String? ?? '',
      parentUid: '',
      childId: '',
      childName: '',
      videoUrl: '', // Lazy signed URL fetch
      durationSeconds: (json['durationSeconds'] as int?) ?? 0,
      sender: senderId == currentUserId ? 'child' : 'parent',
      status: (json['isRead'] as bool? ?? false)
          ? VideoMessageStatus.seen
          : VideoMessageStatus.sent,
      createdAt: _parseBackendIso(json['createdAt'] as String?),
    );
  }

  static DateTime? _parseBackendIso(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      // Backend ISO 8601 UTC → local (Tashkent UTC+5).
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Backend message ID (Firestore'da DocumentSnapshot.id).
  final String? id;

  /// Legacy Firestore field (Backend mode'da bo'sh).
  final String parentUid;

  /// Legacy Firestore field (Backend mode'da bo'sh).
  final String childId;

  /// Legacy Firestore field (Backend mode'da bo'sh).
  final String childName;

  /// Signed URL — Backend `getFileUrl` chaqirilgach to'ldiriladi.
  final String videoUrl;

  /// Davomiyligi sekundlarda.
  final int durationSeconds;

  /// 'child' (o'zi yuborgan) yoki 'parent' (boshqa yuborgan) — UI direction.
  final String sender;

  /// Ko'rilgan/yangi/upload statusi.
  final VideoMessageStatus status;

  /// Yaratilgan vaqt (local).
  final DateTime? createdAt;

  /// Ko'rilgan vaqt (Firestore legacy).
  final DateTime? seenAt;

  /// Backend `thumbnailPath` signed URL (kelajakda thumbnail generation).
  final String? thumbnailUrl;

  bool get isOwn => sender == 'child';

  /// Firestore upload uchun (legacy code paths uchun saqlab qolingan).
  Map<String, dynamic> toFirestore() {
    return {
      'parentUid': parentUid,
      'childId': childId,
      'childName': childName,
      'videoUrl': videoUrl,
      'durationSeconds': durationSeconds,
      'sender': sender,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
