// Maktab kirish nuqtasi (kiosk) QR'ini tanish. Kiosk har 30 soniyada
// `parvoz-school://checkin?code=<token>` ko'rsatadi; token —
// `<base64url>.<base64url>` (imzolangan). Ota-ona ilovasining qayta ulash
// QR'i (`farzandim:repair:`) davomat uchun emas — bolaga alohida aytiladi.

/// Token uzunligi chegarasi (`POST /child/school/check-in`: 1..512 belgi).
const kKioskTokenMaxLength = 512;

const _kioskScheme = 'parvoz-school';
const _kioskHost = 'checkin';
const _pairingPrefix = 'farzandim:repair:';
final _rawTokenPattern = RegExp(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$');

/// Skanerlangan QR turi.
sealed class KioskQr {
  const KioskQr();
}

/// Kiosk kodi — [token] serverga yuboriladi.
final class KioskQrCheckIn extends KioskQr {
  const KioskQrCheckIn(this.token);

  final String token;
}

/// Ota-ona ilovasining qayta ulash QR'i — davomat uchun emas.
final class KioskQrPairing extends KioskQr {
  const KioskQrPairing();
}

/// Tanilmagan QR.
final class KioskQrUnknown extends KioskQr {
  const KioskQrUnknown();
}

/// QR matnini tahlil qilish: avval kiosk havolasi, keyin xom token.
KioskQr parseKioskQr(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return const KioskQrUnknown();
  if (text.toLowerCase().startsWith(_pairingPrefix)) {
    return const KioskQrPairing();
  }
  final token =
      _tokenFromLink(text) ?? (_rawTokenPattern.hasMatch(text) ? text : null);
  if (token == null || token.length > kKioskTokenMaxLength) {
    return const KioskQrUnknown();
  }
  return KioskQrCheckIn(token);
}

/// `parvoz-school://checkin?code=…` dan token (sxema va host katta-kichik
/// harfga sezgir emas). Buzuq foiz-kodlash (`%FF`) — tanilmagan QR.
String? _tokenFromLink(String text) {
  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != _kioskScheme || uri.host != _kioskHost) {
    return null;
  }
  final String? code;
  try {
    code = uri.queryParameters['code']?.trim();
  } on FormatException {
    return null;
  }
  return code == null || code.isEmpty ? null : code;
}
