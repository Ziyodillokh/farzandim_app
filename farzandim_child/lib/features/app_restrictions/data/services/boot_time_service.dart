// ─────────────────────────────────────────────────────────────────────
// BootTimeService — qurilma oxirgi marta yoqilgan (boot) vaqti
// ─────────────────────────────────────────────────────────────────────
//
// NEGA KERAK: HONOR/Huawei kabi Health Connect BO'LMAGAN qurilmalarda qadam
// TYPE_STEP_COUNTER sensoridan olinadi — u "telefon yoqilgandan beri jami"ni
// beradi. Telefon BUGUN yoqilgan bo'lsa bu son AYNAN bugungi qadam (telefon
// o'chiq paytda qadam sanalmaydi). Boot vaqtini bilib, ilova cumulative'ni
// bugungi qadam sifatida ANIQ qabul qiladi — telefondagi son bilan mos keladi.
//
// Boot vaqti = hozirgi vaqt − uptime (SystemClock.elapsedRealtime, deep-sleep
// ham hisoblanadi). Native kanal `MainActivity.kt` da e'lon qilingan.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BootTimeService {
  BootTimeService._();

  static const MethodChannel _channel =
      MethodChannel('farzandim_child/device_clock');

  /// Qurilma oxirgi marta yoqilgan (boot) vaqti. Aniqlab bo'lmasa `null`
  /// (web, kanal yo'q, yoki xato) — chaqiruvchi ehtiyotkor fallback ishlatadi.
  static Future<DateTime?> bootTime() async {
    if (kIsWeb) return null;
    try {
      final uptimeMs = await _channel.invokeMethod<int>('elapsedRealtimeMs');
      if (uptimeMs == null || uptimeMs <= 0) return null;
      return DateTime.now().subtract(Duration(milliseconds: uptimeMs));
    } catch (e) {
      debugPrint('BootTimeService: elapsedRealtime xato: $e');
      return null;
    }
  }
}
