// "Kelajagim" UI matnlari: server matni (`LocalizedText`) joriy tilda, xato
// kodi va bugungi holat → tarjima kalitlari, savollar soni / vaqt qatori.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_error.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_overview.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:flutter/widgets.dart';

extension KelajakLocalized on LocalizedText {
  /// Joriy ilova tilidagi matn (yo'q bo'lsa — o'zbekchasi).
  String inLocale(BuildContext context) => of(context.locale.languageCode);
}

/// Xato kodi (boshqa istisno — `unknown`).
KelajakErrorCode kelajakCodeOf(Object? error) =>
    error is KelajakException ? error.code : KelajakErrorCode.unknown;

/// Xato matni kaliti (`kelajak.errors.network` …).
String kelajakErrorKey(KelajakErrorCode code) => 'kelajak.errors.${code.name}';

/// Testning bugungi holati — UI uchun uch xil.
enum KelajakDayState {
  /// Hali javob berilmagan (yangi yoki ochilgan, javobsiz).
  fresh,

  /// Javob berish boshlangan, yakunlanmagan.
  unfinished,

  /// Bugun yakunlangan.
  done,
}

/// Noma'lum holat — `null` (belgi ko'rsatilmaydi).
KelajakDayState? kelajakDayStateOf(KelajakToday today) =>
    switch (today.status) {
      KelajakTodayStatus.notStarted ||
      KelajakTodayStatus.started => KelajakDayState.fresh,
      KelajakTodayStatus.inProgress => KelajakDayState.unfinished,
      KelajakTodayStatus.completed => KelajakDayState.done,
      KelajakTodayStatus.unknown => null,
    };

/// Holat belgisi: "Yangi" / "Davom etmoqda" / "Bajarildi".
String kelajakStatusKey(KelajakDayState state) => switch (state) {
  KelajakDayState.fresh => 'kelajak.status.new',
  KelajakDayState.unfinished => 'kelajak.status.inProgress',
  KelajakDayState.done => 'kelajak.status.completed',
};

/// Tugma: "Boshlash" / "Davom etish" / "Natijani ko'rish".
String kelajakActionKey(KelajakDayState? state) => switch (state) {
  KelajakDayState.unfinished => 'kelajak.action.continue',
  KelajakDayState.done => 'kelajak.action.result',
  KelajakDayState.fresh || null => 'kelajak.action.start',
};

/// "10 ta savol · 3 daqiqa" (soni noma'lum bo'lsa — qismi tushiriladi).
String kelajakTestMeta(KelajakTestInfo test) => [
  if (test.questionCount > 0)
    'kelajak.questions'.tr(namedArgs: {'count': '${test.questionCount}'}),
  if (test.estimatedMinutes > 0)
    'kelajak.minutes'.tr(namedArgs: {'count': '${test.estimatedMinutes}'}),
].join(' · ');

/// Yosh guruhi `10-12` → `10–12`.
String kelajakAgeGroupLabel(String group) => group.replaceAll('-', '–');

/// "11 yosh · savollar 10–12 yoshlar uchun" (`null` — yosh noma'lum).
String? kelajakAgeLine(KelajakAge age) {
  final years = age.age;
  final group = age.ageGroup;
  if (!age.isOk || years == null || group == null) return null;
  return 'kelajak.age.line'.tr(
    namedArgs: {'age': '$years', 'group': kelajakAgeGroupLabel(group)},
  );
}
