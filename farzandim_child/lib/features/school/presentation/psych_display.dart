// Psixologik testlarni ko'rsatish qoidalari: test turi nomi va belgisi,
// LIKERT yorliqlari, teskari sanoq va ro'yxatdagi qisqa ma'lumot qatori.
// Sof funksiyalar — widget'siz testlanadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/core/utils/tashkent_time.dart';
import 'package:farzandim_child/features/school/domain/psych_answer.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:flutter/widgets.dart';
import 'package:solar_icons/solar_icons.dart';

/// Test turi nomi — `school.psych.kinds.<name>`.
String psychKindLabelKey(PsychKind kind) => 'school.psych.kinds.${kind.name}';

/// Test turi belgisi.
IconData psychKindIcon(PsychKind kind) => switch (kind) {
  PsychKind.cognitive => SolarIconsOutline.lightbulb,
  PsychKind.attention => SolarIconsOutline.eye,
  PsychKind.emotional => SolarIconsOutline.heartPulse,
  PsychKind.selfEsteem => SolarIconsOutline.starFall,
  PsychKind.career => SolarIconsOutline.target,
  PsychKind.social => SolarIconsOutline.usersGroupRounded,
  PsychKind.iq => SolarIconsOutline.lightbulb,
  PsychKind.custom || PsychKind.unknown => SolarIconsOutline.clipboardList,
};

/// LIKERT bahosi (1 hech qachon … 5 doim) — `school.psych.likert.<n>`.
String likertLabelKey(int value) => 'school.psych.likert.$value';

/// LIKERT shkalasi qiymatlari (1..5).
List<int> get likertValues => [
  for (var v = kLikertMin; v <= kLikertMax; v++) v,
];

/// Teskari sanoq: "09:41" (soat bo'lsa "1:05:00"). Soniyalar yuqoriga
/// yaxlitlanadi — boshida "10:00" ko'rinadi, "00:00" esa vaqt tugaganda.
String formatCountdown(Duration left) {
  final ms = left.inMilliseconds;
  final total = ms <= 0 ? 0 : (ms + 999) ~/ 1000;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

/// Oxirgi kun (Toshkent vaqtida). Yarim tunda yopilsa ("26-oktabr 00:00")
/// — oldingi kun: bola "25-oktabrgacha" deb ko'radi.
DateTime psychLastDay(DateTime closesAt) {
  final local = toTashkent(closesAt);
  final isMidnight = local.hour == 0 && local.minute == 0;
  return isMidnight ? local.subtract(const Duration(minutes: 1)) : local;
}

/// Ro'yxatdagi qisqa ma'lumot: "12 ta savol · 10 daqiqa · 25-oktabrgacha".
String psychMetaLine(PsychAssignmentSummary assignment) {
  final minutes = assignment.timeLimitMin;
  final closesAt = assignment.closesAt;
  return [
    if (assignment.itemCount > 0) 'home.questions'.plural(assignment.itemCount),
    if (minutes != null)
      'school.psych.minutes'.tr(namedArgs: {'count': '$minutes'}),
    if (closesAt != null)
      'school.psych.until'.tr(
        namedArgs: {'date': localizedDayMonth(psychLastDay(closesAt))},
      ),
  ].join(' · ');
}
