/// Polling loop'lari uchun oddiy xato-backoff (PERF).
///
/// Muammo: barcha poller'lar qat'iy 30s/60s kadansda xatoni yutib qayta
/// uraveradi — backend qisman yotganda ("brownout") 100k klient hech
/// qanday yengillik bermaydi.
///
/// Yechim: ketma-ket xatolarda keyingi 1..4 tick tashlab yuboriladi
/// (60s poll → xatolar davom etsa amalda 5 daqiqagacha siyraklashadi),
/// birinchi muvaffaqiyat odatdagi kadansni qaytaradi.
///
/// Ishlatish (poll loop ichida):
/// ```dart
/// final backoff = PollBackoff();
/// await for (...) {
///   if (backoff.shouldSkipTick) continue;
///   try { ...; backoff.onSuccess(); } catch (_) { backoff.onFailure(); }
/// }
/// ```
class PollBackoff {
  int _failStreak = 0;
  int _skipLeft = 0;

  /// Shu tick tashlab yuborilsinmi (oldingi xatolar evaziga).
  /// Chaqiruvning o'zi skip-hisoblagichni kamaytiradi.
  bool get shouldSkipTick {
    if (_skipLeft > 0) {
      _skipLeft--;
      return true;
    }
    return false;
  }

  /// Muvaffaqiyatli so'rov — odatdagi kadans qaytadi.
  void onSuccess() => _failStreak = 0;

  /// Xato — keyingi `min(streak, 4)` tick tashlab yuboriladi.
  void onFailure() {
    _failStreak++;
    _skipLeft = _failStreak.clamp(1, 4);
  }
}
