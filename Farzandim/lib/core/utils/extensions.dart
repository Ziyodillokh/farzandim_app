// Iterable kengaytmalari — collection paketini import qilmasdan
// foydalanish uchun kichik helper'lar.

extension IterableExtensions<T> on Iterable<T> {
  /// Birinchi mos elementni qaytaradi, topilmasa `null` —
  /// standart `firstWhere` esa topmasa `StateError` tashlaydi.
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
