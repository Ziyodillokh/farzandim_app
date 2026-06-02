import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/admin_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/error_state_view.dart';
import '../../core/widgets/skeletons.dart';

/// Moliyaviy tahlil — GET /admin/analytics/monetization (real data, 6 oy).
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final _api = AdminApi();
  Future<MonetizationVm>? _future;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _future = _fetch();

    _poll = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<MonetizationVm> _fetch() async {
    final m = await _api.getMonetizationAnalytics();
    return MonetizationVm.fromJson(m);
  }

  void _load() {
    setState(() {
      _future = _fetch();
    });
  }

  String _formatSom(int n) {
    if (n == 0) {
      return "0 so'm";
    }
    return "${NumberFormat('#,###', 'en').format(n).replaceAll(',', ' ')} so'm";
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MonetizationVm>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const AnalyticsSkeleton();
        }
        if (snapshot.hasError) {
          return AppErrorStateView(
            error: snapshot.error!,
            onRetry: _load,
            title: 'Tahlil yuklanmadi',
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const EmptyStateView(
            title: "Ma'lumot yo'q",
            subtitle: "To'lov va obunalar paydo bo'lgach grafiklar to'ldiriladi.",
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _future = _fetch());
            await _future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              const Text(
                'Moliyaviy statistika va trendlar',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              const AdminPageHeader(
                title: 'Tahlil',
                subtitle: "Obunalar va to'lovlar",
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth > 1000;
                  final children = <Widget>[
                    _Kpi(
                      icon: Icons.attach_money_rounded,
                      iconBg: const Color(0xFF22C55E),
                      value: _formatSom(data.totalRevenue),
                      label: "Jami daromad (6 oy)",
                      showTrend: true,
                    ),
                    _Kpi(
                      icon: Icons.people_alt_rounded,
                      iconBg: const Color(0xFF3B82F6),
                      value: '${data.totalUsers}',
                      label: "Jami foydalanuvchilar",
                    ),
                    _Kpi(
                      icon: Icons.gps_fixed_rounded,
                      iconBg: const Color(0xFF8B5CF6),
                      value: _formatSom(data.avgMonthlyRevenue),
                      label: "O'rtacha oylik daromad",
                    ),
                    _Kpi(
                      icon: Icons.trending_up_rounded,
                      iconBg: const Color(0xFFFF9800),
                      value: '${data.payingPercent}%',
                      label: "Pullik foydalanuvchilar",
                    ),
                  ];
                  if (wide) {
                    return Row(
                      children: [
                        for (var i = 0; i < 4; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(child: children[i]),
                        ],
                      ],
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        children[i],
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth > 1000;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _LineCard(data: data)),
                        const SizedBox(width: 12),
                        Expanded(child: _PieCard(data: data)),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _LineCard(data: data),
                      const SizedBox(height: 12),
                      _PieCard(data: data),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth > 1000;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _BarGrowthCard(data: data)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _HorizontalRevCard(
                            data: data,
                            formatSom: _formatSom,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _BarGrowthCard(data: data),
                      const SizedBox(height: 12),
                      _HorizontalRevCard(
                        data: data,
                        formatSom: _formatSom,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class MonetizationVm {
  MonetizationVm({
    required this.totalRevenue,
    required this.totalUsers,
    required this.avgMonthlyRevenue,
    required this.payingPercent,
    required this.monthlyRevenue,
    required this.planDistribution,
    required this.subscriptionGrowth,
    required this.revenueByPlan,
    required this.revenueByPlanTotal,
  });

  final int totalRevenue;
  final int totalUsers;
  final int avgMonthlyRevenue;
  final double payingPercent;
  final List<MonthlyAmount> monthlyRevenue;
  final List<PlanDist> planDistribution;
  final List<GrowthRow> subscriptionGrowth;
  final List<RevenueBar> revenueByPlan;
  final int revenueByPlanTotal;

  static MonetizationVm fromJson(Map<String, dynamic> j) {
    final mr = (j['monthlyRevenue'] as List?) ?? const [];
    final pd = (j['planDistribution'] as List?) ?? const [];
    final sg = (j['subscriptionGrowth'] as List?) ?? const [];
    final rb = (j['revenueByPlan'] as List?) ?? const [];
    return MonetizationVm(
      totalRevenue: (j['totalRevenue'] as num?)?.toInt() ?? 0,
      totalUsers: (j['totalUsers'] as num?)?.toInt() ?? 0,
      avgMonthlyRevenue: (j['avgMonthlyRevenue'] as num?)?.toInt() ?? 0,
      payingPercent: (j['payingPercent'] as num?)?.toDouble() ?? 0,
      monthlyRevenue: mr
          .map((e) => MonthlyAmount.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      planDistribution: pd
          .map((e) => PlanDist.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      subscriptionGrowth: sg
          .map((e) => GrowthRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      revenueByPlan: rb
          .map((e) => RevenueBar.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      revenueByPlanTotal: (j['revenueByPlanTotal'] as num?)?.toInt() ?? 0,
    );
  }
}

class MonthlyAmount {
  MonthlyAmount({required this.label, required this.amount});
  final String label;
  final int amount;

  factory MonthlyAmount.fromJson(Map<String, dynamic> j) {
    return MonthlyAmount(
      label: (j['label'] ?? '').toString(),
      amount: (j['amount'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlanDist {
  PlanDist({required this.key, required this.label, required this.count, required this.percent});
  final String key;
  final String label;
  final int count;
  final double percent;

  factory PlanDist.fromJson(Map<String, dynamic> j) {
    return PlanDist(
      key: (j['key'] ?? '').toString(),
      label: (j['label'] ?? '').toString(),
      count: (j['count'] as num?)?.toInt() ?? 0,
      percent: (j['percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class GrowthRow {
  GrowthRow({
    required this.label,
    required this.bepul,
    required this.oylik,
    required this.yillik,
  });
  final String label;
  final int bepul;
  final int oylik;
  final int yillik;

  factory GrowthRow.fromJson(Map<String, dynamic> j) {
    return GrowthRow(
      label: (j['label'] ?? '').toString(),
      bepul: (j['bepul'] as num?)?.toInt() ?? 0,
      oylik: (j['oylik'] as num?)?.toInt() ?? 0,
      yillik: (j['yillik'] as num?)?.toInt() ?? 0,
    );
  }
}

class RevenueBar {
  RevenueBar({required this.key, required this.label, required this.amount});
  final String key;
  final String label;
  final int amount;

  factory RevenueBar.fromJson(Map<String, dynamic> j) {
    return RevenueBar(
      key: (j['key'] ?? '').toString(),
      label: (j['label'] ?? '').toString(),
      amount: (j['amount'] as num?)?.toInt() ?? 0,
    );
  }
}

const _lime = Color(0xFFA6E22E);
const _blue = Color(0xFF4A90E2);
const _slate = Color(0xFF64748B);

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.icon,
    required this.iconBg,
    required this.value,
    required this.label,
    this.showTrend = false,
  });

  final IconData icon;
  final Color iconBg;
  final String value;
  final String label;
  final bool showTrend;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const Spacer(),
              if (showTrend)
                const Icon(
                  Icons.trending_up,
                  size: 18,
                  color: Color(0xFF22C55E),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.data});

  final MonetizationVm data;

  @override
  Widget build(BuildContext context) {
    final pts = data.monthlyRevenue;
    if (pts.isEmpty) {
      return AppCard(
        child: const SizedBox(
          height: 220,
          child: Center(child: Text("Ma'lumot yo'q")),
        ),
      );
    }
    final maxY = pts
            .map((e) => e.amount)
            .fold<int>(0, (a, b) => a > b ? a : b)
            .toDouble() *
        1.15;
    final minY = 0.0;
    final h = (maxY < 1 ? 1.0 : maxY).toDouble();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Oylik daromad",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (pts.length - 1).toDouble().clamp(0, double.infinity),
                minY: minY,
                maxY: h,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0xFFE5E7EB),
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
                      reservedSize: 40,
                      getTitlesWidget: (v, m) {
                        if (v > h) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          _shortMoney(v),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (v, m) {
                        final i = v.toInt();
                        if (i < 0 || i >= pts.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          pts[i].label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      pts.length,
                      (i) => FlSpot(
                        i.toDouble(),
                        pts[i].amount.toDouble(),
                      ),
                    ),
                    isCurved: true,
                    color: _lime,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (s, p, b, i) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: _lime,
                          strokeWidth: 1,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortMoney(double v) {
    if (v >= 1e6) {
      return "${(v / 1e6).toStringAsFixed(0)}M";
    }
    if (v >= 1000) {
      return "${(v / 1000).round()}k";
    }
    return v.toInt().toString();
  }
}

class _PieCard extends StatelessWidget {
  const _PieCard({required this.data});

  final MonetizationVm data;

  @override
  Widget build(BuildContext context) {
    final p = data.planDistribution;
    if (p.isEmpty) {
      return AppCard(
        child: const SizedBox(
          height: 280,
          child: Center(child: Text("Obuna taqsimoti yo'q")),
        ),
      );
    }
    const colors = [_slate, _lime, _blue];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Tarif bo‘yicha taqsimot",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 44,
                sectionsSpace: 1,
                sections: List.generate(p.length, (i) {
                  final e = p[i];
                  return PieChartSectionData(
                    value: (e.count > 0 ? e.count : 1).toDouble(),
                    title: "${e.percent.toStringAsFixed(0)}%",
                    color: colors[i % colors.length],
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              for (var i = 0; i < p.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${p[i].label}: ${p[i].count}",
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarGrowthCard extends StatelessWidget {
  const _BarGrowthCard({required this.data});

  final MonetizationVm data;

  @override
  Widget build(BuildContext context) {
    final rows = data.subscriptionGrowth;
    if (rows.isEmpty) {
      return AppCard(
        child: const SizedBox(
          height: 260,
          child: Center(child: Text("Ma'lumot yo'q")),
        ),
      );
    }
    var maxV = 1;
    for (final r in rows) {
      final s = r.bepul + r.oylik + r.yillik;
      if (s > maxV) {
        maxV = s;
      }
    }
    final maxY = (maxV * 1.1).ceilToDouble();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Obunalar o‘sishi",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                barGroups: List.generate(rows.length, (i) {
                  final r = rows[i];
                  return BarChartGroupData(
                    x: i,
                    groupVertically: false,
                    barRods: [
                      BarChartRodData(
                        toY: r.bepul.toDouble(),
                        color: _slate,
                        width: 6,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2),
                        ),
                      ),
                      BarChartRodData(
                        toY: r.oylik.toDouble(),
                        color: _lime,
                        width: 6,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2),
                        ),
                      ),
                      BarChartRodData(
                        toY: r.yillik.toDouble(),
                        color: _blue,
                        width: 6,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2),
                        ),
                      ),
                    ],
                    barsSpace: 2,
                  );
                }),
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
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        if (v > maxY) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          v.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (v, m) {
                        final i = v.toInt();
                        if (i < 0 || i >= rows.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          rows[i].label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) {
                    if (v == 0) {
                      return const FlLine(color: Colors.transparent, strokeWidth: 0);
                    }
                    return const FlLine(
                      color: Color(0xFFE5E7EB),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Leg(color: _slate, text: "Bepul"),
              SizedBox(width: 12),
              _Leg(color: _lime, text: "Oylik"),
              SizedBox(width: 12),
              _Leg(color: _blue, text: "Yillik"),
            ],
          ),
        ],
      ),
    );
  }
}

class _Leg extends StatelessWidget {
  const _Leg({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _HorizontalRevCard extends StatelessWidget {
  const _HorizontalRevCard({required this.data, required this.formatSom});

  final MonetizationVm data;
  final String Function(int) formatSom;

  @override
  Widget build(BuildContext context) {
    final list = data.revenueByPlan;
    final maxA = list.isEmpty
        ? 1
        : list.map((e) => e.amount).fold<int>(0, (a, b) => a > b ? a : b);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Tarif bo‘yicha daromad",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            const Text(
              "To'lov (tarif) yo'q yoki hali katalogga bog'lanmagan",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            )
          else
            for (final e in list) ...[
              Text(
                e.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: maxA > 0 ? (e.amount / maxA).clamp(0, 1) : 0,
                  minHeight: 14,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(_lime),
                ),
              ),
              const SizedBox(height: 10),
            ],
          if (list.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Jami daromad: ${formatSom(data.revenueByPlanTotal)}",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
