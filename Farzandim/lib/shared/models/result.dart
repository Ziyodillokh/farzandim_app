/// Operatsiya natijasi — muvaffaqiyat (`data`) yoki xato (`error`).
///
/// Notifier metodlari shu turni qaytaradi. Chaqiruvchi ekran natijani
/// to'g'ridan-to'g'ri oladi — `ref.read(provider)` orqali umumiy state'ni
/// qayta o'qish (TOCTOU + ekranlararo state oqishi) kerak emas.
class Result<T> {
  /// Muvaffaqiyatli natija. `data` ixtiyoriy (void operatsiyalar uchun null).
  const Result.success([this.data]) : error = null;

  /// Xato natija — `message` bo'sh bo'lmagan xato xabari.
  const Result.failure(String this.error) : data = null;

  /// Muvaffaqiyatli natija qiymati (`failure` da `null`).
  final T? data;

  /// Xato xabari (`success` da `null`).
  final String? error;

  /// Operatsiya muvaffaqiyatli tugadimi.
  bool get isSuccess => error == null;
}
