// ─────────────────────────────────────────────────────────────────────
// PhotoRequest — ota-onaning foto so'rovi
// ─────────────────────────────────────────────────────────────────────
//
// Firestore strukturasi:
//   photo_requests/{requestId}
//     ├── parentUid: ota UID
//     ├── childId
//     ├── status: 'pending' | 'capturing' | 'completed' | 'declined'
//     ├── requestedAt: serverTimestamp
//     ├── completedAt: serverTimestamp | null
//     └── photoUrl: String | null   ← Storage URL
//
// Child App `pending` statusli so'rovlarga obuna bo'ladi va banner
// ko'rsatadi. Bola tugmani bosgach kamera ochiladi, foto Storage'ga
// yuklanadi va status `completed` ga o'tadi.

import 'package:cloud_firestore/cloud_firestore.dart';

enum PhotoRequestStatus { pending, capturing, completed, declined }

class PhotoRequest {
  final String id;
  final String parentUid;
  final String childId;
  final PhotoRequestStatus status;
  final DateTime? requestedAt;
  final DateTime? completedAt;
  final String? photoUrl;

  const PhotoRequest({
    required this.id,
    required this.parentUid,
    required this.childId,
    required this.status,
    this.requestedAt,
    this.completedAt,
    this.photoUrl,
  });

  /// Backend REST `PhotoRequest` JSON'idan parse (Sprint 4.4.9.4).
  ///
  /// Backend kontract:
  /// ```json
  /// {
  ///   "id": "uuid",
  ///   "parentId": "uuid",
  ///   "childId": "uuid",
  ///   "status": "PENDING|COMPLETED|DECLINED",
  ///   "message": "...",
  ///   "requestedAt": "ISO 8601",
  ///   "completedAt": "ISO 8601" | null,
  ///   "declinedAt": "ISO 8601" | null
  /// }
  /// ```
  factory PhotoRequest.fromBackendJson(Map<String, dynamic> json) {
    final statusStr = (json['status'] as String? ?? 'PENDING').toUpperCase();
    return PhotoRequest(
      id: json['id'] as String? ?? '',
      parentUid: json['parentId'] as String? ?? '',
      childId: json['childId'] as String? ?? '',
      status: _backendStatusToFrontend(statusStr),
      requestedAt: _parseIso(json['requestedAt'] as String?),
      completedAt: _parseIso(json['completedAt'] as String?),
      // photoUrl signed URL alohida endpoint orqali olinadi.
    );
  }

  static PhotoRequestStatus _backendStatusToFrontend(String status) {
    switch (status) {
      case 'COMPLETED':
        return PhotoRequestStatus.completed;
      case 'DECLINED':
        return PhotoRequestStatus.declined;
      case 'PENDING':
      default:
        return PhotoRequestStatus.pending;
    }
  }

  static DateTime? _parseIso(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  factory PhotoRequest.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return PhotoRequest(
      id: id,
      parentUid: data['parentUid'] as String? ?? '',
      childId: data['childId'] as String? ?? '',
      status: _parseStatus(data['status'] as String?),
      requestedAt: data['requestedAt'] != null
          ? (data['requestedAt'] as Timestamp).toDate()
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  static PhotoRequestStatus _parseStatus(String? raw) {
    return switch (raw) {
      'capturing' => PhotoRequestStatus.capturing,
      'completed' => PhotoRequestStatus.completed,
      'declined' => PhotoRequestStatus.declined,
      _ => PhotoRequestStatus.pending,
    };
  }
}
