// Bola haftalik hisoboti: qadam, ekran vaqti va eng ko'p ishlatilgan
// ilovalar (oxirgi 7 kun, Toshkent vaqti bo'yicha).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/weekly_report/data/weekly_report_provider.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeeklyReportScreen extends ConsumerWidget {
  const WeeklyReportScreen({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyReportProvider(childId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(onBack: () => Navigator.of(context).maybePop()),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async {
                    ref
                        .read(weeklyReportRefreshProvider(childId).notifier)
                        .state++;
                    await ref.read(weeklyReportProvider(childId).future);
                  },
                  child: async.when(
                    data: (r) => _Body(report: r),
                    loading: () => const _Loading(),
                    error: (e, _) =>
                        _ErrorView(message: 'weeklyReport.error'.tr()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: onBack,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'weeklyReport.title'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'weeklyReport.subtitle'.tr(),
                  style: AppTextStyles.bodyS.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.report});
  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.xl,
      ),
      children: [
        _StepsCard(report: report),
        const SizedBox(height: AppDimensions.md),
        _ScreenTimeCard(report: report),
        const SizedBox(height: AppDimensions.md),
        _TopAppsCard(apps: report.topApps),
      ],
    );
  }
}

// ─── Qadam kartasi ───────────────────────────────────────────────────
class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.report});
  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final maxSteps = report.stepDays.fold<int>(
      1,
      (m, d) => d.steps > m ? d.steps : m,
    );
    return _Card(
      icon: Icons.directions_walk_rounded,
      title: 'weeklyReport.steps'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: _fmtInt(report.stepsWeekTotal),
                  label: 'weeklyReport.weekTotal'.tr(),
                ),
              ),
              const SizedBox(width: AppDimensions.lg),
              Expanded(
                child: _Stat(
                  value: _fmtInt(report.stepsDailyAvg),
                  label: 'weeklyReport.dailyAvg'.tr(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          _BarChart(
            values: report.stepDays.map((d) => d.steps.toDouble()).toList(),
            labels: report.stepDays.map((d) => _weekday(d.date)).toList(),
            maxValue: maxSteps.toDouble(),
            barColor: AppColors.primary,
            valueText: (v) => v >= 1000
                ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k'
                : v.toStringAsFixed(0),
          ),
        ],
      ),
    );
  }
}

// ─── Ekran vaqti kartasi ─────────────────────────────────────────────
class _ScreenTimeCard extends StatelessWidget {
  const _ScreenTimeCard({required this.report});
  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final maxMin = report.screenDays.fold<int>(
      1,
      (m, d) => d.totalMinutes > m ? d.totalMinutes : m,
    );
    final avgMin = (report.screenWeekMinutes / 7).round();
    return _Card(
      icon: Icons.timer_outlined,
      title: 'weeklyReport.screenTime'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: _fmtDuration(report.screenWeekMinutes),
                  label: 'weeklyReport.weekTotal'.tr(),
                ),
              ),
              const SizedBox(width: AppDimensions.lg),
              Expanded(
                child: _Stat(
                  value: _fmtDuration(avgMin),
                  label: 'weeklyReport.dailyAvg'.tr(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          _BarChart(
            values: report.screenDays
                .map((d) => d.totalMinutes.toDouble())
                .toList(),
            labels: report.screenDays.map((d) => _weekday(d.date)).toList(),
            maxValue: maxMin.toDouble(),
            barColor: AppColors.featurePurple,
            valueText: (v) => v >= 60
                ? 'weeklyReport.duration.hours'.tr(
                    namedArgs: {
                      'h': (v / 60).toStringAsFixed(v >= 600 ? 0 : 1),
                    },
                  )
                : 'weeklyReport.duration.minutes'.tr(
                    namedArgs: {'m': v.toStringAsFixed(0)},
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Top ilovalar kartasi ────────────────────────────────────────────
class _TopAppsCard extends StatelessWidget {
  const _TopAppsCard({required this.apps});
  final List<TopApp> apps;

  @override
  Widget build(BuildContext context) {
    final maxMin = apps.fold<int>(
      1,
      (m, a) => a.totalMinutes > m ? a.totalMinutes : m,
    );
    return _Card(
      icon: Icons.apps_rounded,
      title: 'weeklyReport.topApps'.tr(),
      child: apps.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'weeklyReport.noApps'.tr(),
                style: AppTextStyles.bodyS.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          : Column(
              children: [
                for (final a in apps)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                a.appName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyS.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _fmtDuration(a.totalMinutes),
                              style: AppTextStyles.bodyS.copyWith(
                                color: AppColors.textSecondary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (a.totalMinutes / maxMin).clamp(0.04, 1.0),
                            minHeight: 7,
                            backgroundColor: AppColors.surfaceVariant
                                .withValues(alpha: 0.6),
                            valueColor: AlwaysStoppedAnimation(AppColors.info),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ─── Umumiy karta ────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SettingsCard(
        accent: AppColors.info,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SettingsIconChip(icon: icon, accent: AppColors.info, size: 38),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.headlineL.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: AppTextStyles.bodyS.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ─── Oddiy bar chart (dependency-free) ───────────────────────────────
class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.values,
    required this.labels,
    required this.maxValue,
    required this.barColor,
    required this.valueText,
  });

  final List<double> values;
  final List<String> labels;
  final double maxValue;
  final Color barColor;
  final String Function(double) valueText;

  @override
  Widget build(BuildContext context) {
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final v = values[i];
          final ratio = (v / safeMax).clamp(0.0, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    v > 0 ? valueText(v) : '',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: (ratio * 78).clamp(v > 0 ? 4.0 : 2.0, 78.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [barColor, barColor.withValues(alpha: 0.55)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    labels[i],
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    return Center(child: CircularProgressIndicator(color: AppColors.primary));
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Text(
            message,
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────
String _fmtInt(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _fmtDuration(int minutes) {
  if (minutes < 60) {
    return 'weeklyReport.duration.minutes'.tr(namedArgs: {'m': '$minutes'});
  }
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0
      ? 'weeklyReport.duration.hours'.tr(namedArgs: {'h': '$h'})
      : 'weeklyReport.duration.hoursMinutes'.tr(
          namedArgs: {'h': '$h', 'm': '$m'},
        );
}

String _weekday(String date) {
  try {
    final d = DateTime.parse(date);
    // ISO weekday: 1 = dushanba ... 7 = yakshanba.
    return 'weeklyReport.weekdays.${d.weekday}'.tr();
  } catch (_) {
    return '';
  }
}
