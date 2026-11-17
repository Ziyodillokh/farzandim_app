// ─────────────────────────────────────────────────────────────────────
// BackgroundTelemetry — fon ishlaridagi kutilmagan xatolar hisoboti
// ─────────────────────────────────────────────────────────────────────
//
// Fon servislari (cheklov sync'i, heartbeat, o'yin xabari...) xatolarni o'zi
// ushlaydi — release'da debugPrint jim, shuning uchun "ba'zan ishlamay
// qoladi" holatini hech qayerda ko'rib bo'lmasdi. FGS isolate (Crashlytics
// sozlangach) shu ilgakni o'rnatadi; boshqa joyda u no-op.
//
// Faqat KUTILMAGAN xatolar uchun (TypeError, PlatformException...). Tarmoq
// uzilishi oddiy holat — repository'lar uni `null` bilan qaytaradi.

import 'package:flutter/foundation.dart';

typedef BackgroundErrorReporter =
    void Function(Object error, StackTrace stack, String where);

abstract final class BackgroundTelemetry {
  static BackgroundErrorReporter? _reporter;

  /// FGS isolate (ChildBackgroundTaskHandler) Crashlytics bilan o'rnatadi.
  static set reporter(BackgroundErrorReporter? reporter) =>
      _reporter = reporter;

  static void report(Object error, StackTrace stack, String where) {
    debugPrint('[$where] xato: $error');
    final reporter = _reporter;
    if (reporter == null) return;
    try {
      reporter(error, stack, where);
    } catch (_) {
      // Hisobot xatosi ishni buzmasin.
    }
  }
}
