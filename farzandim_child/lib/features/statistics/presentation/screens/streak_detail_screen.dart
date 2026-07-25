// Streak (rivojlanish) batafsil ekrani — "Kunlik rivojlanish" kartasi
// bosilganda ochiladi. Yuqorida ketma-ket kunlar (olovli halqa, keyingi
// bosqichgacha progress), pastda ERISHGAN va ERISHISH MUMKIN bo'lgan
// medallar (Achievements.all katalogi).

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/gamification/data/models/achievement.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

const _bg = Color(0xFF00060A);
const _bgTop = Color(0xFF0A2942);
const _panel = Color(0xFF161C24);
const _dim = Color(0x8CFFFFFF);
const _line = Color(0x14FFFFFF);
const _flame = Color(0xFFFB923C);
const _flameSoft = Color(0xFFFFB86B);

const _milestones = [3, 7, 10, 30, 60, 100];

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

class StreakDetailScreen extends ConsumerWidget {
  const StreakDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(backendGamificationProvider).valueOrNull;
    final streak = g?.streak ?? 0;
    final unlocked = g?.unlockedAchievements.toSet() ?? const <String>{};

    bool earned(Achievement a) =>
        unlocked.contains(a.id) || (a.id == 'streak_10' && streak >= 10);

    final medals = Achievements.all;
    final earnedCount = medals.where(earned).length;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const _Backdrop(),
          SafeArea(
            child: Column(
              children: [
                _Header(title: 'streakDetail.title'.tr()),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      _StreakHero(streak: streak),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Text('streakDetail.medals'.tr(), style: _unb(17)),
                          const Spacer(),
                          _CountPill(
                            text: 'streakDetail.earnedOf'.tr(
                              namedArgs: {
                                'earned': '$earnedCount',
                                'total': '${medals.length}',
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'streakDetail.subtitle'.tr(),
                        style: _pop(12, c: _dim),
                      ),
                      const SizedBox(height: 14),
                      for (var r = 0; r < medals.length; r += 2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _MedalCard(
                                  medal: medals[r],
                                  earned: earned(medals[r]),
                                  streak: streak,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (r + 1 < medals.length)
                                Expanded(
                                  child: _MedalCard(
                                    medal: medals[r + 1],
                                    earned: earned(medals[r + 1]),
                                    streak: streak,
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox()),
                            ],
                          ),
                        ),
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

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final next = _milestones.firstWhere(
      (m) => m > streak,
      orElse: () => streak,
    );
    final atMax = next <= streak;
    final pct = next > 0 ? (streak / next).clamp(0.0, 1.0) : 1.0;
    final caption = atMax
        ? 'streakDetail.maxMilestone'.tr()
        : 'streakDetail.nextMilestone'.tr(namedArgs: {'n': '${next - streak}'});

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2C1810), Color(0xFF0C1119)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x1FFB923C)),
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
                      colors: [Color(0x33FB923C), Color(0x00FB923C)],
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
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 36,
                      color: _flame,
                    ),
                    const SizedBox(height: 4),
                    Text('$streak', style: _unb(42, ls: -1.5)),
                    const SizedBox(height: 2),
                    Text(
                      'streakDetail.continuous'.tr(),
                      style: _pop(11, c: _dim, w: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(caption, style: _unb(14.5, ls: -0.3, c: _flameSoft)),
          const SizedBox(height: 6),
          Text(
            'streakDetail.hint'.tr(),
            textAlign: TextAlign.center,
            style: _pop(12, c: _dim),
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
        colors: [_flame, _flameSoft, _flame],
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

class _CountPill extends StatelessWidget {
  const _CountPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1FFB923C),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33FB923C)),
      ),
      child: Text(
        text,
        style: _pop(11.5, c: _flameSoft, w: FontWeight.w600),
      ),
    );
  }
}

class _MedalCard extends StatelessWidget {
  const _MedalCard({
    required this.medal,
    required this.earned,
    required this.streak,
  });

  final Achievement medal;
  final bool earned;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final showProgress = !earned && medal.id == 'streak_10';
    final progress = (streak / 10).clamp(0.0, 1.0);
    final color = medal.color;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: earned ? null : _panel,
        gradient: earned
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.20),
                  color.withValues(alpha: 0.05),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: earned ? color.withValues(alpha: 0.45) : _line,
        ),
        boxShadow: earned
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: earned ? 0.22 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  medal.icon,
                  size: 27,
                  color: earned ? color : Colors.white.withValues(alpha: 0.38),
                ),
              ),
              if (!earned)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C1117),
                      shape: BoxShape.circle,
                      border: Border.all(color: _line),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: _dim,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            medal.titleKey.tr(),
            style: _unb(
              13.5,
              ls: -0.4,
              c: earned ? Colors.white : const Color(0xCCFFFFFF),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            medal.descriptionKey.tr(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _pop(11, c: _dim),
          ),
          const SizedBox(height: 12),
          if (earned)
            _FooterChip(
              icon: Icons.check_circle_rounded,
              label: 'streakDetail.achieved'.tr(),
              color: color,
              tinted: true,
            )
          else if (showProgress)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0x14FFFFFF),
                    valueColor: const AlwaysStoppedAnimation(_flame),
                  ),
                ),
                const SizedBox(height: 6),
                Text('$streak / 10', style: _pop(11, c: _flameSoft)),
              ],
            )
          else
            _FooterChip(
              icon: Icons.lock_rounded,
              label: 'streakDetail.locked'.tr(),
              color: _dim,
              tinted: false,
            ),
        ],
      ),
    );
  }
}

class _FooterChip extends StatelessWidget {
  const _FooterChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.tinted,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tinted ? color.withValues(alpha: 0.16) : const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: _pop(11, c: color, w: FontWeight.w600),
          ),
        ],
      ),
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
