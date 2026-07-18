// Default avatar tanlash — jinsi + yosh guruhiga qarab 6 ta rasmdan biri.
// Bir joyda (bu funksiya) — Child modeli ham, DON reytingi ham shuni ishlatadi.

import 'package:farzandim/features/child_management/data/models/gender.dart';

/// Jinsi va yoshga mos default avatar rasm yo'li.
///
///   O'G'IL  → yagona `boy.png` (yoshdan qat'i nazar)
///   QIZ     → yoshga qarab:
///               yosh < 10        → girl_6_10
///               10 <= yosh < 14  → girl_10_14
///               yosh >= 14       → girl_14  ("14 va undan katta")
///
/// Yosh 0 (kiritilmagan) yoki 10 dan kichik — eng yosh guruh (6-10).
String defaultAvatarAsset(Gender gender, int age) {
  // O'g'illar uchun yagona default (foydalanuvchi shunday xohlagan).
  if (gender != Gender.female) {
    return 'assets/default_avatars/boy.png';
  }
  final String band;
  if (age >= 14) {
    band = '14';
  } else if (age >= 10) {
    band = '10_14';
  } else {
    band = '6_10';
  }
  return 'assets/default_avatars/girl_$band.png';
}
