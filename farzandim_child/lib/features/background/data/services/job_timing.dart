// ─────────────────────────────────────────────────────────────────────
// job_timing — fon ishlarining "muddati keldimi" va backoff mantig'i
// ─────────────────────────────────────────────────────────────────────
//
// MUHIM: devor soati (DateTime.now) ishlatiladi, Stopwatch EMAS. Android'da
// Stopwatch/Timer uyqu (Doze) paytida yurmaydi — telefon 2 soat uxlasa
// "oxirgi heartbeat'dan 1 daqiqa o'tdi" chiqib, 5 daqiqalik tick hech narsa
// yubormasdi. Soat orqaga surilsa (bola sozlamadan o'zgartirsa) — muddat
// keldi deb olinadi, backoff esa bekor bo'ladi (abadiy to'xtab qolmasin).

import 'dart:math' as math;

/// [last] dan beri [interval] o'tdimi (soat orqaga surilgan bo'lsa ham `true`).
bool isDue(DateTime? last, DateTime now, Duration interval) {
  if (last == null) return true;
  final elapsed = now.difference(last);
  return elapsed.isNegative || elapsed >= interval;
}

/// Ketma-ket xatolarda eksponensial kutish: first, 2×first, ... max.
class Backoff {
  Backoff({required this.first, required this.max});

  final Duration first;
  final Duration max;
  int _failures = 0;
  DateTime? _until;

  int get failures => _failures;

  /// Hozir urinish mumkin emasmi.
  bool isBlocked(DateTime now) {
    final until = _until;
    if (until == null) return false;
    // Soat orqaga surilgan — kutish ma'nosiz uzayib ketmasin.
    if (until.difference(now) > max) {
      _until = null;
      return false;
    }
    return now.isBefore(until);
  }

  void fail(DateTime now) {
    _failures++;
    final factor = 1 << math.min(_failures - 1, 20);
    final ms = math.min(max.inMilliseconds, first.inMilliseconds * factor);
    _until = now.add(Duration(milliseconds: ms));
  }

  void reset() {
    _failures = 0;
    _until = null;
  }
}
