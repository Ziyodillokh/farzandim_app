// Qadam batafsil ekrani — dashboard "Kunlik qadamlar" kartasi bosilganda
// ochiladi. Bugungi qadam (maqsadga nisbatan halqa), haftalik ustunli grafik
// (har kun ANIQ qadam soni), jami / o'rtacha / eng faol kun.
//
// Ma'lumot: `weeklyStepsProvider(childId)` -> WeeklySteps (oxirgi 7 kun).

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_usage_repository.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ── Tokenlar (dashboard bilan bir xil) ──
const _bg = Color(0xFF00060A);
const _bgTop = Color(0xFF0A2942);
const _panel = Color(0xFF11161C);
const _panel2 = Color(0xFF161C24);
const _blue = Color(0xFF216BFF);
const _blueSoft = Color(0xFF5D8BFF);
const _dim = Color(0x8CFFFFFF);
const _line = Color(0x14FFFFFF);
const _goal = 10000;

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.5,
}) => GoogleFonts.unbounded(
  fontSize: s,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.2,
);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.35);

String _fmt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

const _weekdayShort = ['Du', 'Se', 'Cho', 'Pa', 'Ju', 'Sha', 'Ya'];
const _weekdayFull = [
  'Dushanba',
  'Seshanba',
  'Chorshanba',
  'Payshanba',
  'Juma',
  'Shanba',
  'Yakshanba',
];

class StepsDetailScreen extends ConsumerWidget {
  const StepsDetailScreen({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(weeklyStepsProvider(childId)).valueOrNull;
    final now = DateTime.now();
    String key(DateTime d) => '${d.year}-${d.month}-${d.day}';
    final byDay = <String, int>{
      for (final d in weekly?.days ?? const <DailySteps>[])
        key(d.date): d.steps,
    };

    // Joriy hafta Du..Ya (7 kun).
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final week = <_DaySteps>[
      for (var i = 0; i < 7; i++)
        _DaySteps(
          date: monday.add(Duration(days: i)),
          steps: byDay[key(monday.add(Duration(days: i)))] ?? 0,
          isToday: i == now.weekday - 1,
          isFuture: monday.add(Duration(days: i)).isAfter(now),
        ),
    ];
    final today = week[now.weekday - 1].steps;
    final total = week.fold<int>(0, (a, d) => a + d.steps);
    final activeDays = week.where((d) => d.steps > 0).length;
    final avg = activeDays == 0 ? 0 : (total / activeDays).round();
    final best = week.fold<int>(0, (a, d) => math.max(a, d.steps));

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const _Backdrop(),
          SafeArea(
            child: Column(
              children: [
                _Header(title: 'stepsDetail.title'.tr()),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      _HeroRing(steps: today, goal: _goal),
                      const SizedBox(height: 18),
                      _StatsRow(total: total, avg: avg, best: best),
                      const SizedBox(height: 18),
                      _WeeklyChart(week: week, best: math.max(best, 1)),
                      const SizedBox(height: 18),
                      Text('stepsDetail.byDay'.tr(), style: _unb(16)),
                      const SizedBox(height: 10),
                      for (var i = 6; i >= 0; i--)
                        if (!week[i].isFuture)
                          _DayRow(day: week[i], best: math.max(best, 1)),
                    ],
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

// ── Bugungi qadam — halqa (progress ring) ──
class _HeroRing extends StatelessWidget {
  const _HeroRing({required this.steps, required this.goal});

  final int steps;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final pct = (steps / goal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF13202F), Color(0xFF0B1119)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 190,
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 190,
                  height: 190,
                  child: CustomPaint(painter: _RingPainter(pct)),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/ic_steps.png',
                      width: 34,
                      height: 34,
                    ),
                    const SizedBox(height: 6),
                    Text(_fmt(steps), style: _unb(32, ls: -1)),
                    Text('/ ${_fmt(goal)}', style: _pop(12.5, c: _dim)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'stepsDetail.todayPct'.tr(
              namedArgs: {'pct': '${(pct * 100).round()}'},
            ),
            style: _pop(13.5, c: _blueSoft, w: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.pct);
  final double pct;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 9;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x1AFFFFFF);
    canvas.drawCircle(c, r, bg);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [_blue, _blueSoft, _blue],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * pct,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.pct != pct;
}

// ── Jami / o'rtacha / eng faol ──
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.total, required this.avg, required this.best});
  final int total;
  final int avg;
  final int best;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: 'stepsDetail.weekTotal'.tr(),
            value: _fmt(total),
            tint: _blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            label: 'stepsDetail.dailyAvg'.tr(),
            value: _fmt(avg),
            tint: const Color(0xFF34D399),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            label: 'stepsDetail.best'.tr(),
            value: _fmt(best),
            tint: const Color(0xFFF5C451),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.tint,
  });
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Text(value, style: _unb(17, c: tint)),
          const SizedBox(height: 4),
          Text(
            label,
            style: _pop(10.5, c: _dim),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Haftalik ustunli grafik ──
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.week, required this.best});
  final List<_DaySteps> week;
  final int best;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('stepsDetail.week'.tr(), style: _unb(15)),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _Bar(
                      day: week[i],
                      frac: week[i].isFuture
                          ? 0
                          : (week[i].steps / best).clamp(0.0, 1.0),
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

class _Bar extends StatelessWidget {
  const _Bar({required this.day, required this.frac});
  final _DaySteps day;
  final double frac;

  @override
  Widget build(BuildContext context) {
    const maxH = 110.0;
    final h = math.max<double>(6, maxH * frac);
    final active = day.steps > 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          active ? _fmt(day.steps) : '',
          style: _pop(9, c: day.isToday ? _blueSoft : _dim, w: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Container(
          width: 22,
          height: h,
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: day.isToday
                        ? const [_blue, _blueSoft]
                        : const [Color(0xFF2A4A6E), Color(0xFF3A6091)],
                  )
                : null,
            color: active ? null : const Color(0x12FFFFFF),
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _weekdayShort[day.date.weekday - 1],
          style: _pop(
            11,
            c: day.isToday ? Colors.white : _dim,
            w: day.isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ── Har kun bir qator (aniq son) ──
class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.best});
  final _DaySteps day;
  final int best;

  @override
  Widget build(BuildContext context) {
    final frac = (day.steps / best).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: day.isToday ? const Color(0xFF122135) : _panel2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: day.isToday ? const Color(0x3F216BFF) : _line,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              day.isToday
                  ? 'stepsDetail.today'.tr()
                  : _weekdayFull[day.date.weekday - 1],
              style: _pop(
                13.5,
                w: FontWeight.w600,
                c: day.isToday ? _blueSoft : Colors.white,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 7,
                backgroundColor: const Color(0x14FFFFFF),
                valueColor: AlwaysStoppedAnimation(
                  day.steps > 0 ? _blue : Colors.transparent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(_fmt(day.steps), style: _unb(15, ls: -0.4)),
        ],
      ),
    );
  }
}

class _DaySteps {
  const _DaySteps({
    required this.date,
    required this.steps,
    required this.isToday,
    required this.isFuture,
  });
  final DateTime date;
  final int steps;
  final bool isToday;
  final bool isFuture;
}

// ── Header + fon ──
class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                SolarIconsBold.altArrowLeft,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(title, style: _unb(20, ls: -0.6)),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bg],
            stops: [0, 0.4],
          ),
        ),
      ),
    );
  }
}
