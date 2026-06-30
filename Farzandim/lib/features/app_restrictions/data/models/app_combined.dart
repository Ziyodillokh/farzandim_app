import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/utils/app_brand.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_restriction.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_usage.dart';
import 'package:flutter/foundation.dart';

/// Ilova foydalanish holati — UI ranglari va sort tartibini aniqlaydi.
enum UsageStatus {
  /// Cheklov ichida, < 50% ishlatilgan (yashil).
  healthy,

  /// Cheklovning 50-100% qismi ishlatilgan (sariq).
  warning,

  /// Cheklov to'liq ishlatilgan yoki oshib ketgan (qizil).
  exceeded,

  /// Butunlay bloklangan (qizil rang, lekin alohida holat).
  blocked,

  /// Cheklov yo'q (ko'rsatkichsiz).
  noLimit,
}

/// Bitta ilova ustida usage + restriction birlashtirilgan ko'rinish.
///
/// UI tile shu modelni oladi — bir ilovaga oid hamma ma'lumot
/// (foydalanish + cheklov + ikon) shu yerda. `restriction` `null`
/// bo'lsa ilova cheklanmagan.
@immutable
class AppCombined {
  const AppCombined({
    required this.packageName,
    required this.appName,
    required this.usageTimeMs,
    this.iconBase64,
    this.iconUrl,
    this.restriction,
  });

  /// Android paket nomi.
  final String packageName;

  /// Foydalanuvchi-friendly nom (usage yoki restriction'dan keladi).
  final String appName;

  /// Bugungi foydalanish vaqti (millisekund). 0 = bugun ishlatilmagan
  /// (lekin cheklov mavjud bo'lishi mumkin).
  final int usageTimeMs;

  /// Bola App tomonidan yuborilgan PNG ikon (base64). Cheklov-only
  /// ilova (bugun ishlatilmagan) uchun `null`.
  final String? iconBase64;

  /// Backend ikon URL — base64'dan ustun.
  final String? iconUrl;

  /// Cheklov (limit yoki block). `null` bo'lsa cheklanmagan.
  final AppRestriction? restriction;

  /// Limit yoki block bormi.
  bool get hasLimit => restriction?.hasLimit ?? false;

  /// Butunlay bloklanganmi.
  bool get isBlocked => restriction?.isBlocked ?? false;

  /// `Duration` ko'rinishida foydalanish vaqti.
  Duration get usageTime => Duration(milliseconds: usageTimeMs);

  /// Foydalanish daqiqada (`progressRatio` hisoblash uchun).
  int get usageMinutes => usageTime.inMinutes;

  /// Foydalanuvchi-friendly format:
  /// `< 1 daq` / `30 daqiqa` / `2 soat` / `2 soat 25 daqiqa`.
  String get usageFormatted {
    final h = usageTime.inHours;
    final m = usageTime.inMinutes % 60;
    if (h == 0 && m == 0) return 'appLimits.durationLessThanMinute'.tr();
    if (h == 0) {
      return 'appLimits.durationMinutesFull'.tr(namedArgs: {'minutes': '$m'});
    }
    if (m == 0) {
      return 'appLimits.durationHours'.tr(namedArgs: {'hours': '$h'});
    }
    return 'appLimits.durationHoursMinutesFull'.tr(
      namedArgs: {'hours': '$h', 'minutes': '$m'},
    );
  }

  /// Cheklov matni (`AppRestriction.limitFormatted`'ga delegate).
  /// `null` bo'lsa cheklov yo'q.
  String? get limitFormatted => restriction?.limitFormatted;

  /// Progress 0..1.5 (limit'ga nisbatan, oshib ketgan holat ham
  /// ifodalanadi). Limit yo'q yoki bloklangan bo'lsa 0.
  double get progressRatio {
    final r = restriction;
    if (r == null || r.limitMinutes <= 0) return 0;
    final ratio = usageMinutes / r.limitMinutes;
    return ratio.clamp(0.0, 1.5);
  }

