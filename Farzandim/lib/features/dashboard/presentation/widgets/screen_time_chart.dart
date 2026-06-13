// ─────────────────────────────────────────────────────────────────────
// ScreenTimeChart — Parent dashboard haftalik bar chart
// ─────────────────────────────────────────────────────────────────────
//
// Sprint 5.x: Child App'dan ko'chirildi (parent monitoring vositasi).
// Tanlangan bola uchun oxirgi 7 kunlik app-usage aggregati.
// Bugungi kun lime green bar, qolganlar slate.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/utils/polling.dart';
import 'package:farzandim/core/utils/tashkent_time.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_usage_repository.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/shared/widgets/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 7 kunlik usage provider — selectedChildId family.
///
/// Realtime: ekran ochiq ekan har 30 sek backend'dan qayta o'qiydi.
/// `autoDispose` + lifecycle skip (P0-1): ekran yopilgach (2 daq keshdan
/// keyin) va ilova fonda bo'lsa polling to'xtaydi — avval ilova umri
/// davomida davom etardi.
final weeklyChildUsageProvider = StreamProvider.autoDispose
    .family<List<DailyUsageTotal>, String>((ref, childId) async* {
      // Auth guard — logout'dan keyin 401 polling qilmaslik uchun.
      final isAuthed = ref.watch(
        backendAuthProvider.select((s) => s is AuthAuthenticated),
      );
      if (!isAuthed) {
        yield const <DailyUsageTotal>[];
        return;
      }
      keepAliveFor(ref, const Duration(minutes: 2));
      final repo = ref.watch(backendAppUsageRepositoryProvider);
      // swallowFirstError: birinchi fetch xatosi ham yutiladi — kesh yoki
      // AsyncLoading qoladi, polling keyin qayta urinadi (ekran vaqti
      // "0 daqiqa"ga tushib qolmaydi — avvalgi regressiya).
      yield* pollFetchStream<List<DailyUsageTotal>>(
        ref,
        interval: const Duration(seconds: 30),
        fetch: () =>
            repo.getWeeklyTotals(childId: childId, endDate: DateTime.now()),
        // NET-07 (SWR): keshdagi haftalik DARHOL — chart "—" o'rniga oxirgi
        // ma'lumotni ko'rsatadi, yangisi fonda keladi.
        readCache: () async {
          final cached = await repo.getCachedWeeklyTotals(childId);
          return (cached != null && cached.isNotEmpty) ? cached : null;
        },
        swallowFirstError: true,
      );
    });

/// Bugungi ekran vaqti (ms) — server `/weekly` (system filtrlangan +
/// Toshkent UTC+5) avtoritar kunlik jamisidan olinadi.
///
/// **Yagona manba:** dashboard `_TimeCard` va detail `ScreenTimeChart` ayni
/// shu provider'dan o'qiydi — shuning uchun ikki ekranda qiymat DOIM bir xil
/// va realtime bo'ladi (avval dashboard per-app yig'indini alohida hisoblardi,
/// shu sababli 1h7m ↔ 1h22m kabi farq chiqardi).
/// `autoDispose` (REG-2): busiz bu non-autoDispose provider weekly poller'ni
/// ABADIY ushlab turardi — weekly'ning autoDispose'i jim ishlamay qolardi.
final todayScreenTimeMsProvider = Provider.autoDispose.family<int, String>((
  ref,
  childId,
) {
  final weekly =
      ref.watch(weeklyChildUsageProvider(childId)).valueOrNull ?? const [];
  if (weekly.isEmpty) return 0;
  String key(DateTime d) => '${d.year}-${d.month}-${d.day}';
  final todayKey = key(tashkentNow());
  final match = weekly.where((x) => key(x.date) == todayKey);
  // BUG-08: bugungi yozuv topilmasa 0 — avval weekly.last (BOSHQA kunning
  // vaqti!) ko'rsatilardi: yarim kechada kechagi katta raqam "bugun" deb
  // chiqardi.
  final ms = match.isNotEmpty ? match.first.totalMs : 0;
  return ms.clamp(0, 24 * 60 * 60 * 1000);
});

class ScreenTimeChart extends ConsumerWidget {
  const ScreenTimeChart({required this.childId, super.key});

  final String childId;

