// ─────────────────────────────────────────────────────────────────────
// tashkent_time — Toshkent (UTC+5, DST yo'q) vaqt yordamchilari (ARCH-08)
// ─────────────────────────────────────────────────────────────────────
//
// "Bugun" tushunchasi loyihada Toshkent kuni bilan hisoblanadi (backend
// ham shunday). Avval `DateTime.now().toUtc().add(Duration(hours: 5))`
// 4 joyda dublikat edi — endi bitta util.

/// Toshkent (UTC+5) bo'yicha "hozir".
DateTime tashkentNow() => DateTime.now().toUtc().add(const Duration(hours: 5));

/// Toshkent bugungi sanasi "YYYY-MM-DD" (backend kun-kaliti formati).
String tashkentTodayStr() {
  final t = tashkentNow();
  return '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}
