// ─────────────────────────────────────────────────────────────────────
// ScreenTimeChart — Parent dashboard haftalik bar chart
// ─────────────────────────────────────────────────────────────────────
//
// Sprint 5.x: Child App'dan ko'chirildi (parent monitoring vositasi).
// Tanlangan bola uchun oxirgi 7 kunlik app-usage aggregati.
// Bugungi kun lime green bar, qolganlar slate.

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/utils/app_lifecycle.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/shared/widgets/glass_card.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_usage_repository.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart'
    show keepAliveFor;
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
  final isAuthed =
      ref.watch(backendAuthProvider.select((s) => s is AuthAuthenticated));
  if (!isAuthed) {
    yield const <DailyUsageTotal>[];
    return;
  }
  keepAliveFor(ref, const Duration(minutes: 2));
  // Zombi-guard: bekor qilingan generator faqat keyingi yield'da to'xtaydi.
  var alive = true;
  ref.onDispose(() => alive = false);
  final repo = ref.watch(backendAppUsageRepositoryProvider);
  // NET-07 (SWR): keshdagi haftalik DARHOL — chart "—" o'rniga oxirgi
  // ma'lumotni ko'rsatadi, yangisi fonda keladi.
  final cachedWeekly = await repo.getCachedWeeklyTotals(childId);
  if (cachedWeekly != null && cachedWeekly.isNotEmpty) {
    yield cachedWeekly;
  }
  // Birinchi yuklash. Xato bo'lsa kesh/AsyncLoading qoladi,
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
    if (!alive) return;
    if (!isAppResumed(ref)) continue;
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
/// `autoDispose` (REG-2): busiz bu non-autoDispose provider weekly poller'ni
/// ABADIY ushlab turardi — weekly'ning autoDispose'i jim ishlamay qolardi.
final todayScreenTimeMsProvider =
    Provider.autoDispose.family<int, String>((ref, childId) {
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
      return '${hoursF.toStringAsFixed(hoursF >= 10 ? 0 : 1)}s';
    }
    return '${ms ~/ 60000}d';
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
                    Text('${maxHours}s', style: _yAxisStyle),
                    Text('${(maxHours / 2).round()}s', style: _yAxisStyle),
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
                      _shortDays[(daily.date.weekday - 1) % 7],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.w400,
                        color: isToday
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label.isEmpty ? '—' : label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday
                            ? _todayBar
                            : AppColors.textTertiary,
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