  // Getter — theme almashganda rang yangilanishi uchun (cached field emas).
  // Bugun — to'q/boy yashil (accent: dark=lime, light=to'q yashil) — bo'rtib turadi.
  static Color get _todayBar => AppColors.accent;
  // O'tgan kunlar — OCHROQ yashil (avval surfaceVariant edi → kartaga yopishib
  // ko'rinmasdi). Endi ikkala temada ham aniq ko'rinadigan ochroq yashil.
  static Color get _otherBar => AppColors.chartBarMuted;
  static TextStyle get _yAxisStyle => TextStyle(
    fontSize: 11,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w500,
  );

  /// Bar ustidagi "ishlatilgan vaqt" yorlig'i — ixcham (2.5s / 45d).
  static String _barLabel(int ms) {
    if (ms <= 0) return '';
    final hoursF = ms / 3600000;
    if (hoursF >= 1) {
      return 'dashboard.chart.hoursShort'.tr(
        namedArgs: {'value': hoursF.toStringAsFixed(hoursF >= 10 ? 0 : 1)},
      );
    }
    return 'dashboard.chart.minutesShort'.tr(
      namedArgs: {'value': '${ms ~/ 60000}'},
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyAsync = ref.watch(weeklyChildUsageProvider(childId));
    final todayMs = ref.watch(todayScreenTimeMsProvider(childId));

    return GlassCard(
      padding: const EdgeInsets.all(20),
      radius: 16,
      child: weeklyAsync.when(
        loading: () => SizedBox(
          height: 220,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        ),
        error: (_, _) => SizedBox(
          height: 220,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'dashboard.chart.loadError'.tr(),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(weeklyChildUsageProvider(childId)),
                  child: Text('common.retry'.tr()),
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
            'dashboard.chart.noData'.tr(),
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    // Toshkent (UTC+5) bugungi kuni — bar shu vaqt bilan belgilanadi.
    final todayKey = _key(tashkentNow());
    final maxMs = totals
        .map((t) => t.totalMs)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final maxHours = (maxMs / 3600000).ceil().clamp(2, 24);

    // Bugungi kun jami vaqti — dashboard `_TimeCard` bilan AYNI manba
    // (`todayScreenTimeMsProvider`), shuning uchun ikki ekranda bir xil.
    final hours = todayMs ~/ 3600000;
    final minutes = (todayMs % 3600000) ~/ 60000;
    final title = hours == 0
        ? 'appLimits.durationMinutes'.tr(namedArgs: {'minutes': '$minutes'})
        : 'formatters.duration'.tr(
            namedArgs: {'hours': '$hours', 'minutes': '$minutes'},
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'weeklyReport.screenTime'.tr(),
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
        // ─── Grafik: chap soat-shkalasi + yengil gridline'lar + bar'lar ───
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Y o'qi — soat shkalasi (gridline'larga tekis).
              SizedBox(
                width: 30,
                height: 150,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'dashboard.chart.hoursShort'.tr(
                        namedArgs: {'value': '$maxHours'},
                      ),
                      style: _yAxisStyle,
                    ),
                    Text(
                      'dashboard.chart.hoursShort'.tr(
                        namedArgs: {'value': '${(maxHours / 2).round()}'},
                      ),
                      style: _yAxisStyle,
                    ),
                    Text('0', style: _yAxisStyle),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    // Yengil gorizontal gridline'lar (0 / yarim / max).
                    Positioned.fill(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          3,
                          (_) => Container(height: 1, color: AppColors.divider),
                        ),
                      ),
                    ),
                    // Bar'lar — pastdan o'sadi.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: totals.map((daily) {
                        final isToday = _key(daily.date) == todayKey;
                        final ratio = daily.totalMs / (maxHours * 3600000);
                        final barH = (ratio * 150).clamp(3.0, 150.0);
                        return Container(
                          width: 26,
                          height: barH,
                          decoration: BoxDecoration(
                            color: isToday ? _todayBar : _otherBar,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(7),
                              bottom: Radius.circular(2),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ─── Kun + aniq ishlatilgan vaqt (bar'lar ostida tekis) ───
        Padding(
          padding: const EdgeInsets.only(left: 38),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: totals.map((daily) {
              final isToday = _key(daily.date) == todayKey;
              final label = _barLabel(daily.totalMs);
              return SizedBox(
                width: 30,
                child: Column(
                  children: [
                    Text(
                      'dashboard.chart.weekdays.${daily.date.weekday}'.tr(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                        color: isToday
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label.isEmpty ? '—' : label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday ? _todayBar : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  static String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';
}
