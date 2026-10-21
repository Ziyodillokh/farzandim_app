// ─────────────────────────────────────────────────────────────────────
// InviteCode — maktab taklif kodi (8 belgi, 7 kun amal qiladi)
// ─────────────────────────────────────────────────────────────────────
//
// Backend bilan bir xil qoida (`students.schemas.ts` redeemSchema):
// bo'shliq va `-` olib tashlanadi, katta harfga o'tkaziladi, natija
// `[A-Z0-9]{8}`. Panel QR'i `https://parvoz.uz/link?code=XXXXXXXX` ni
// kodlaydi — skaner shu `code` parametrini o'qiydi yoki xom kodni oladi.

/// Taklif kodi bilan ishlash (normallashtirish, tekshirish, QR).
abstract final class InviteCode {
  /// Kod uzunligi (ajratuvchilarsiz).
  static const int length = 8;

  static final RegExp _pattern = RegExp(r'^[A-Z0-9]{8}$');
  static final RegExp _separators = RegExp(r'[\s-]');

  /// QR havolasi qabul qilinadigan saytlar (tasodifiy QR'lar rad etiladi).
  static const Set<String> _linkHosts = {
    'parvoz.uz',
    'www.parvoz.uz',
    'farzandimedu.uz',
    'www.farzandimedu.uz',
  };

  /// Bo'shliq va `-` olib tashlanadi, katta harfga o'tkaziladi.
  static String normalize(String raw) =>
      raw.replaceAll(_separators, '').toUpperCase();

  /// Normallashtirilgan kod `[A-Z0-9]{8}` ga mosmi.
  static bool isValid(String raw) => _pattern.hasMatch(normalize(raw));

  /// Ko'rsatish uchun "XXXX-XXXX" (to'liq bo'lmasa ham bo'lib yoziladi).
  static String format(String raw) {
    final code = normalize(raw);
    const half = length ~/ 2;
    if (code.length <= half) return code;
    return '${code.substring(0, half)}-${code.substring(half)}';
  }

  /// Skanerlangan QR matnidan kod: Parvoz havolasidagi `?code=` yoki xom
  /// kod. Yaroqsiz yoki begona QR → `null`.
  static String? fromScan(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (isValid(text)) return normalize(text);
    final uri = Uri.tryParse(text);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return null;
    }
    if (!_linkHosts.contains(uri.host.toLowerCase())) return null;
    final code = _queryCode(uri);
    if (code == null || !isValid(code)) return null;
    return normalize(code);
  }

  /// `?code=` qiymati; buzuq percent-kodlashda → `null`.
  static String? _queryCode(Uri uri) {
    try {
      return uri.queryParameters['code'];
    } on FormatException {
      return null;
    }
  }
}
