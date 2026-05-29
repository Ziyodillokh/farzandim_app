// ─────────────────────────────────────────────────────────────────────
// VideoMessageService — video xabar Storage yuklash + Firestore yozish
// ─────────────────────────────────────────────────────────────────────
//
// Storage path: `video_messages/{parentUid}/{childId}/{timestamp}.mp4`
// Firestore: `video_messages/{messageId}` — top-level kolleksiya.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:farzandim_child/features/video_message/data/models/video_message.dart';

class VideoMessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Video faylni Storage'ga yuklaydi va Firestore'ga metadata yozadi.
  /// `onProgress` 0.0 — 1.0 oralig'idagi qiymatlarni emit qiladi.
  /// Qaytadi: yangi yaratilgan `video_messages/{id}` hujjat ID'si.
  Future<String> sendVideoMessage({
    required String parentUid,
    required String childId,
    required String childName,
    required File videoFile,
    required int durationSeconds,
    required void Function(double progress) onProgress,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'video_messages/$parentUid/$childId/$timestamp.mp4';
    final ref = _storage.ref(path);

    final uploadTask = ref.putFile(
      videoFile,
      SettableMetadata(contentType: 'video/mp4'),
    );

    uploadTask.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });

    final snapshot = await uploadTask.whenComplete(() {});
    final url = await snapshot.ref.getDownloadURL();

    final message = VideoMessage(
      parentUid: parentUid,
      childId: childId,
      childName: childName,
      videoUrl: url,
      durationSeconds: durationSeconds,
    );

    final docRef = await _firestore
        .collection('video_messages')
        .add(message.toFirestore());

    return docRef.id;
  }

  /// Bola yuborgan oxirgi video xabar (eng yangisi). Dashboard'da
  /// "Oxirgi video: X daq oldin" indikatori uchun.
  ///
  /// `parentUid` filter SHART: Firestore rules `isMember(parentUid, childId)`
  /// talab qiladi.
  Stream<VideoMessage?> latestForChild({
    required String parentUid,
    required String childId,
  }) {
    return _firestore
        .collection('video_messages')
        .where('parentUid', isEqualTo: parentUid)
        .where('childId', isEqualTo: childId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      final data = doc.data();
      return VideoMessage(
        id: doc.id,
        parentUid: data['parentUid'] as String? ?? '',
        childId: data['childId'] as String? ?? '',
        childName: data['childName'] as String? ?? '',
        videoUrl: data['videoUrl'] as String? ?? '',
        durationSeconds: data['durationSeconds'] as int? ?? 0,
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
    });
  }
}
