// ─────────────────────────────────────────────────────────────────────
// InviteCode — maktab taklif kodi: 6 xonali o'quvchi kodi yoki 8 belgili
// vasiy kodi
// ─────────────────────────────────────────────────────────────────────
//
// Ikkala kod ham bitta `POST /parent/school/link` ga ketadi (turini backend
// o'zi ajratadi):
//   - 6 xonali RAQAMLI o'quvchi kodi (24 soat; bosh nol bo'lishi mumkin:
//     "042913" — shuning uchun kod HECH QACHON songa aylantirilmaydi);
//   - 8 belgili vasiy kodi `[A-Z0-9]{8}` (7 kun).
// Bo'shliq va `-` olib tashlanadi, katta harfga o'tkaziladi. Panel QR'i
// `https://farzandimedu.uz/link?code=…` ni kodlaydi — skaner shu `code`
// parametrini o'qiydi yoki xom kodni oladi. Telefon kamerasi bilan
// skanerlangan havola Android'da ilovani `/link?code=` yo'li bilan ochadi
// (`fromLinkParam`).

/// Skanerlangan taklif: `code` va u Parvoz havolasidan olinganmi (`fromLink`).
typedef ScannedInvite = ({String code, bool fromLink});

/// Taklif kodi bilan ishlash (normallashtirish, tekshirish, QR).
abstract final class InviteCode {
  /// 8 belgili vasiy kodi uzunligi (ajratuvchilarsiz).
  static const int length = 8;

  /// 6 xonali o'quvchi kodi uzunligi.
  static const int studentLength = 6;

  static final RegExp _guardianPattern = RegExp(r'^[A-Z0-9]{8}$');
  static final RegExp _studentPattern = RegExp(r'^[0-9]{6}$');
  static final RegExp _digits = RegExp(r'^[0-9]+$');
  static final RegExp _plain = RegExp(r'^[A-Z0-9]*$');
  static final RegExp _hasDigit = RegExp('[0-9]');
  static final RegExp _separators = RegExp(r'[\s-]');

  /// Matn ichidagi kod. Qo'shni harf/raqam bo'lsa — kod emas (uzun raqam,
  /// oddiy so'z). Turlari:
  ///   - 6 raqam: "042913" yoki "042 913";
  ///   - raqami bor 8 belgi: "ABCD-2345" (chiziqcha yoki bo'shliq bilan ham);
  ///   - HARF-FAQAT 8 belgi (taxminan 10% kod): "ABCD-EFGH" yoki yopishgan
  ///     "ABCDEFGH". Kod alifbosida I va O yo'q (backend:
  ///     ABCDEFGHJKLMNPQRSTUVWXYZ23456789), shuning uchun "TOSHKENT" kabi
  ///     so'zlar kod hisoblanmaydi; yopishgan variant faqat BOSH harflarda
  ///     ("Assalomu" kabi oddiy so'z emas), chiziqchali variant har qanday
  ///     registrda.
  static final RegExp _studentInText = RegExp(
    r'(?<![A-Za-z0-9])[0-9]{3}[-\s]?[0-9]{3}(?![A-Za-z0-9])',
  );
  static final RegExp _guardianInText = RegExp(
    r'(?<![A-Za-z0-9])[A-Za-z0-9]{4}[-\s]?[A-Za-z0-9]{4}(?![A-Za-z0-9])',
  );
  static final RegExp _guardianLettersDashed = RegExp(
    '(?<![A-Za-z0-9])[A-HJ-NP-Za-hj-np-z]{4}-[A-HJ-NP-Za-hj-np-z]{4}'
    '(?![A-Za-z0-9])',
  );
  static final RegExp _guardianLettersUpper = RegExp(
    '(?<![A-Za-z0-9])[A-HJ-NP-Z]{8}(?![A-Za-z0-9])',
  );

  /// QR havolasi qabul qilinadigan saytlar (tasodifiy QR'lar rad etiladi).
  /// `parvoz.uz` — eski chop etilgan QR'lar uchun (domen hozircha ochilmaydi).
  static const Set<String> _linkHosts = {
    'farzandimedu.uz',
    'www.farzandimedu.uz',
    'parvoz.uz',
    'www.parvoz.uz',
  };

  /// Bo'shliq va `-` olib tashlanadi, katta harfga o'tkaziladi.
  static String normalize(String raw) =>
      raw.replaceAll(_separators, '').toUpperCase();

