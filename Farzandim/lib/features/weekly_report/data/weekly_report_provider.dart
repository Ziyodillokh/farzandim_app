// Haftalik hisobot modellari va provider'lari: qadam, ekran vaqti,
// top ilovalar (GET /api/children/:childId/weekly-report).

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class DayMs {
  const DayMs({
    required this.date,
    required this.totalMs,
    required this.totalMinutes,
  });
  final String date;
  final int totalMs;
  final int totalMinutes;
}

@immutable
class DaySteps {
  const DaySteps({required this.date, required this.steps});
  final String date;
  final int steps;
}

@immutable
class TopApp {
  const TopApp({
    required this.packageName,
    required this.appName,
    required this.totalMinutes,
  });
  final String packageName;
  final String appName;
  final int totalMinutes;
}

@immutable
class WeeklyReport {
  const WeeklyReport({
    required this.screenDays,
    required this.screenWeekMs,
    required this.screenWeekMinutes,
    required this.stepDays,
    required this.stepsWeekTotal,
    required this.stepsDailyAvg,
    required this.topApps,
  });

  factory WeeklyReport.fromJson(Map<String, dynamic> json) {
    final screen = (json['screenTime'] as Map<String, dynamic>?) ?? const {};
    final steps = (json['steps'] as Map<String, dynamic>?) ?? const {};
    final apps = (json['topApps'] as List<dynamic>?) ?? const [];

    final screenDays = ((screen['days'] as List<dynamic>?) ?? const [])
        .map((e) => e as Map<String, dynamic>)
        .map(
          (d) => DayMs(
            date: d['date'] as String? ?? '',
            totalMs: _int(d['totalMs']),
            totalMinutes: _int(d['totalMinutes']),
          ),
        )
        .toList();

    final stepDays = ((steps['days'] as List<dynamic>?) ?? const [])
        .map((e) => e as Map<String, dynamic>)
        .map(
          (d) => DaySteps(
            date: d['date'] as String? ?? '',
            steps: _int(d['steps']),
          ),
        )
        .toList();

    final topApps = apps
        .map((e) => e as Map<String, dynamic>)
        .map(
          (a) => TopApp(
            packageName: a['packageName'] as String? ?? '',
            appName:
                a['appName'] as String? ?? (a['packageName'] as String? ?? ''),
            totalMinutes: _int(a['totalMinutes']),
          ),
        )
        .toList();

    return WeeklyReport(
      screenDays: screenDays,
      screenWeekMs: _int(screen['weekTotalMs']),
      screenWeekMinutes: _int(screen['weekTotalMinutes']),
      stepDays: stepDays,
      stepsWeekTotal: _int(steps['weekTotal']),
      stepsDailyAvg: _int(steps['dailyAvg']),
      topApps: topApps,
    );
  }

  final List<DayMs> screenDays;
  final int screenWeekMs;
  final int screenWeekMinutes;
  final List<DaySteps> stepDays;
  final int stepsWeekTotal;
  final int stepsDailyAvg;
  final List<TopApp> topApps;

  static int _int(dynamic v) => (v as num?)?.round() ?? 0;
}

class WeeklyReportRepository {
  WeeklyReportRepository(this._dio);
  final Dio _dio;

  Future<WeeklyReport> get(String childId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/children/$childId/weekly-report',
    );
    return WeeklyReport.fromJson(res.data ?? const {});
  }
}

final weeklyReportRepositoryProvider = Provider<WeeklyReportRepository>((ref) {
  return WeeklyReportRepository(ref.watch(dioClientProvider));
});

/// Pull-to-refresh uchun hisoblagich — invalidate ekranni blank qilib
/// yuborardi, counter bilan eski data ko'rinib turadi.
final weeklyReportRefreshProvider = StateProvider.family<int, String>(
  (ref, childId) => 0,
);

final weeklyReportProvider = FutureProvider.family<WeeklyReport, String>((
  ref,
  childId,
) async {
  ref.watch(weeklyReportRefreshProvider(childId));
  return ref.watch(weeklyReportRepositoryProvider).get(childId);
});
