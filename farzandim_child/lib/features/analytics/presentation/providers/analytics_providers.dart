// ─────────────────────────────────────────────────────────────────────
// analytics_providers — Sprint 4.4.32 selected date + usage + limits
// ─────────────────────────────────────────────────────────────────────
//
// DateNavigator state: hozir tanlangan sana. Default — bugun.
// Provider'lar shu sanaga binoan Backend'dan ma'lumot oladi:
//   - dailyUsageProvider — tanlangan sana ilovalar usage + icon
//   - weeklyUsageProvider — tanlangan sana 'oxirgi kuni' bo'lgan
//     7 kunlik haftalik aggregate
//   - childAppLimitsProvider — joriy AppLimit'lar (Sprint 4.4.25
//     `BackendAppLimitRepository` qayta ishlatiladi)

// ignore_for_file: public_member_api_docs

import 'package:farzandim_child/features/analytics/data/models/app_usage_entry.dart';
import 'package:farzandim_child/features/analytics/data/repositories/backend_analytics_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sana — vaqtsiz (00:00:00). DateNavigator o'zgartiradi.
final selectedAnalyticsDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Tanlangan sana ilovalar usage + icon merge bilan.
final dailyUsageProvider = FutureProvider<AppUsageDay>((ref) async {
  final pairing = ref.watch(pairingStateProvider);
  final childId = pairing.childId;
  if (childId == null) {
    return AppUsageDay(
      date: '',
      apps: const [],
    );
  }
  final date = ref.watch(selectedAnalyticsDateProvider);
  final repo = ref.watch(backendAnalyticsRepositoryProvider);
  return repo.getUsageByDate(childId: childId, date: date);
});

/// 7 kunlik haftalik aggregate — selected date oxirgi kun.
final weeklyUsageProvider =
    FutureProvider<List<DailyUsageTotal>>((ref) async {
  final pairing = ref.watch(pairingStateProvider);
  final childId = pairing.childId;
  if (childId == null) return const [];
  final endDate = ref.watch(selectedAnalyticsDateProvider);
  final repo = ref.watch(backendAnalyticsRepositoryProvider);
  return repo.getWeeklyTotals(childId: childId, endDate: endDate);
});

/// Joriy bola uchun AppLimit'lar (Sprint 4.4.25 `BackendAppLimitRepository`).
final childAppLimitsProvider =
    FutureProvider<List<AppLimit>>((ref) async {
  final pairing = ref.watch(pairingStateProvider);
  final childId = pairing.childId;
  if (childId == null) return const [];
  final repo = ref.watch(backendAppLimitRepositoryProvider);
  return repo.getLimits(childId);
});

/// Installed apps map (packageName → meta). AppLimit'lar uchun
/// nom + icon manbai.
final installedAppsMapProvider =
    FutureProvider<Map<String, InstalledAppMeta>>((ref) async {
  final pairing = ref.watch(pairingStateProvider);
  final childId = pairing.childId;
  if (childId == null) return const {};
  final repo = ref.watch(backendAnalyticsRepositoryProvider);
  return repo.getInstalledApps(childId);
});
