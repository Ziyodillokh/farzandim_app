// ─────────────────────────────────────────────────────────────────────
// SimInfoService — SIM kartadan telefon raqamini o'qish
// ─────────────────────────────────────────────────────────────────────
//
// Pair tugagandan keyin chaqiriladi. Permission so'raydi (READ_PHONE_NUMBERS)
// va native Kotlin tomonidan SIM kartadan raqam o'qiydi. Topgan raqamni
// Firestore'dagi bola hujjatining `phoneNumber` maydoniga yozadi.
//
// Parent App SOS dialog'ining "Qo'ng'iroq" tugmasi shu maydondan o'qib
// `tel:` URI bilan dialer'ni ochadi.
//
// **Cheklov:** O'zbekiston operatorlari odatda raqamni SIM'ga yozadi,
// lekin 100% kafolat yo'q. `null` qaytsa Parent App "kiritilmagan"
// xabarini ko'rsatadi.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class SimInfoService {
  static const _channel = MethodChannel('farzandim/sim_info');

  final FirebaseFirestore _firestore;

  SimInfoService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// SIM kartadan telefon raqamini o'qib Firestore'ga yozadi.
  ///
  /// Quyidagi holatlarda hech narsa qilmaydi (jim chiqadi):
  ///   - Permission rad etilgan
  ///   - SIM raqami yozilmagan (null/bo'sh)
  ///   - Native xato
  ///
  /// Idempotent — bola hujjatida `phoneNumber` allaqachon bor bo'lsa
  /// qaytadan yozmaydi (bandwidth saqlash).
  Future<void> syncPhoneNumberIfNeeded({
    required String parentUid,
    required String childId,
  }) async {
    try {
      // 1. Hozir Firestore'da phoneNumber bormi?
      final doc = await _firestore
          .collection('users')
          .doc(parentUid)
          .collection('children')
          .doc(childId)
          .get();

      final existing = doc.data()?['phoneNumber'] as String?;
      if (existing != null && existing.trim().isNotEmpty) {
        debugPrint('SimInfoService: phoneNumber allaqachon bor ($existing) — skip');
        return;
      }

      // 2. Permission so'rash (READ_PHONE_NUMBERS — Android 8+).
      final status = await Permission.phone.request();
      if (!status.isGranted) {
        debugPrint("SimInfoService: phone permission yo'q ($status)");
        return;
      }

      // 3. Native plugin orqali SIM raqamini o'qish.
      final phone = await _channel.invokeMethod<String?>('getPhoneNumber');
      if (phone == null || phone.trim().isEmpty) {
        debugPrint(
          "SimInfoService: SIM raqami topilmadi (carrier yozmagan)",
        );
        return;
      }

      // 4. Firestore'ga yozish — faqat phoneNumber maydoni.
      await _firestore
          .collection('users')
          .doc(parentUid)
          .collection('children')
          .doc(childId)
          .update({'phoneNumber': phone.trim()});

      debugPrint('SimInfoService: phoneNumber yozildi ($phone)');
    } catch (e) {
      // PlatformException, Firestore xato, va h.k. — barchasi yutiladi.
      // Bu feature critical emas (SOS callButton ishlamasa fallback bor).
      debugPrint('SimInfoService xato: $e');
    }
  }
}
