// ─────────────────────────────────────────────────────────────────────
// FaroMascot — FARO maskot widget (character sheet'dan kerakli pozani
// ─────────────────────────────────────────────────────────────────────
//
// Asset: `assets/mascot/faro_character_sheet.png` (1122x1402)
// Tarkib:
//   - Chap 55%: to'liq tana (asosiy poza, qo'l silkitish)
//   - O'ng 45%: 4 ta yuz variant (idle / excited / sad / sleeping)
//
// Bizning widget character sheet'dan kerakli qismni `ClipRect` +
// `Align` orqali "ajratib oladi" — alohida fayllar talab qilmaydi.
//
// Foydalanish:
//   FaroMascot(variant: FaroVariant.body, size: 200)  // to'liq tana
//   FaroMascot(variant: FaroVariant.faceIdle, size: 120)  // faqat yuz

import 'package:flutter/material.dart';

enum FaroVariant {
  /// To'liq tana (chap qism — asosiy poza).
  body,

  /// Yuz: oddiy jilmayish (idle).
  faceIdle,

  /// Yuz: hayajon (excited, sparkle eyes).
  faceExcited,

  /// Yuz: g'amgin (sad, warning).
  faceSad,

  /// Yuz: uxlab yotgan (sleeping, Zzz).
  faceSleeping,
}

class FaroMascot extends StatelessWidget {
  const FaroMascot({
    this.variant = FaroVariant.body,
    this.size = 160,
    super.key,
  });

  final FaroVariant variant;
  final double size;

  /// Character sheet o'lchamlari (PNG asl).
  static const double _sheetWidth = 1122;
  static const double _sheetHeight = 1402;

  /// Asset path.
  static const String _path = 'assets/mascot/faro_character_sheet.png';

  /// Har variant uchun:
  ///   - `viewWidth` — ko'rinadigan qism kengligi (% sheet'dan)
  ///   - `viewHeight` — ko'rinadigan qism balandligi (% sheet'dan)
  ///   - `xPercent` — chap-o'ng pozitsiya (0.0 chap, 1.0 o'ng)
  ///   - `yPercent` — yuqori-past pozitsiya
  _CropSpec _spec() {
    switch (variant) {
      case FaroVariant.body:
        // Chap yarmi, full height
        return const _CropSpec(
          widthFactor: 0.55,
          heightFactor: 1.0,
          alignment: Alignment.centerLeft,
        );
      case FaroVariant.faceIdle:
        // O'ng yuqori (1/4)
        return const _CropSpec(
          widthFactor: 0.30,
          heightFactor: 0.22,
          alignment: Alignment(0.85, -0.92), // o'ng yuqori
        );
      case FaroVariant.faceExcited:
        // O'ng 2-quarter
        return const _CropSpec(
          widthFactor: 0.30,
          heightFactor: 0.22,
          alignment: Alignment(0.85, -0.32),
        );
      case FaroVariant.faceSad:
        // O'ng 3-quarter
        return const _CropSpec(
          widthFactor: 0.30,
          heightFactor: 0.22,
          alignment: Alignment(0.85, 0.32),
        );
      case FaroVariant.faceSleeping:
        // O'ng pastki
        return const _CropSpec(
          widthFactor: 0.30,
          heightFactor: 0.22,
          alignment: Alignment(0.85, 0.92),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec();
    // Aspect ratio: character sheet 1122:1402 ≈ 0.8 width per height
    // To'liq tana qismi: 617:1402 ≈ 0.44 aspect ratio.
    // Yuz qismi: 337:308 ≈ 1.1 aspect ratio.
    final aspectRatio = variant == FaroVariant.body
        ? (_sheetWidth * spec.widthFactor) / _sheetHeight
        : (_sheetWidth * spec.widthFactor) / (_sheetHeight * spec.heightFactor);

    return SizedBox(
      width: aspectRatio < 1 ? size * aspectRatio : size,
      height: aspectRatio < 1 ? size : size / aspectRatio,
      child: ClipRect(
        child: Align(
          alignment: spec.alignment,
          widthFactor: spec.widthFactor,
          heightFactor: spec.heightFactor,
          child: Image.asset(
            _path,
            // Image kerakli scale'da chiziladi — sheet'ning to'liq
            // o'lchami uchun (clip qiladigan qism widget size'iga sig'sin).
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _CropSpec {
  const _CropSpec({
    required this.widthFactor,
    required this.heightFactor,
    required this.alignment,
  });

  final double widthFactor;
  final double heightFactor;
  final Alignment alignment;
}
