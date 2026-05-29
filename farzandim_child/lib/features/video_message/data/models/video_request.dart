// ─────────────────────────────────────────────────────────────────────
// VideoRequest — Parent so'rovi: "video xabar yubor"
// ─────────────────────────────────────────────────────────────────────
//
// Firestore: `video_requests/{id}` — top-level kolleksiya. Parent App
// `pending` statusli hujjat yaratadi `expiresAt` (odatda +5 daq) bilan;
// Child App shu kolleksiyani kuzatib aktiv (pending va expired emas)
// so'rovni Dashboard banner orqali ko'rsatadi.

import 'package:cloud_firestore/cloud_firestore.dart';

class VideoRequest {
  final String id;
  final String parentUid;
  final String childId;
  final String status; // 'pending' | 'recording' | 'completed' | 'cancelled'
  final DateTime requestedAt;
  final DateTime expiresAt;
  final DateTime? completedAt;
  final String? videoMessageId;

  const VideoRequest({
    required this.id,
    required this.parentUid,
    required this.childId,
    required this.status,
    required this.requestedAt,
    required this.expiresAt,
    this.completedAt,
    this.videoMessageId,
  });

  bool get isPending => status == 'pending';
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive => isPending && !isExpired;

  factory VideoRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return VideoRequest(
      id: doc.id,
      parentUid: data['parentUid'] as String? ?? '',
      childId: data['childId'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      requestedAt: (data['requestedAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      videoMessageId: data['videoMessageId'] as String?,
    );
  }
}
