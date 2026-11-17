// ─────────────────────────────────────────────────────────────────────
// school_mode_guidance — School Mode eslatmasida qaysi qadam ochiladi
// ─────────────────────────────────────────────────────────────────────
//
// Maktab xodimi "eslatish"ni bosganda (`SCHOOL_MODE_REMIND`, `studentId`)
// ota-onaga push keladi: o'quvchining telefonida dars vaqtidagi tartib
// ishlamayapti (backend `NO_PERMISSION`). Tuzatish yo'li o'quvchi holatiga
// bog'liq:
//   1) o'quvchi mening farzandimga moslanmagan → moslash varag'i;
//   2) farzand bor, lekin bola ilovasi ulanmagan → ulash varag'i;
//   3) ulangan → ruxsat bola telefonida yoqiladi (izoh + bola sozlamalari).
// Sof mantiq — widget'siz, testlanadi.

import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:flutter/foundation.dart';

@immutable
sealed class SchoolModeGuidance {
  const SchoolModeGuidance();

  /// [student] — push'dagi o'quvchi (ro'yxatda yo'q → `null`); [child] —
  /// unga moslangan farzand ilovadagi ro'yxatdan (topilmasa `null`).
  factory SchoolModeGuidance.of({
    required LinkedStudent? student,
    required Child? child,
  }) {
    if (student == null) return const SchoolModeMissing();
    final childId = student.childId;
    if (childId == null) return SchoolModeMatch(student);
    if (child == null || child.pairedAt == null || !child.isConnected) {
      return SchoolModeConnect(
        student: student,
        childId: childId,
        child: child,
      );
    }
    return SchoolModePermission(student: student, child: child);
  }
}

/// O'quvchi endi ro'yxatda yo'q (aloqa uzilgan yoki arxivlangan).
final class SchoolModeMissing extends SchoolModeGuidance {
  const SchoolModeMissing();
}

/// O'quvchi mening farzandimga moslanmagan — moslash varag'i (oilaning
/// boshqa a'zosi moslagan bo'lsa, varaq buni faqat o'qish uchun ko'rsatadi).
final class SchoolModeMatch extends SchoolModeGuidance {
  const SchoolModeMatch(this.student);

  final LinkedStudent student;
}

/// Farzand bor, lekin bola telefoni Parvoz bola ilovasiga ulanmagan.
final class SchoolModeConnect extends SchoolModeGuidance {
  const SchoolModeConnect({
    required this.student,
    required this.childId,
    this.child,
  });

  final LinkedStudent student;
  final String childId;

  /// Ilovadagi ro'yxatda hali bo'lmasa `null` (varaq o'zi kuzatadi).
  final Child? child;
}

/// Bola ilovasi ulangan — ruxsatni bola telefonida yoqish kerak.
final class SchoolModePermission extends SchoolModeGuidance {
  const SchoolModePermission({required this.student, required this.child});

  final LinkedStudent student;
  final Child child;
}
