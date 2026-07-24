// ─────────────────────────────────────────────────────────────────────
// ChildRecoveryService — Auth UID orqali eski child hujjat topish
// ─────────────────────────────────────────────────────────────────────
//
// Bola Auth UID'iga bog'langan child document'ni topadi
// (`collectionGroup('children')`). Topilsa Parent UID, child ID va
// ism qaytariladi — caller ularni SharedPreferences'ga saqlab,
// Pairing state'ni "paired" ga ko'taradi.
//
// Talab qilingan Firestore index:
//   Collection group: children
//   Field: linkedDeviceUid (Ascending)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

class RecoveredChildData {
  const RecoveredChildData({
    required this.parentUid,
    required this.childId,
    required this.childName,
  });

  final String parentUid;
  final String childId;
  final String childName;
}

class ChildRecoveryService {
  ChildRecoveryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Auth UID bo'yicha bog'langan bola hujjatini topadi.
  /// Topilmasa `null` qaytaradi — caller oddiy pairing flow'iga o'tadi.
  Future<RecoveredChildData?> findExistingChild(String uid) async {
    try {
      final snap = await _firestore
          .collectionGroup('children')
          .where('linkedDeviceUid', isEqualTo: uid)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        debugPrint('ChildRecovery: uid uchun mos child topilmadi');
        return null;
      }

      final doc = snap.docs.first;
      final data = doc.data();

      // Parent UID document yo'lidan: users/{parentUid}/children/{childId}
      final segments = doc.reference.path.split('/');
      if (segments.length < 4) {
        debugPrint('ChildRecovery: noto\'g\'ri path — ${doc.reference.path}');
        return null;
      }

      final parentUid = segments[1];
      final childId = doc.id;
      final childName =
          data['name'] as String? ?? 'common.fallbackChildName'.tr();

      debugPrint(
        'ChildRecovery: topildi parent=$parentUid, '
        'child=$childId, name=$childName',
      );

      return RecoveredChildData(
        parentUid: parentUid,
        childId: childId,
        childName: childName,
      );
    } catch (e) {
      debugPrint('ChildRecovery xato: $e');
      return null;
    }
  }
}
