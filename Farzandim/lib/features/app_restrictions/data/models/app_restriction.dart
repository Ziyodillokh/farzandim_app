import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

/// Bola qurilmasidagi bitta ilova uchun ota-ona belgilagan cheklov.
///
/// **Firestore:**
/// `users/{parentUid}/children/{childId}/app_restrictions/{packageName}`
/// — document ID `packageName` (`com.tiktok`). Bola App real-time
/// stream qiladi va `isBlocked` yoki `limitMinutes` bo'yicha overlay
/// ko'rsatadi (Bosqich 4).
@immutable
class AppRestriction {
  /// `AppRestriction` konstruktor.
  const AppRestriction({
    required this.packageName,
    required this.appName,
    required this.limitMinutes,
    required this.updatedAt,
    this.isBlocked = false,
  });

  /// Android paket nomi (document ID).
  final String packageName;

  /// Foydalanuvchi-friendly nom (denormalized — usage va
  /// restriction'da bir xil bo'lishi uchun).
  final String appName;

  /// Kunlik vaqt cheklovi (daqiqa). 0 = limit yo'q.
  final int limitMinutes;

  /// Butunlay bloklangan — `limitMinutes`'dan ustun.
  final bool isBlocked;

  /// Oxirgi yangilanish (server timestamp).
  final DateTime updatedAt;

  /// Cheklov mavjudmi (block yoki limit > 0).
  bool get hasLimit => isBlocked || limitMinutes > 0;

  /// Foydalanuvchi-friendly format:
  /// - Bloklangan → "Bloklangan"
  /// - 0 → ""
  /// - 30 → "30 daq"
  /// - 60 → "1 soat"
  /// - 90 → "1 st 30 daq"
  String get limitFormatted {
    if (isBlocked) return 'appLimits.blocked'.tr();
    if (limitMinutes <= 0) return '';
    final h = limitMinutes ~/ 60;
    final m = limitMinutes % 60;
    if (h == 0) {
      return 'appLimits.durationMinutes'.tr(namedArgs: {'minutes': '$m'});
    }
    if (m == 0) {
      return 'appLimits.durationHours'.tr(namedArgs: {'hours': '$h'});
    }
    return 'formatters.duration'.tr(
      namedArgs: {'hours': '$h', 'minutes': '$m'},
    );
  }
}
