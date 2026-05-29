// ─────────────────────────────────────────────────────────────────────
// ScheduleRepository — Child App'da jadvallarni o'qish (read-only)
// ─────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:farzandim_child/features/schedules/data/models/schedule.dart';

class ScheduleRepository {
  ScheduleRepository({
    required FirebaseFirestore firestore,
    required String parentUid,
    required String childId,
  })  : _firestore = firestore,
        _parentUid = parentUid,
        _childId = childId;

  final FirebaseFirestore _firestore;
  final String _parentUid;
  final String _childId;

  CollectionReference<Map<String, dynamic>> get _ref => _firestore
      .collection('users')
      .doc(_parentUid)
      .collection('children')
      .doc(_childId)
      .collection('schedules');

  /// Faqat aktiv jadvallar, vaqt bo'yicha sortlangan.
  Stream<List<Schedule>> streamActiveSchedules() {
    return _ref
        .where('isActive', isEqualTo: true)
        .orderBy('startHour')
        .orderBy('startMinute')
        .snapshots()
        .map((snap) => snap.docs.map(Schedule.fromFirestore).toList());
  }
}
