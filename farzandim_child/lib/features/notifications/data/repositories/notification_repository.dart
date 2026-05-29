// ─────────────────────────────────────────────────────────────────────
// NotificationRepository — Firestore CRUD bildirishnoma uchun
// ─────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farzandim_child/features/notifications/data/models/app_notification.dart';

class NotificationRepository {
  NotificationRepository({
    FirebaseFirestore? firestore,
    required this.parentUid,
    required this.childId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String parentUid;
  final String childId;

  CollectionReference<Map<String, dynamic>> get _ref => _firestore
      .collection('users')
      .doc(parentUid)
      .collection('children')
      .doc(childId)
      .collection('notifications');

  /// Yangi → eski tartibida real-time stream.
  Stream<List<AppNotification>> stream({int limit = 100}) {
    return _ref
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(AppNotification.fromFirestore).toList());
  }

  /// O'qilmagan bildirishnomalar soni (badge uchun).
  Stream<int> unreadCountStream() {
    return _ref
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size);
  }

  /// O'qilgan deb belgilash.
  Future<void> markAsRead(String notificationId) async {
    await _ref.doc(notificationId).update({'isRead': true});
  }

  /// Hammasini o'qilgan deb belgilash.
  Future<void> markAllAsRead() async {
    final unread = await _ref.where('isRead', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// O'chirish.
  Future<void> delete(String notificationId) async {
    await _ref.doc(notificationId).delete();
  }

  /// Yangi bildirishnoma yaratish (achievement unlock, system event'lar uchun).
  Future<String> create(AppNotification notification) async {
    final docRef = await _ref.add(notification.toFirestore());
    return docRef.id;
  }
}
