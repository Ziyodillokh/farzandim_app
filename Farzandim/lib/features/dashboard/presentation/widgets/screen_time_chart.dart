// ─────────────────────────────────────────────────────────────────────
// ScreenTimeChart — Parent dashboard haftalik bar chart
// ─────────────────────────────────────────────────────────────────────
//
// Sprint 5.x: Child App'dan ko'chirildi (parent monitoring vositasi).
// Tanlangan bola uchun oxirgi 7 kunlik app-usage aggregati.
// Bugungi kun lime green bar, qolganlar slate.

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_usage_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 7 kunlik usage provider — selectedChildId family.
///
/// Realtime: ekran ochiq ekan har 30 sek backend'dan qayta o'qiydi. Bola
/// qurilmasi usage sync qilgach ota-ona 30 sek ichida yangi qiymatni ko'radi
/// (avval `FutureProvider` edi — faqat ekran qayta ochilganda yangilanardi).
final weeklyChildUsageProvider =
    StreamProvider.family<List<DailyUsageTotal>, String>((ref, childId) async* {
  final repo = ref.watch(backendAppUsageRepositoryProvider);
  // Birinchi yuklash. Xato bo'lsa AsyncLoading qoladi (_TimeCard "—" ko'rsatadi),
  // polling keyin qayta urinadi.
  try {
    yield await repo.getWeeklyTotals(childId: childId, endDate: DateTime.now());
  } catch (_) {
    // birinchi fetch xato — pastdagi polling retry qiladi
  }
  // Har 30 sek realtime poll. Xato (tarmoq blip) bo'lsa YIELD QILMAYMIZ —
  // StreamProvider oxirgi qiymatni saqlaydi, shuning uchun ekran vaqti
  // "0 daqiqa"ga tushib qolmaydi (avvalgi regressiya).
  await for (final _
      in Stream<int>.periodic(const Duration(seconds: 30), (i) => i)) {
    try {
      yield await repo.getWeeklyTotals(
        childId: childId,
        endDate: DateTime.now(),
      );
    } catch (_) {
      // skip — oxirgi qiymat saqlanadi
    }
  }
});

/// Bugungi ekran vaqti (ms) — server `/weekly` (system filtrlangan +
/// Toshkent UTC+5) avtoritar kunlik jamisidan olinadi.
///
/// **Yagona manba:** dashboard `_TimeCard` va detail `ScreenTimeChart` ayni
/// shu provider'dan o'qiydi — shuning uchun ikki ekranda qiymat DOIM bir xil
/// va realtime bo'ladi (avval dashboard per-app yig'indini alohida hisoblardi,
/// shu sababli 1h7m ↔ 1h22m kabi farq chiqardi).
final todayScreenTimeMsProvider = Provider.family<int, String>((ref, childId) {
  final weekly =
      ref.watch(weeklyChildUsageProvider(childId)).valueOrNull ?? const [];
  if (weekly.isEmpty) return 0;
  String key(DateTime d) => '${d.year}-${d.month}-${d.day}';
  final todayKey = key(DateTime.now().toUtc().add(const Duration(hours: 5)));
  final match = weekly.where((x) => key(x.date) == todayKey);
  final ms = match.isNotEmpty ? match.first.totalMs : weekly.last.totalMs;
  return ms.clamp(0, 24 * 60 * 60 * 1000);
});

class ScreenTimeChart extends ConsumerWidget {
  const ScreenTimeChart({super.key, required this.childId});

  final String childId;

  static const List<String> _shortDays = [
    'Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya',
  ];
  // Getter — theme almashganda rang yangilanishi uchun (cached field emas).
  static Color get _todayBar => AppColors.primary;
  static Color get _otherBar => AppColors.surfaceVariant;
  static TextStyle get _yAxisStyle => TextStyle(
        fontSize: 11,
        color: AppColors.textSecondary,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyAsync = ref.watch(weeklyChildUsageProvider(childId));
    final todayMs = ref.watch(todayScreenTimeMsProvider(childId));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: weeklyAsync.when(
        loading: () => SizedBox(
          height: 220,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (_, _) => SizedBox(
          height: 220,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Statistika yuklanmadi',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(weeklyChildUsageProvider(childId)),
                  child: const Text('Qayta urinish'),
                ),
              ],
            ),
          ),
        ),
        data: (totals) => _buildChart(totals, todayMs),
      ),
    );
  }

  Widget _buildChart(List<DailyUsageTotal> totals, int todayMs) {
    if (totals.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(
            "Hech qanday ma'lumot yo'q",
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    // Toshkent (UTC+5) bugungi kuni — bar shu vaqt bilan belgilanadi.
    final todayKey = _key(DateTime.now().toUtc().add(const Duration(hours: 5)));
    final maxMs = totals
        .map((t) => t.totalMs)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final maxHours = (maxMs / 3600000).ceil().clamp(2, 24);

    // Bugungi kun jami vaqti — dashboard `_TimeCard` bilan AYNI manba
    // (`todayScreenTimeMsProvider`), shuning uchun ikki ekranda bir xil.
    final hours = todayMs ~/ 3600000;
    final minutes = (todayMs % 3600000) ~/ 60000;
    final title = hours == 0 ? '$minutes daq' : '$hours st $minutes daq';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ekran vaqti',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 180,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: totals.map((daily) {
                    final value = daily.hours;
                    final isToday = _key(daily.date) == todayKey;
                    final heightPercent = value / maxHours;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 28,
                          height: (heightPercent * 140).clamp(2, 140),
                          decoration: BoxDecoration(
                            color: isToday ? _todayBar : _otherBar,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _shortDays[(daily.date.weekday - 1) % 7],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isToday ? FontWeight.w700 : FontWeight.w400,
                            color: isToday
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$maxHours st', style: _yAxisStyle),
                  Text('${(maxHours / 2).floor()} st', style: _yAxisStyle),
                  Text('0', style: _yAxisStyle),
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';
}
