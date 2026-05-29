// ─────────────────────────────────────────────────────────────────────
// VideoRequestRepository — Parent video so'rovlari Firestore CRUD
// ─────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:farzandim_child/features/video_message/data/models/video_request.dart';

class VideoRequestRepository {
  VideoRequestRepository({
    required FirebaseFirestore firestore,
    required String parentUid,
    required String childId,
  })  : _firestore = firestore,
        _parentUid = parentUid,
        _childId = childId;

  final FirebaseFirestore _firestore;
  final String _parentUid;
  final String _childId;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('video_requests');

  /// Aktiv (pending va expired emas) so'rov stream — eng yangisi.
  Stream<VideoRequest?> streamActiveRequest() {
    return _ref
        .where('parentUid', isEqualTo: _parentUid)
        .where('childId', isEqualTo: _childId)
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final request = VideoRequest.fromFirestore(snap.docs.first);
      return request.isExpired ? null : request;
    });
  }

  /// So'rovni 'recording' holatga (Bola yozish ekraniga o'tdi).
  Future<void> markAsRecording(String requestId) {
    return _ref.doc(requestId).update({'status': 'recording'});
  }

  /// So'rovni 'completed' holatga + linked `videoMessageId`.
  Future<void> markAsCompleted({
    required String requestId,
    required String videoMessageId,
  }) {
    return _ref.doc(requestId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'videoMessageId': videoMessageId,
    });
  }

  /// So'rovni 'cancelled' holatga (bola rad etganda).
  Future<void> markAsCancelled(String requestId) {
    return _ref.doc(requestId).update({'status': 'cancelled'});
  }
}