  /// Foydalanish holati: blocked/noLimit, aks holda progress bo'yicha
  /// exceeded (>=100%), warning (>=50%) yoki healthy.
  UsageStatus get status {
    if (isBlocked) return UsageStatus.blocked;
    if (!hasLimit) return UsageStatus.noLimit;
    final ratio = progressRatio;
    if (ratio >= 1.0) return UsageStatus.exceeded;
    if (ratio >= 0.5) return UsageStatus.warning;
    return UsageStatus.healthy;
  }
}

/// Usage + restrictions ro'yxatlarini tile uchun birlashtiradi.
/// Sort: avval status (exceeded, blocked, warning, healthy, noLimit),
/// bir status ichida usage kamayish tartibida, keyin nom bo'yicha.
List<AppCombined> combineAppData({
  required AppUsageDay? usage,
  required List<AppRestriction> restrictions,
  List<AppUsageEntry> installedApps = const [],
}) {
  final restrictionMap = <String, AppRestriction>{
    for (final r in restrictions) r.packageName: r,
  };
  // packageName → installed app (icon manbai) lookup.
  final installedMap = <String, AppUsageEntry>{
    for (final a in installedApps) a.packageName: a,
  };

  final result = <AppCombined>[];
  final seenPackages = <String>{};

  if (usage != null) {
    // Juda qisqa va system ilovalar `filteredApps`da chiqarib tashlangan,
    // lekin ularni "seen" deb belgilaymiz — pastdagi cheklov ro'yxatida
    // 0-usage bo'lib qayta paydo bo'lib qolmasin.
    for (final app in usage.aggregatedApps) {
      seenPackages.add(app.packageName);
    }
    for (final app in usage.filteredApps) {
      // Real nom: bola qurilmasidagi ilova yorlig'i (installed-apps'dan).
      // Usage endpoint nomni bermaydi (packageName qaytadi) — shuning uchun
      // installed-apps'dagi haqiqiy nom afzal ("telegram.org" emas "Telegram").
      final installed = installedMap[app.packageName];
      final candidate = (installed != null && installed.appName.isNotEmpty)
          ? installed.appName
          : app.appName;
      final name = friendlyAppName(app.packageName, candidate);
      result.add(
        AppCombined(
          packageName: app.packageName,
          appName: name,
          usageTimeMs: app.totalTimeMs,
          iconBase64: app.iconBase64 ?? installed?.iconBase64,
          iconUrl: app.iconUrl ?? installed?.iconUrl,
          restriction: restrictionMap[app.packageName],
        ),
      );
    }
  }

  // Cheklov bor, lekin bugun ishlatilmagan ilovalar — mavjud limitlarni
  // ko'rish/boshqarish uchun ko'rsatamiz.
  for (final r in restrictions) {
    if (!seenPackages.contains(r.packageName)) {
      seenPackages.add(r.packageName);
      final installed = installedMap[r.packageName];
      final candidate = (installed != null && installed.appName.isNotEmpty)
          ? installed.appName
          : r.appName;
      final name = friendlyAppName(r.packageName, candidate);
      result.add(
        AppCombined(
          packageName: r.packageName,
          appName: name,
          usageTimeMs: 0,
          iconBase64: installed?.iconBase64,
          iconUrl: installed?.iconUrl,
          restriction: r,
        ),
      );
    }
  }

  // 0-usage o'rnatilgan ilovalar ataylab qo'shilmaydi — faqat real
  // ishlatilgan va cheklangan ilovalar ko'rsatiladi.

  const statusOrder = [
    UsageStatus.exceeded,
    UsageStatus.blocked,
    UsageStatus.warning,
    UsageStatus.healthy,
    UsageStatus.noLimit,
  ];

  result.sort((a, b) {
    final byStatus = statusOrder
        .indexOf(a.status)
        .compareTo(statusOrder.indexOf(b.status));
    if (byStatus != 0) return byStatus;
    final byUsage = b.usageTimeMs.compareTo(a.usageTimeMs);
    if (byUsage != 0) return byUsage;
    return a.appName.compareTo(b.appName);
  });

  return result;
}
