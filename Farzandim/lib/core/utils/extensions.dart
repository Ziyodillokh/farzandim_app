// Iterable kengaytmalari — collection paketini import qilmasdan
// foydalanish uchun kichik helper'lar.

/// `Iterable<T>` ga qo'shimcha helper'lar.
extension IterableExtensions<T> on Iterable<T> {
  /// Birinchi mos element'ni qaytaradi, topilmasa `null`.
  ///
  /// Standart `firstWhere` topmasa `StateError` tashlaydi — bu esa
  /// "topilmagan" holatni xatosiz boshqarishga imkon beradi:
  ///
  /// ```dart
  /// final child = children.firstWhereOrNull((c) => c.id == childId);
  /// if (child == null) {
  ///   // bola topilmadi — Dashboard'ga qaytaramiz
  /// }
  /// ```
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
