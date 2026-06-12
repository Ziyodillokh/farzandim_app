// Sana/vaqt formatlash helper'lari — hozirgi locale'ga moslab matn beradi.
// `.tr()` global EasyLocalization controller'dan o'qiydi, context kerak emas.

import 'package:easy_localization/easy_localization.dart';

/// `Duration`'ni locale'ga mos "X st Y daq" ko'rinishiga o'tkazadi.
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  return 'formatters.duration'.tr(
    namedArgs: {'hours': '$hours', 'minutes': '$minutes'},
  );
}

/// Nisbiy vaqt matni: "hozir", "5 daq oldin", "3 soat oldin",
/// kechagisi "kecha", undan eskisi "DD.MM".
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
