// ─────────────────────────────────────────────────────────────────────
// ChildRepository — bola profili Firestore + Storage operatsiyalari
// ─────────────────────────────────────────────────────────────────────
//
// AccountEditScreen ushbu repodan foydalanadi:
//   - updateChildProfile() — name/age/region/photoUrl yangilash
//   - uploadChildPhoto()   — foto Storage'ga yuklab URL qaytarish

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChildRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Bola hujjatining tanlangan maydonlarini yangilash. `null` qiymatlar
  /// payloadga qo'shilmaydi — qisman update.
  Future<void> updateChildProfile({
    required String parentUid,
    required String childId,
    String? name,
    int? age,
    String? region,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) updates['name'] = name;
    if (age != null) updates['age'] = age;
    if (region != null) updates['region'] = region;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    await _firestore
        .collection('users')
        .doc(parentUid)
        .collection('children')
        .doc(childId)
        .update(updates);
  }

  /// Foto Firebase Storage'ga yuklanadi va download URL qaytariladi.
  /// Path: users/{parentUid}/children/{childId}/profile.jpg
  ///
  /// `bytes` ishlatiladi (File emas) — bu web va mobile'da bir xil
  /// ishlaydi. ImagePicker.readAsBytes() ikkala platformada xfile'dan
  /// Uint8List qaytaradi. putData() web/mobile uchun universal.
  Future<String> uploadChildPhoto({
    required String parentUid,
    required String childId,
    required Uint8List bytes,
  }) async {
    final ref = _storage
        .ref()
        .child('users/$parentUid/children/$childId/profile.jpg');

    final uploadTask = ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final snapshot = await uploadTask.whenComplete(() {});
    return snapshot.ref.getDownloadURL();
  }
}
