// Bola ovozi ekranlari uchun umumiy matnlar: ish vaqti, murojaat sarlavhasi
// va bosqich yorlig'i.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_models.dart';

/// «Dushanba–juma · 09:00–17:00» / «Du, Ch, Ju · 09:00–13:00».
String voiceHoursLabel(VoiceHours hours) {
  final days = hours.days;
  final contiguous =
      days.length > 1 && days.last - days.first == days.length - 1;
  final dayText = switch (days.length) {
    1 => 'g5.voice.weekdays.${days.first}'.tr(),
    _ when contiguous =>
      '${'g5.voice.weekdays.${days.first}'.tr()}–${'g5.voice.weekdays.${days.last}'.tr()}',
    _ => days.map((d) => 'g5.voice.weekdaysShort.$d'.tr()).join(', '),
  };
  return 'g5.voice.hours'.tr(
    namedArgs: {'days': dayText, 'start': hours.start, 'end': hours.end},
  );
}

/// Bolaga ko'rinadigan psixolog ismi (sozlanmagan bo'lsa — umumiy nom).
String voicePsychologistName(VoiceContact contact) =>
    contact.psychologistName ?? 'g5.voice.help.unknownName'.tr();

/// «Murojaat · 5-noyabr» — matnsiz, neytral sarlavha.
String voiceRequestTitle(DateTime createdAt) =>
    'g5.voice.list.item'.tr(namedArgs: {'date': localizedDayMonth(createdAt)});

/// «HH:MM» (mahalliy vaqt).
String voiceClock(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

/// So'rov oyi nomi bosh harf bilan («Noyabr»).
String voiceMonthName(DateTime at) {
  final name = monthNameFrom('common.monthsFull'.tr(), at.month);
  return name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);
}

/// Ro'yxatdagi bosqich belgisi.
({String label, GChipKind kind}) voiceStageChip(VoiceStage? stage) =>
    switch (stage) {
      null => (label: 'g5.voice.list.stage.pending'.tr(), kind: GChipKind.warn),
      VoiceStage.received => (
        label: 'g5.voice.list.stage.received'.tr(),
        kind: GChipKind.info,
      ),
      VoiceStage.opened => (
        label: 'g5.voice.list.stage.opened'.tr(),
        kind: GChipKind.info,
      ),
      VoiceStage.replied => (
        label: 'g5.voice.list.stage.replied'.tr(),
        kind: GChipKind.ok,
      ),
      VoiceStage.closed => (
        label: 'g5.voice.list.stage.closed'.tr(),
        kind: GChipKind.neutral,
      ),
    };
