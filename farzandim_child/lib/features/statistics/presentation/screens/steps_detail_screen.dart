// Qadam batafsil ekrani — "Kunlik qadamlar" kartasi bosilganda ochiladi.
// Bugungi qadam (maqsad halqasi), hafta trekeri va qadamdan topilgan don.

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

const _bg = Color(0xFF00060A);
const _bgTop = Color(0xFF0A2942);
const _panel = Color(0xFF161C24);
const _dim = Color(0x8CFFFFFF);
const _line = Color(0x14FFFFFF);
const _blue = Color(0xFF216BFF);
const _blueSoft = Color(0xFF66B3FF);
const _goal = 10000;

const _weekShort = ['Du', 'Se', 'Cho', 'Pa', 'Ju', 'Sha', 'Ya'];

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

class StepsDetailScreen extends ConsumerWidget {
  const StepsDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = ref.watch(todayStepsProvider).valueOrNull ?? 0;
    final donToday = (steps ~/ 1000) * 5;
    final todayIdx = DateTime.now().weekday - 1;

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
                      _StepsHero(steps: steps),
                      const SizedBox(height: 18),
                      _DonRow(donToday: donToday),
                      const SizedBox(height: 20),
                      Text('stepsDetail.week'.tr(), style: _unb(16)),
                      const SizedBox(height: 12),
                      _WeekBars(todayIdx: todayIdx, todaySteps: steps),
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

class _StepsHero extends StatelessWidget {
  const _StepsHero({required this.steps});

  final int steps;

  @override
  Widget build(BuildContext context) {
    final pct = (steps / _goal).clamp(0.0, 1.0);
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
            width: 196,
            height: 196,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x33216BFF), Color(0x00216BFF)],
                    ),
                  ),
                ),
                SizedBox(
                  width: 196,
                  height: 196,
                  child: CustomPaint(painter: _RingPainter(pct)),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/badge_steps.png',
                      width: 40,
                      height: 40,
                    ),
                    const SizedBox(height: 4),
                    Text(_fmt(steps), style: _unb(34, ls: -1.2)),
                    Text('/ ${_fmt(_goal)}', style: _pop(12, c: _dim)),
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

// ── Qadamdan don qatori ──
class _DonRow extends StatelessWidget {
  const _DonRow({required this.donToday});

  final int donToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.stars_rounded, color: _blueSoft, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('stepsDetail.donInfo'.tr(), style: _pop(12.5, c: _dim)),
                const SizedBox(height: 2),
                Text(
                  'stepsDetail.donToday'.tr(namedArgs: {'n': '$donToday'}),
                  style: _unb(16, ls: -0.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hafta ustunlari (bugun aniq, qolgani preview) ──
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.todayIdx, required this.todaySteps});

  final int todayIdx;
  final int todaySteps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: _Bar(
                label: _weekShort[i],
                isToday: i == todayIdx,
                // Bugun real; boshqa kunlar hali ma'lumotsiz (0).
                frac: i == todayIdx
                    ? (todaySteps / _goal).clamp(0.06, 1.0)
                    : 0.0,
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.isToday, required this.frac});

  final String label;
  final bool isToday;
  final double frac;

  @override
  Widget build(BuildContext context) {
    const maxH = 96.0;
    final h = math.max<double>(6, maxH * frac);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: h,
          decoration: BoxDecoration(
            gradient: isToday
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_blueSoft, _blue],
                  )
                : null,
            color: isToday ? null : const Color(0x12FFFFFF),
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: _pop(
            11,
            c: isToday ? Colors.white : _dim,
            w: isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

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
                Icons.arrow_back_rounded,
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
