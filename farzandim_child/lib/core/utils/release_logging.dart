// ─────────────────────────────────────────────────────────────────────
// Release log'lari — maxfiy ma'lumot qurilma jurnaliga yozilmasin
// ─────────────────────────────────────────────────────────────────────
//
// Release build'da `debugPrint` iOS unified log / Android logcat'ga yozadi —
// Console yoki sysdiagnose orqali o'qish mumkin. Bolalar ilovasida
// koordinata, token yoki so'rov/javob tanasi u yerga tushmasligi kerak.
// Har isolate o'z `debugPrint`iga ega — shuning uchun har bir kirish
// nuqtasida (main, fon servisi, FCM fon handler) chaqiriladi.

import 'package:flutter/foundation.dart';

void silenceDebugPrintInRelease() {
  if (!kReleaseMode) return;
  debugPrint = (String? message, {int? wrapWidth}) {};
}
