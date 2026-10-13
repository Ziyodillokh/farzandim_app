// ─────────────────────────────────────────────────────────────────────
// ranking_name_privacy — umumiy reytingda BOSHQA bolalar shaxsini yashirish
// ─────────────────────────────────────────────────────────────────────
//
// Butun O'zbekiston bo'yicha DON reytingida boshqa bolalarning to'liq ismi
// va rasmi ko'rsatilmaydi: faqat ism + familiya bosh harfi ("Akmal T.") va
// bosh harfli avatar. Backend ham ismni niqoblaydi, lekin UI bunga
// tayanmaydi — shu yerda ham qayta niqoblanadi.
//
// Bola ism maydoniga telefon raqami yoki @handle yozib qo'ygan bo'lsa,
// harf bo'lmagan belgilar olib tashlanadi; birorta harf qolmasa `null`
// qaytadi (UI neytral "Ishtirokchi" yorlig'ini ko'rsatadi).

/// Ism qismida ruxsat etilgan belgilar: harflar + o'zbekcha apostroflar
/// (G'ayrat, O'g'iloy) + defis.
final RegExp _disallowedChars = RegExp(r"[^\p{L}'ʻʼ‘’`\-]", unicode: true);
final RegExp _letter = RegExp(r'\p{L}', unicode: true);
final RegExp _whitespace = RegExp(r'\s+');

/// Ko'rsatiladigan ismning maksimal uzunligi (uzun "ism" orqali xabar
/// yozib bo'lmasin).
const int kMaxMaskedFirstNameLength = 16;

/// Ism qismlarini tozalaydi: faqat kamida bitta harfi bor qismlar qoladi.
List<String> _cleanParts(String raw) => raw
    .trim()
    .split(_whitespace)
    .map((p) => p.replaceAll(_disallowedChars, ''))
    .where((p) => _letter.hasMatch(p))
    .toList(growable: false);

/// "Akmal Toshmatov" → "Akmal T.", "Akmal" → "Akmal".
///
/// Harf bo'lmagan belgilar (raqam, @, + va h.k.) olib tashlanadi. Hech
/// qanday harf qolmasa `null` (masalan, ism o'rniga telefon raqami).
String? maskRankingName(String raw) {
  final parts = _cleanParts(raw);
  if (parts.isEmpty) return null;
  final first = parts.first;
  final firstName = first.length > kMaxMaskedFirstNameLength
      ? first.substring(0, kMaxMaskedFirstNameLength)
      : first;
  if (parts.length < 2) return firstName;
  final initial = _letter.firstMatch(parts[1])?.group(0);
  if (initial == null) return firstName;
  return '$firstName ${initial.toUpperCase()}.';
}

/// Avatar uchun bosh harflar: "Akmal T." → "AT", "Akmal" → "A", "" → "?".
String rankingInitials(String name) {
  final letters = _cleanParts(name)
      .take(2)
      .map((p) => _letter.firstMatch(p)?.group(0) ?? '')
      .where((l) => l.isNotEmpty)
      .map((l) => l.toUpperCase())
      .join();
  return letters.isEmpty ? '?' : letters;
}