  /// Normallashtirilgan kod 6 xonali o'quvchi kodimi (`[0-9]{6}`).
  static bool isStudentCode(String raw) =>
      _studentPattern.hasMatch(normalize(raw));

  /// Normallashtirilgan kod 8 belgili vasiy kodimi (`[A-Z0-9]{8}`).
  static bool isGuardianCode(String raw) =>
      _guardianPattern.hasMatch(normalize(raw));

  /// Ikki xil koddan biriga mosmi.
  static bool isValid(String raw) => isStudentCode(raw) || isGuardianCode(raw);

  /// Kiritilgan matn bo'sh yoki faqat raqamlardan iborat — raqamli
  /// klaviatura qulay (harf paydo bo'lsa, harfli klaviatura kerak).
  static bool isNumericInput(String raw) {
    final code = normalize(raw);
    return code.isEmpty || _digits.hasMatch(code);
  }

  /// Ko'rsatish uchun: raqamli kod (≤ 6 raqam) bo'linmaydi ("042913"),
  /// qolgani "XXXX-XXXX" (to'liq bo'lmasa ham bo'lib yoziladi).
  static String format(String raw) {
    final code = normalize(raw);
    if (code.length <= studentLength && _digits.hasMatch(code)) return code;
    const half = length ~/ 2;
    if (code.length <= half) return code;
    return '${code.substring(0, half)}-${code.substring(half)}';
  }

  /// Yopishtirilgan matn "kod"ning o'ziga o'xshamaydimi (ortiqcha so'z yoki
  /// belgilar bor) — shunda undan kod qidiriladi.
  static bool looksLikeMessage(String raw) {
    final code = normalize(raw);
    return code.length > length || !_plain.hasMatch(code);
  }

  /// Matn ichidan kod qidiradi (masalan "Maktab kodi: 042 913. Muddati 24
  /// soat" yoki "Kod: ABCD-EFGH"): birinchi uchragan 6 raqam yoki 8 belgili
  /// kod (turlari [_studentInText] izohida). Atrofdagi so'zlar e'tiborga
  /// olinmaydi. Topilmasa `null`.
  static String? extract(String text) {
    final found = <({int start, String code})>[
      for (final match in _studentInText.allMatches(text))
        (start: match.start, code: normalize(match.group(0)!)),
      for (final match in _guardianInText.allMatches(text))
        if (_hasDigit.hasMatch(match.group(0)!))
          (start: match.start, code: normalize(match.group(0)!)),
      for (final match in _guardianLettersDashed.allMatches(text))
        (start: match.start, code: normalize(match.group(0)!)),
      for (final match in _guardianLettersUpper.allMatches(text))
        (start: match.start, code: normalize(match.group(0)!)),
    ];
    if (found.isEmpty) return null;
    found.sort((a, b) => a.start.compareTo(b.start));
    return found.first.code;
  }

  /// Skanerlangan QR: kod (normallashtirilgan) va u Parvoz HAVOLASIDAN
  /// olinganmi. Havola (`https://farzandimedu.uz/link?code=…`) — panel chiqargan
  /// ishonchli QR: kod darrov yuboriladi. Xom kod esa istalgan begona QR
  /// bo'lishi mumkin (6 raqamli chipta, mahsulot kodi...): u faqat maydonga
  /// yoziladi, yuborishni ota-ona tasdiqlaydi — tasodifiy kod noto'g'ri
  /// urinishlar limitini sarflamasin. Yaroqsiz yoki begona QR → `null`.
  static ScannedInvite? parseScan(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (isValid(text)) return (code: normalize(text), fromLink: false);
    final uri = Uri.tryParse(text);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return null;
    }
    if (!_linkHosts.contains(uri.host.toLowerCase())) return null;
    final code = _queryCode(uri);
    if (code == null || !isValid(code)) return null;
    return (code: normalize(code), fromLink: true);
  }

  /// Skanerlangan QR matnidan kod (havola yoki xom). [parseScan] ning
  /// qisqartmasi: havoladan olinganmi — bilinmaydi.
  static String? fromScan(String raw) => parseScan(raw)?.code;

  /// Deep link `/link?code=…` qiymati: normallashtirilgan to'g'ri kod yoki
  /// `null` (bo'sh, yaroqsiz yoki boshqa narsa).
  static String? fromLinkParam(String? raw) {
    if (raw == null) return null;
    final code = normalize(raw.trim());
    return isValid(code) ? code : null;
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
