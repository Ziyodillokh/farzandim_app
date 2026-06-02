import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/admin_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/error_state_view.dart';
import '../../core/widgets/skeletons.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _api = AdminApi();
  late Future<_DashboardPayload> _future;
  DateTime? _rangeFrom;
  DateTime? _rangeTo;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardPayload> _load() async {
    final data = await _api.getDashboard(from: _rangeFrom, to: _rangeTo);
    return _DashboardPayload.fromJson(data);
  }

  void _retry() {
    setState(() => _future = _load());
  }

  Future<void> _onRefresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _rangeFrom ?? DateTime(now.year, now.month, now.day),
        end: _rangeTo ?? now,
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _rangeFrom = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _rangeTo = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
          999,
        );
        _future = _load();
      });
    }
  }

  /// Shift chart range by the same number of whole days (mockup arrows).
  void _shiftRange(int direction) {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final startDay = _rangeFrom ?? DateTime(now.year, now.month, now.day);
    final endDay = _rangeTo ?? todayEnd;
    final nDays = endDay
            .difference(DateTime(startDay.year, startDay.month, startDay.day))
            .inDays +
        1;
    final step = nDays < 1 ? 1 : nDays;

    late DateTime from;
    late DateTime to;
    if (direction < 0) {
      from = DateTime(
        startDay.year,
        startDay.month,
        startDay.day,
      ).subtract(Duration(days: step));
      to = DateTime(from.year, from.month, from.day, 23, 59, 59, 999)
          .add(Duration(days: step - 1));
      if (from.isBefore(DateTime(2024))) {
        from = DateTime(2024);
        to = DateTime(from.year, from.month, from.day, 23, 59, 59, 999)
            .add(Duration(days: step - 1));
      }
    } else {
      from = DateTime(
        startDay.year,
        startDay.month,
        startDay.day,
      ).add(Duration(days: step));
      to = DateTime(from.year, from.month, from.day, 23, 59, 59, 999)
          .add(Duration(days: step - 1));
      if (from.isAfter(todayEnd)) return;
      if (to.isAfter(todayEnd)) {
        to = todayEnd;
        from = DateTime(to.year, to.month, to.day).subtract(Duration(days: step - 1));
      }
    }

    setState(() {
      _rangeFrom = DateTime(from.year, from.month, from.day);
      _rangeTo = to;
      _future = _load();
    });
  }

  String _fmtInt(int n) => NumberFormat('#,###', 'en_US').format(n);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: FutureBuilder<_DashboardPayload>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const DashboardSkeleton();
          }
          if (snapshot.hasError) {
            return AppErrorStateView(
              error: snapshot.error!,
              onRetry: _retry,
              title: 'Dashboard yuklanmadi',
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: AppPrimaryButton(label: 'Qayta urinish', onPressed: _retry),
            );
          }

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: [
                AdminPageHeader(
                  title: 'Dashboard',
                  subtitle: 'Foydalanuvchilar',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Oldingi davr',
                        onPressed: () => _shiftRange(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                        style: IconButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Keyingi davr',
                        onPressed: () => _shiftRange(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                        style: IconButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.calendar_today_outlined, size: 18),
                        label: const Text('Sana'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    // 5 ta KPI card — ekran kengligiga qarab necha qatorda
                    // joylashishi: >=1400 → 5/row, >=1100 → 3/row, >=720 → 2/row, < → 1/row
                    final int perRow = w >= 1400
                        ? 5
                        : w >= 1100
                            ? 3
                            : w >= 720
                                ? 2
                                : 1;
                    final cardW = (w - AppSpacing.sm * (perRow - 1)) / perRow;
                    return Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _KpiCard(
                          width: cardW,
                          title: 'Bugungi kirishlar',
                          value: _fmtInt(data.summary.todayLogins),
                          trendPct: data.trends.todayLogins,
                          accent: const Color(0xFF8B5CF6),
                          icon: Icons.login_rounded,
                        ),
                        _KpiCard(
                          width: cardW,
                          title: 'Yuklangan videolar',
                          value: _fmtInt(data.summary.videosUploaded),
                          trendPct: data.trends.videosUploaded,
                          accent: const Color(0xFF3B82F6),
                          icon: Icons.video_library_outlined,
                        ),
                        _KpiCard(
                          width: cardW,
                          title: 'Audiokitoblar',
                          value: _fmtInt(data.summary.audiobooks),
                          trendPct: data.trends.audiobooks,
                          accent: const Color(0xFFF59E0B),
                          icon: Icons.headphones_outlined,
                        ),
                        _KpiCard(
                          width: cardW,
                          title: 'Faol konkurslar',
                          value: _fmtInt(data.summary.activeContests),
                          trendPct: data.trends.activeContests,
                          accent: const Color(0xFFEC4899),
                          icon: Icons.emoji_events_outlined,
                        ),
                        _KpiCard(
                          width: cardW,
                          title: 'Pullik tarif sotib olganlar',
                          value: _fmtInt(data.summary.paidPlanBuyers),
                          trendPct: data.trends.paidPlanBuyers,
                          accent: AppColors.primaryDark,
                          icon: Icons.workspace_premium_outlined,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, c) {
                    if (c.maxWidth >= 900) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _UsersLineCard(
                              title: 'Jami foydalanuvchilar',
                              chart: data.usersGrowth,
                              onInterval: _pickDateRange,
                              fmt: _fmtInt,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _UsersLineCard(
                              title: 'Faol foydalanuvchilar',
                              chart: data.activeUsers,
                              onInterval: _pickDateRange,
                              fmt: _fmtInt,
                              activeStyle: true,
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _UsersLineCard(
                          title: 'Jami foydalanuvchilar',
                          chart: data.usersGrowth,
                          onInterval: _pickDateRange,
                          fmt: _fmtInt,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _UsersLineCard(
                          title: 'Faol foydalanuvchilar',
                          chart: data.activeUsers,
                          onInterval: _pickDateRange,
                          fmt: _fmtInt,
                          activeStyle: true,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Summary {
  const _Summary({
    required this.todayLogins,
    required this.videosUploaded,
    required this.audiobooks,
    required this.activeContests,
    required this.paidPlanBuyers,
  });

  final int todayLogins;
  final int videosUploaded;
  final int audiobooks;
  final int activeContests;
  final int paidPlanBuyers;

  factory _Summary.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return const _Summary(
        todayLogins: 0,
        videosUploaded: 0,
        audiobooks: 0,
        activeContests: 0,
        paidPlanBuyers: 0,
      );
    }
    int g(String k) => (j[k] as num?)?.toInt() ?? 0;
    return _Summary(
      todayLogins: g('todayLogins'),
      videosUploaded: g('videosUploaded'),
      audiobooks: g('audiobooks'),
      activeContests: g('activeContests'),
      paidPlanBuyers: g('paidPlanBuyers'),
    );
  }
}

class _Trends {
  const _Trends({
    required this.todayLogins,
    required this.videosUploaded,
    required this.audiobooks,
    required this.activeContests,
    required this.paidPlanBuyers,
  });

  final double todayLogins;
  final double videosUploaded;
  final double audiobooks;
  final double activeContests;
  final double paidPlanBuyers;

  factory _Trends.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return const _Trends(
        todayLogins: 0,
        videosUploaded: 0,
        audiobooks: 0,
        activeContests: 0,
        paidPlanBuyers: 0,
      );
    }
    double g(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return _Trends(
      todayLogins: g('todayLogins'),
      videosUploaded: g('videosUploaded'),
      audiobooks: g('audiobooks'),
      activeContests: g('activeContests'),
      paidPlanBuyers: g('paidPlanBuyers'),
    );
  }
}

class _LineChartData {
  const _LineChartData({
    required this.headlineTotal,
    required this.changePercent,
    required this.labels,
    required this.parentSeries,
    required this.childSeries,
  });

  final int headlineTotal;
  final double changePercent;
  final List<String> labels;
  final List<int> parentSeries;
  final List<int> childSeries;

  factory _LineChartData.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return const _LineChartData(
        headlineTotal: 0,
        changePercent: 0,
        labels: [],
        parentSeries: [],
        childSeries: [],
      );
    }
    List<int> ints(String k) {
      final v = j[k];
      if (v is! List) return [];
      return v.map((e) => (e as num).toInt()).toList();
    }

    return _LineChartData(
      headlineTotal: (j['headlineTotal'] as num?)?.toInt() ?? 0,
      changePercent: (j['changePercent'] as num?)?.toDouble() ?? 0,
      labels: (j['labels'] as List?)?.map((e) => e.toString()).toList() ?? [],
      parentSeries: ints('parentSeries'),
      childSeries: ints('childSeries'),
    );
  }
}

class _DashboardPayload {
  const _DashboardPayload({
    required this.summary,
    required this.trends,
    required this.usersGrowth,
    required this.activeUsers,
  });

  final _Summary summary;
  final _Trends trends;
  final _LineChartData usersGrowth;
  final _LineChartData activeUsers;

  factory _DashboardPayload.fromJson(Map<String, dynamic> j) {
    final chartsJ = j['charts'] as Map<String, dynamic>?;
    return _DashboardPayload(
      summary: _Summary.fromJson(j['summary'] as Map<String, dynamic>?),
      trends: _Trends.fromJson(j['trends'] as Map<String, dynamic>?),
      usersGrowth: _LineChartData.fromJson(
        chartsJ?['usersGrowth'] as Map<String, dynamic>?,
      ),
      activeUsers: _LineChartData.fromJson(
        chartsJ?['activeUsers'] as Map<String, dynamic>?,
      ),
    );
  }
}

const Color _parentLine = Color(0xFF1E40AF);
const Color _childLine = Color(0xFF22C55E);

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.width,
    required this.title,
    required this.value,
    required this.trendPct,
    required this.accent,
    required this.icon,
  });

  final double width;
  final String title;
  final String value;
  final double trendPct;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final up = trendPct >= 0;
    final trendColor = up ? AppColors.success : AppColors.warning;
    return SizedBox(
      width: width,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.statTitle.copyWith(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(value, style: AppTextStyles.statValue),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        up ? Icons.trending_up : Icons.trending_down,
                        size: 14,
                        color: trendColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${up ? '+' : ''}${trendPct.toStringAsFixed(1)}% kechagi bilan',
                          style: TextStyle(
                            fontSize: 11,
                            color: trendColor,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersLineCard extends StatelessWidget {
  const _UsersLineCard({
    required this.title,
    required this.chart,
    required this.onInterval,
    required this.fmt,
    this.activeStyle = false,
  });

  final String title;
  final _LineChartData chart;
  final VoidCallback onInterval;
  final String Function(int) fmt;
  final bool activeStyle;

  @override
  Widget build(BuildContext context) {
    final spotsP = _spots(chart.parentSeries);
    final spotsC = _spots(chart.childSeries);
    final maxY = _maxY([...chart.parentSeries, ...chart.childSeries]);

    final trendUp = chart.changePercent >= 0;
    final trendColor = activeStyle && !trendUp
        ? AppColors.warning
        : (trendUp ? AppColors.success : AppColors.warning);

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: AppTextStyles.sectionTitle),
                ),
                OutlinedButton(
                  onPressed: onInterval,
                  child: const Text('Oraliq'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(fmt(chart.headlineTotal), style: AppTextStyles.statValue),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: trendColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    trendUp ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: trendColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${trendUp ? '+' : ''}${chart.changePercent.toStringAsFixed(1)}% oldingi davr bilan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: trendColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _legendDot(_parentLine, 'Ota-ona'),
                const SizedBox(width: AppSpacing.md),
                _legendDot(_childLine, 'Farzand'),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 220,
              child: spotsP.isEmpty && spotsC.isEmpty
                  ? const Center(
                      child: Text(
                        'Tanlangan davr uchun ma\'lumot yo\'q',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: mathMaxX(spotsP, spotsC),
                        minY: 0,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => const FlLine(
                            color: AppColors.border,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (v, m) => Text(
                                v.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              interval: 1,
                              getTitlesWidget: (v, m) {
                                final i = v.toInt();
                                if (i < 0 || i >= chart.labels.length) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  chart.labels[i],
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          if (spotsP.isNotEmpty)
                            LineChartBarData(
                              spots: spotsP,
                              isCurved: true,
                              barWidth: 3,
                              color: _parentLine,
                              dotData: const FlDotData(show: false),
                            ),
                          if (spotsC.isNotEmpty)
                            LineChartBarData(
                              spots: spotsC,
                              isCurved: true,
                              barWidth: 3,
                              color: _childLine,
                              dotData: const FlDotData(show: false),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static List<FlSpot> _spots(List<int> s) {
    if (s.isEmpty) return [];
    return List.generate(
      s.length,
      (i) => FlSpot(i.toDouble(), s[i].toDouble()),
    );
  }

  static double _maxY(List<int> values) {
    if (values.isEmpty) return 4;
    final m = values.reduce((a, b) => a > b ? a : b);
    return (m * 1.15).clamp(4, double.infinity);
  }

  static double mathMaxX(List<FlSpot> a, List<FlSpot> b) {
    final na = a.length;
    final nb = b.length;
    final n = na > nb ? na : nb;
    return n <= 1 ? 1 : (n - 1).toDouble();
  }

  static Widget _legendDot(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}