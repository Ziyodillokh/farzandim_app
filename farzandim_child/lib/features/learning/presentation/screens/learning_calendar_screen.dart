// ─────────────────────────────────────────────────────────────────────
// LearningCalendarScreen — testlar kalendari (`/learn/calendar`)
// ─────────────────────────────────────────────────────────────────────
//
// Ketma-ket faol kunlar, oy kalendari (kun natijasi rangida) va tanlangan
// kundagi natijalar. Bugungi reja tugamagan bo'lsa — "Boshlash".

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/domain/learning_stats.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/presentation/learning_navigation.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/calendar/month_calendar.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/setup/setup_widgets.dart';
import 'package:farzandim_child/features/progress/presentation/widgets/result_row.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/inner_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

class LearningCalendarScreen extends ConsumerStatefulWidget {
  const LearningCalendarScreen({super.key});

  @override
  ConsumerState<LearningCalendarScreen> createState() =>
      _LearningCalendarScreenState();
}

class _LearningCalendarScreenState
    extends ConsumerState<LearningCalendarScreen> {
  late final DateTime _today = dayOf(ref.read(learningClockProvider)());
  late DateTime _month = DateTime(_today.year, _today.month);
  late DateTime _selected = _today;

  void _shiftMonth(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
  });

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(learningResultsProvider);
    final plan = ref.watch(dailyPlanProvider);
    final streak = ref.watch(learningStreakProvider);

    final byDay = <DateTime, List<TestResult>>{};
    for (final r in results) {
      (byDay[dayOf(r.date)] ??= []).add(r);
    }
    final dayPercent = {
      for (final e in byDay.entries) e.key: percentOf(e.value) ?? 0,
    };
    final activeThisMonth = byDay.keys
        .where((d) => d.year == _month.year && d.month == _month.month)
        .length;
    final earliest = results.isEmpty ? _today : dayOf(results.last.date);
    final canPrev = DateTime(earliest.year, earliest.month).isBefore(_month);
    final canNext = _month.isBefore(DateTime(_today.year, _today.month));
    final dayResults = byDay[_selected] ?? const <TestResult>[];
    final showCta =
        isSameDay(_selected, _today) && !plan.isEmpty && !plan.isComplete;

    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: DesignScale(
        child: Builder(
          builder: (context) {
            final insets = MediaQuery.paddingOf(context);
            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                growthTopInset(context),
                16,
                insets.bottom + 24,
              ),
              children: [
                InnerPageHeader(
                  title: 'learn.calendarTitle'.tr(),
                  subtitle: 'learn.calendarSubtitle'.tr(),
                  fallbackRoute: '/progress',
                ),
                const SizedBox(height: 18),
                _StreakCard(streak: streak, activeDays: activeThisMonth),
                const SizedBox(height: 12),
                MonthCalendar(
                  month: _month,
                  today: _today,
                  selected: _selected,
                  dayPercent: dayPercent,
                  onSelect: (d) => setState(() => _selected = d),
                  onPrev: canPrev ? () => _shiftMonth(-1) : null,
                  onNext: canNext ? () => _shiftMonth(1) : null,
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        isSameDay(_selected, _today)
                            ? 'common.today'.tr()
                            : localizedDayMonth(_selected),
                        style: homeText(19, weight: FontWeight.w800),
                      ),
                    ),
                    if (dayResults.isNotEmpty)
                      Text(
                        'learn.dayTests'.plural(dayResults.length),
                        style: homeText(13, color: HomeColors.textDim),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (dayResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'learn.noTestsDay'.tr(),
                      textAlign: TextAlign.center,
                      style: homeText(14, color: HomeColors.textDim),
                    ),
                  )
                else
                  for (var i = 0; i < dayResults.length; i++) ...[
                    if (i > 0) const SizedBox(height: 7),
                    ResultRow(result: dayResults[i]),
                  ],
                if (showCta) ...[
                  const SizedBox(height: 14),
                  SetupButton(
                    label: 'learn.todayCta'.tr(),
                    onTap: () => startDailyLearning(context, ref),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.activeDays});

  final int streak;
  final int activeDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: homeCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HomeColors.amber.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              SolarIconsBold.fire,
              size: 26,
              color: HomeColors.amber,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FitText(
                  'learn.streak'.plural(streak),
                  style: homeDisplay(20, letterSpacing: -0.2),
                ),
                const SizedBox(height: 3),
                FitText(
                  'learn.activeDays'.plural(activeDays),
                  style: homeText(13, color: HomeColors.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
