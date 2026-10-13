// ─────────────────────────────────────────────────────────────────────
// localized_date — "13-oktabr" / "October 13" / "13 октября" (joriy tilda)
// ─────────────────────────────────────────────────────────────────────
//
// Avval bir nechta ekranda o'zbekcha oy nomlari ro'yxati qattiq yozilgan
// edi ('yanvar', 'fevral', …) — EN/RU tilida ham o'zbekcha ko'rinardi.
// Endi oy nomlari va kun+oy tartibi tarjima fayllaridan olinadi:
//   common.monthsShort / common.monthsFull — vergul bilan ajratilgan 12 ta
//   common.dayMonth — "{day}-{month}" (uz), "{month} {day}" (en), …

import 'package:easy_localization/easy_localization.dart';

/// Oy nomi (1..12) — [months] vergul bilan ajratilgan 12 ta nom.
/// Ro'yxat noto'g'ri bo'lsa oy raqami qaytadi (ekran buzilmasin).
String monthNameFrom(String months, int month) {
  final names = months.split(',');
  if (month < 1 || month > 12 || names.length != 12) return '$month';
  return names[month - 1].trim();
}

/// Kun + oy joriy tilda: "13-oktabr" / "October 13" / "13 октября".
/// [short] — qisqa oy nomi ("13-okt" / "Oct 13" / "13 окт").
String localizedDayMonth(DateTime date, {bool short = false}) {
  final months = (short ? 'common.monthsShort' : 'common.monthsFull').tr();
  return 'common.dayMonth'.tr(
    namedArgs: {
      'day': '${date.day}',
      'month': monthNameFrom(months, date.month),
    },
  );
}
