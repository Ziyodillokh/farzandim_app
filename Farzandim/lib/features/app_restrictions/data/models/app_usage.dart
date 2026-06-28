import 'package:flutter/foundation.dart';

/// Bola qurilmasidagi bitta ilova ustida foydalanish ma'lumoti.
///
/// Bola ilovasi `UsageStatsManager` orqali yig'ib serverga yuboradi.
/// Bir paket uchun bir nechta yozuv kelishi mumkin (Android `INTERVAL_DAILY`
/// 2 kunga qaytadi) — UI'da [AppUsageDay.aggregatedApps] birlashtiradi.
@immutable
class AppUsageEntry {
  const AppUsageEntry({
    required this.packageName,
    required this.appName,
    required this.totalTimeMs,
    required this.lastTimeUsed,
    this.iconBase64,
    this.iconUrl,
  });

  /// Map'dan parse — Backend JSON yoki cache'dagi `apps` array elementlari.
  /// `lastTimeUsed` epoch millis (int) yoki ISO 8601 (string) bo'lishi mumkin.
  factory AppUsageEntry.fromMap(Map<String, dynamic> map) {
    return AppUsageEntry(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      totalTimeMs: (map['totalTimeMs'] as num?)?.toInt() ?? 0,
      lastTimeUsed: _parseLastTimeUsed(map['lastTimeUsed']),
      iconBase64: map['iconBase64'] as String?,
      iconUrl: map['iconUrl'] as String?,
    );
  }

  static DateTime _parseLastTimeUsed(dynamic raw) {
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
    return DateTime.now();
  }

  /// Android paket nomi (`com.tiktok`, `com.instagram.android`, ...).
  final String packageName;

  /// Foydalanuvchi-friendly nom (`TikTok`, `Instagram`, ...).
  final String appName;

  /// Foydalanish vaqti (millisekund).
  final int totalTimeMs;

  /// Oxirgi marta ishlatilgan vaqt.
  final DateTime lastTimeUsed;

  /// Bola App tomonidan yuborilgan PNG ikonkasi (base64-encoded,
  /// odatda 96x96). `null` bo'lsa `AppIconWidget` paket nomidan
  /// fallback `IconData` ko'rsatadi.
  final String? iconBase64;

  /// Backend MinIO signed URL (1 soat amal qiladi).
  /// Ustuvorlik: `iconUrl > iconBase64 > Material fallback`.
  final String? iconUrl;

  /// `Duration` ko'rinishida foydalanish vaqti.
  Duration get totalTime => Duration(milliseconds: totalTimeMs);

  /// `2 soat 30 daq` / `5 daq` / `< 1 daq` formatda matn.
  String get formattedTime {
    final h = totalTime.inHours;
    final m = totalTime.inMinutes % 60;
    if (h == 0 && m == 0) return '< 1 daq';
    if (h == 0) return '$m daq';
    if (m == 0) return '$h soat';
    return '$h soat $m daq';
  }
}

/// Bir kunlik foydalanish ma'lumotlari — bola ilovasi fonda davriy
/// sync qilib turadi, parent backend'dan kunlik aggregat sifatida oladi.
@immutable
class AppUsageDay {
  const AppUsageDay({
    required this.date,
    required this.updatedAt,
    required this.apps,
  });

  /// `YYYY-MM-DD` format (document ID).
  final String date;

  /// Bola ilovasining oxirgi sync vaqti (server timestamp).
  final DateTime updatedAt;

  /// Xom apps ro'yxati — `aggregatedApps` orqali tartibga solinadi.
  final List<AppUsageEntry> apps;

  /// `packageName` bo'yicha aggregatlangan ro'yxat (vaqt bo'yicha desc).
  ///
  /// Android `INTERVAL_DAILY` ba'zan bir paket uchun ikki yozuv qaytaradi
  /// — bu yerda yig'ib tartiblaymiz: jami vaqt qo'shiladi, oxirgi
  /// ishlatilgan vaqt eng kechki olinadi.
  List<AppUsageEntry> get aggregatedApps {
    final map = <String, AppUsageEntry>{};

    for (final app in apps) {
      final existing = map[app.packageName];
      if (existing == null) {
        map[app.packageName] = app;
      } else {
        map[app.packageName] = AppUsageEntry(
          packageName: app.packageName,
          appName: app.appName,
          totalTimeMs: existing.totalTimeMs + app.totalTimeMs,
          lastTimeUsed: app.lastTimeUsed.isAfter(existing.lastTimeUsed)
              ? app.lastTimeUsed
              : existing.lastTimeUsed,
          iconBase64: app.iconBase64 ?? existing.iconBase64,
          iconUrl: app.iconUrl ?? existing.iconUrl,
        );
      }
    }

    final list = map.values.toList()
      ..sort((a, b) => b.totalTimeMs.compareTo(a.totalTimeMs));
    return list;
  }

  /// Juda qisqa (tasodifiy ochib-yopish) foydalanishlar yashiriladi (ms).
  /// 10 soniya qilib qo'yilgan: 60s bo'lganda 1 daqiqadan kam ishlatilgan
  /// ilova (masalan Chrome 40 soniya) umuman ko'rinmasdi.
  // 1 daqiqadan kam ishlatilgan ilova ro'yxatni shishirib yuboradi
  // (tasodifiy ochilishlar) — ko'rsatmaymiz.
  static const int _minVisibleMs = 60000;

  /// Faqat launcher, systemUI, klaviatura va pure-fon servislarni chiqaramiz.
  ///
  /// Ilgari `com.android.*` butunlay filtrlanardi — soat, kamera,
  /// kalkulyator kabi foydalanuvchi haqiqatan ishlatadigan ilovalar ham
  /// yo'qolardi. Endi faqat aniq tizimiy/fon paketlar chiqariladi;
  /// event-based hisob fon servislarni baribir 0 qiladi, shuning uchun
  /// keng filtr shart emas.
  List<AppUsageEntry> get filteredApps {
    const systemPrefixes = [
      // Launcher'lar (uy ekrani) — foreground'da ko'rinadi, lekin "ilova" emas.
      'com.android.launcher',
      'com.sec.android.app.launcher',
      'com.miui.home',
      'com.google.android.apps.nexuslauncher',
      // System UI / fon servislar.
      'com.android.systemui',
      'com.google.android.gms',
      'com.google.android.packageinstaller',
      'com.google.android.permissioncontroller',
      // Klaviaturalar (IME) — overlay, "ekran vaqti" emas.
      'com.google.android.inputmethod',
      'com.sec.android.inputmethod',
      'com.samsung.android.honeyboard',
      // 'com.farzandim.' (Parvoz) ataylab filtrlanmaydi — bola Parvoz
      // ichida video/audiokitob ko'radi, bu ham haqiqiy ekran vaqti.
    ];

    return aggregatedApps.where((app) {
      // Juda qisqa (tasodifiy) ochilishlar ko'rsatilmaydi.
      if (app.totalTimeMs < _minVisibleMs) return false;
      return !systemPrefixes.any(
        (prefix) => app.packageName.startsWith(prefix),
      );
    }).toList();
  }

  /// UI'da ko'rsatiladigan ilovalar — faqat real ishlatilgan (system emas,
  /// ≥10 soniya) ilovalar. Avvalgi "bo'sh bo'lsa system ilovalarni ko'rsat"
  /// fallback ataylab olib tashlangan.
  List<AppUsageEntry> get displayApps => filteredApps;
}
