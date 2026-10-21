// Avtomatik yangilashni siyraklashtirish: davriy taymer har safar emas,
// oxirgi yangilashdan [RefreshThrottle.interval] o'tgach so'raydi.
// Foydalanuvchi boshlagan yangilash (ilovaga qaytish) — har doim.

class RefreshThrottle {
  /// Yaratilgan payt — birinchi yuklash (ekran ochilishi) hisoblanadi.
  RefreshThrottle(this.interval, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _last = _clock();
  }

  final Duration interval;
  final DateTime Function() _clock;
  late DateTime _last;

  /// Yangilash kerakmi; `true` bo'lsa shu payt oxirgi yangilash bo'ladi.
  /// [force] — oraliqdan qat'i nazar (ilovaga qaytish).
  bool shouldRun({bool force = false}) {
    final now = _clock();
    if (!force && now.difference(_last) < interval) return false;
    _last = now;
    return true;
  }
}
