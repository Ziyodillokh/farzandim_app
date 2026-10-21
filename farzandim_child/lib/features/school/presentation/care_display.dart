// "Bola ovozi" ko'rsatish qoidalari: so'rovnoma shkalasi, murojaat
// mavzulari va holatlari, Toshkent vaqtidagi sana-vaqt va eng yaqin suhbat.
// Sof funksiyalar — widget'siz testlanadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/core/utils/tashkent_time.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/presentation/school_style.dart';
import 'package:flutter/widgets.dart';
import 'package:solar_icons/solar_icons.dart';

/// So'rovnoma shkalasi (1..5) belgilari — oy "to'lib boradi": "yo'q"dan
/// "ha, juda"gacha. Kayfiyat yuzlari ATAYIN ishlatilmaydi: teskari savollarda
/// ("seni ranjitishdimi?") yuqori javob yomon holatni bildiradi, server uni
/// o'zi aylantiradi — yuz esa bolani teskari javobga undardi.
const kSurveyScaleEmoji = ['🌑', '🌒', '🌓', '🌔', '🌕'];

/// So'rovnoma shkalasi qiymatlari (1..5).
List<int> get surveyScaleValues => [
  for (var v = kSurveyScoreMin; v <= kSurveyScoreMax; v++) v,
];

/// Shkala belgisi (1..5).
String surveyScaleEmoji(int value) =>
    kSurveyScaleEmoji[(value - kSurveyScoreMin).clamp(
      0,
      kSurveyScaleEmoji.length - 1,
    )];

/// Shkala yorlig'i — `school.survey.scale.<n>`.
String surveyScaleLabelKey(int value) => 'school.survey.scale.$value';

/// Murojaat yuborishda tanlanadigan mavzular (panel tartibida).
List<CareTopic> get selectableCareTopics =>
    CareTopic.values.where((t) => t != CareTopic.unknown).toList();

/// Mavzu nomi — `school.requests.topics.<name>`.
String careTopicLabelKey(CareTopic topic) =>
    'school.requests.topics.${topic.name}';

/// Mavzu belgisi.
IconData careTopicIcon(CareTopic topic) => switch (topic) {
  CareTopic.learning => SolarIconsOutline.notebookMinimalistic,
  CareTopic.peers => SolarIconsOutline.usersGroupRounded,
  CareTopic.bullying => SolarIconsOutline.shieldUser,
  CareTopic.family => SolarIconsOutline.homeSmile,
  CareTopic.emotions => SolarIconsOutline.heartPulse,
  CareTopic.safety => SolarIconsOutline.shieldCheck,
  CareTopic.other || CareTopic.unknown => SolarIconsOutline.chatRoundDots,
};

/// Murojaat holati nomi — `school.requests.status.<name>`.
String careStatusLabelKey(CareRequestStatus status) =>
    'school.requests.status.${status.name}';

/// Murojaat holati rangi.
Color careStatusColor(CareRequestStatus status) => switch (status) {
  CareRequestStatus.sent => HomeColors.blue,
  CareRequestStatus.inProgress => HomeColors.amber,
  CareRequestStatus.scheduled => SchoolColors.accent,
  CareRequestStatus.resolved || CareRequestStatus.unknown => HomeColors.textDim,
};

/// "21-oktabr, 14:00" — Toshkent vaqtida (qurilma zonasidan qat'i nazar).
String tashkentDateTime(DateTime instant) {
  final local = toTashkent(instant);
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return 'school.requests.dateTime'.tr(
    namedArgs: {'date': localizedDayMonth(local), 'time': '$hh:$mm'},
  );
}

/// Eng yaqin (hali o'tmagan) belgilangan suhbat — `null`: yo'q.
CareRequest? nextMeeting(List<CareRequest> requests, DateTime now) {
  CareRequest? soonest;
  for (final request in requests) {
    final at = request.meetingAt;
    if (request.status != CareRequestStatus.scheduled || at == null) continue;
    if (at.isBefore(now)) continue;
    final best = soonest?.meetingAt;
    if (best == null || at.isBefore(best)) soonest = request;
  }
  return soonest;
}
