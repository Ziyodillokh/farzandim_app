// ─────────────────────────────────────────────────────────────────────
// VideoCapture — dumaloq video yozish uchun platforma-mustaqil interfeys
// ─────────────────────────────────────────────────────────────────────
//
// Web: brauzer native getUserMedia + MediaRecorder (video_capture_web.dart).
// Telefon: `camera` paketi (video_capture_io.dart). Ikkalasi ham `stop()`
// dan eshittiriladigan manba qaytaradi (web: blob URL, qurilma: fayl yo'li).

import 'package:flutter/widgets.dart';

/// Video yozish boshqaruvchisi (platforma implementatsiyalari amalga oshiradi).
abstract class VideoCapture {
  /// Kamera tayyor bo'ldimi (preview ko'rsatish mumkinmi).
  bool get isReady;

  /// Kamerani ishga tushiradi (ruxsat so'raydi). Xato bo'lsa exception otadi.
  Future<void> init();

  /// Jonli kamera preview widgeti (dumaloq quti ichida ko'rsatiladi).
  Widget preview();

  /// Yozishni boshlaydi.
  Future<void> start();

  /// Yozishni to'xtatadi va manbani qaytaradi (web: blob URL, qurilma: yo'l).
  Future<String?> stop();

  /// Yozishni bekor qiladi (natija saqlanmaydi).
  Future<void> cancel();

  /// Resurslarni bo'shatadi.
  Future<void> dispose();
}
