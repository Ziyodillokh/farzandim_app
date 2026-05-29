// ─────────────────────────────────────────────────────────────────────
// AppUsageEntry — bitta ilova foydalanish (Sprint 4.4.32)
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

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
      return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
  }

  final String packageName;
  final String appName;
  final int totalTimeMs;
  final DateTime lastTimeUsed;
  final String? iconBase64;
  final String? iconUrl;

  Duration get totalTime => Duration(milliseconds: totalTimeMs);

  /// `2 soat 30 daq` / `5 daq` / `< 1 daq` formatda.
  String get formattedTime {
    final h = totalTime.inHours;
    final m = totalTime.inMinutes % 60;
    if (h == 0 && m == 0) return '< 1 daq';
    if (h == 0) return '$m daq';
    if (m == 0) return '$h soat';
    return '$h soat $m daq';
  }
}

@immutable
class AppUsageDay {
  const AppUsageDay({
    required this.date,
    required this.apps,
  });

  final String date; // YYYY-MM-DD
  final List<AppUsageEntry> apps;

  /// Jami foydalanish vaqti.
  Duration get totalTime => Duration(
        milliseconds: apps.fold<int>(0, (sum, a) => sum + a.totalTimeMs),
      );

  /// `5 st 16 daq` formatda.
  String get formattedTotal {
    final h = totalTime.inHours;
    final m = totalTime.inMinutes % 60;
    if (h == 0) return '$m daq';
    return '$h st $m daq';
  }
}
