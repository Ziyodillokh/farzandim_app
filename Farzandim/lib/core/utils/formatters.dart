// ─────────────────────────────────────────────────────────────────────
// FARZANDIM — FORMATTERS (Sana/vaqt/raqam formatlash)
// ─────────────────────────────────────────────────────────────────────
//
// UI'da ko'rsatish uchun ma'lumotni hozirgi locale'ga moslashtirib
// formatlaydi (Sprint 3.3). `.tr()` extension global EasyLocalization
// controller'dan o'qiydi — context kerak emas.

import 'package:easy_localization/easy_localization.dart';

/// `Duration`'ni hozirgi locale uchun "X st Y daq" / "X ч Y мин" /
/// "X h Y min" formatiga o'tkazadi.
///
/// Misol (uz): `Duration(hours: 5, minutes: 2)` → `"5 st 2 daq"`
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  return 'formatters.duration'.tr(
    namedArgs: {'hours': '$hours', 'minutes': '$minutes'},
  );
}

/// `DateTime`'ni hozirgi vaqtga nisbatan hozirgi locale matniga
/// o'tkazadi.
///
/// - <1 daq → "hozir" / "сейчас" / "now"
/// - <60 daq → "5 daq oldin" / "5 мин назад" / "5 min ago"
/// - <24 soat → "3 soat oldin" / "3 ч назад" / "3 h ago"
/// - aks holda → "DD.MM" (sana — barcha tilda bir xil)
String formatRelativeTime(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'formatters.now'.tr();
  if (diff.inMinutes < 60) {
    return 'formatters.minutesAgo'.tr(
      namedArgs: {'minutes': '${diff.inMinutes}'},
    );
  }
  if (diff.inHours < 24) {
    return 'formatters.hoursAgo'.tr(
      namedArgs: {'hours': '${diff.inHours}'},
    );
  }
  // Kecha — kalendar kuni bo'yicha (24 soatdan emas).
  final todayStart = DateTime(now.year, now.month, now.day);
  final timeStart = DateTime(time.year, time.month, time.day);
  if (todayStart.difference(timeStart).inDays == 1) {
    return 'formatters.yesterday'.tr();
  }
  final day = time.day.toString().padLeft(2, '0');
  final month = time.month.toString().padLeft(2, '0');
  return '$day.$month';
}
