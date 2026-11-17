// ─────────────────────────────────────────────────────────────────────
// KelajakSupport — qo'llab-quvvatlash signali (ota-ona ko'rinishi)
// ─────────────────────────────────────────────────────────────────────
//
// Backend (`ParentSupportView`): faqat `watch` yoki `support`; `none` →
// `null`. Raqam ham, savol ham YO'Q — faqat soha (wellbeing / safety),
// sana va ehtiyotkor maslahat matni ("Bu tashxis emas...").

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_text.dart';
import 'package:flutter/foundation.dart';

/// Signal darajasi: bitta tashvishli javob (`watch`) yoki bir nechta
/// (`support`).
enum KelajakSupportLevel {
  watch,
  support;

  /// `none`, noma'lum yoki yo'q → `null` (karta ko'rsatilmaydi).
  static KelajakSupportLevel? fromApi(Object? raw) => switch (raw) {
    'watch' => watch,
    'support' => support,
    _ => null,
  };
}

/// Signal sohasi (`wellbeing` — "Ruhiy farovonlik va stress").
@immutable
class KelajakSupportArea {
  const KelajakSupportArea({required this.key, required this.name});

  factory KelajakSupportArea.fromJson(Map<String, dynamic> json) =>
      KelajakSupportArea(
        key: requireKelajakString(json, 'key'),
        name: requireKelajakText(json, 'name'),
      );

  final String key;
  final LocalizedText name;
}

@immutable
class KelajakSupport {
  const KelajakSupport({
    required this.level,
    required this.areas,
    this.day,
    this.guidance,
  });

  /// Signal yo'q yoki darajasi noma'lum → `null`.
  static KelajakSupport? tryParse(Object? raw) {
    final json = asJsonMap(raw);
    if (json == null) return null;
    final level = KelajakSupportLevel.fromApi(json['level']);
    if (level == null) return null;
    return KelajakSupport(
      level: level,
      areas: readKelajakList(json, 'areas', KelajakSupportArea.fromJson),
      day: json.readStringOrNull('day'),
      guidance: readKelajakText(json, 'guidance'),
    );
  }

  final KelajakSupportLevel level;
  final List<KelajakSupportArea> areas;

  /// Shu darajaga olib kelgan eng so'nggi sessiya kuni ("YYYY-MM-DD").
  final String? day;

  /// Backend maslahati; yo'q bo'lsa ilova o'z matnini ko'rsatadi.
  final LocalizedText? guidance;
}
