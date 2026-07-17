// ─────────────────────────────────────────────────────────────────────
// TestDifficulty — test qiyinlik darajasi (Oson / O'rta / Qiyin)
// ─────────────────────────────────────────────────────────────────────
//
// Bola "Konkurs shartlari" sheet'da tanlaydi. Genuine ta'sir: har savol
// uchun beriladigan VAQT (Oson ko'proq, Qiyin kamroq — quiz timeri shundan).
// Savollar soni va sovrin testning o'zgarmas qiymatlari (halol ko'rsatiladi).
//
// Kartadagi kichik yorliq (inherentDifficulty) — savollar sonidan olinadi
// (backend darajani bermaydi), faqat ma'lumot uchun; sheet default shu.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

enum TestDifficulty { oson, orta, qiyin }

extension TestDifficultyX on TestDifficulty {
  String get label => switch (this) {
    TestDifficulty.oson => 'contests.difficultyEasy'.tr(),
    TestDifficulty.orta => 'contests.difficultyMedium'.tr(),
    TestDifficulty.qiyin => 'contests.difficultyHard'.tr(),
  };

  /// Yorliq rangi — yashil / amber / qizil.
  Color get color => switch (this) {
    TestDifficulty.oson => const Color(0xFF41DD7A),
    TestDifficulty.orta => const Color(0xFFFFAE00),
    TestDifficulty.qiyin => const Color(0xFFFF5A6E),
  };

  /// Har savol uchun soniya — quiz timeri shu qiymatni ishlatadi.
  int get secondsPerQuestion => switch (this) {
    TestDifficulty.oson => 50,
    TestDifficulty.orta => 40,
    TestDifficulty.qiyin => 30,
  };
}

/// Testning "tabiiy" darajasi — savollar sonidan (backend daraja bermaydi).
/// Kartadagi yorliq va sheet'ning boshlang'ich tanlovi shundan.
TestDifficulty inherentDifficulty(int savollarSoni) {
  if (savollarSoni > 0 && savollarSoni <= 15) return TestDifficulty.oson;
  if (savollarSoni <= 28) return TestDifficulty.orta;
  return TestDifficulty.qiyin;
}
