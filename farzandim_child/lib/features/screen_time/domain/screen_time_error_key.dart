// ─────────────────────────────────────────────────────────────────────
// Ekran vaqti xato kodlari → tarjima kaliti
// ─────────────────────────────────────────────────────────────────────
//
// Bir xil native kod ikki rejimda boshqa ma'noni bildiradi. Masalan
// `invalidAccountType`: kuchli (.child) rejimda — telefon Oila guruhida bola
// akkaunti bilan emas; standart (.individual) rejimda — telefonda Apple
// Account'ga kirilmagan. Standart rejim xatosida "yuqoridagi tugmani
// bosing" deyish o'sha xatoni takrorlatardi.

/// Alohida tarjimasi bor native xato kodlari.
const _knownErrorCodes = {
  'invalidAccountType',
  'authorizationCanceled',
  'restricted',
  'networkError',
  'authenticationMethodUnavailable',
  'authorizationConflict',
};

/// Standart rejimda boshqa matnga ega kodlar.
const _standardModeCodes = {'invalidAccountType'};

/// `screenTime.err.*` tarjima kaliti. [isStrictMode] — xato kuchli (.child)
/// ruxsat so'rovidan kelganmi; boshqa amallar (ilova tanlash va h.k.)
/// uchun `false`.
String screenTimeErrorKey(String code, {bool isStrictMode = false}) {
  if (!_knownErrorCodes.contains(code)) return 'screenTime.err.generic';
  if (!isStrictMode && _standardModeCodes.contains(code)) {
    return 'screenTime.err.${code}Standard';
  }
  return 'screenTime.err.$code';
}
