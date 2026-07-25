// Streak (rivojlanish) batafsil ekrani — dashboard "Kunlik rivojlanish"
// kartasi bosilganda ochiladi. Yuqorida ketma-ket kunlar (olovli halqa,
// keyingi bosqichgacha progress), pastda bola ERISHGAN va ERISHISHI MUMKIN
// bo'lgan medallar (masalan "1-kitob") to'ri.
//
// Ma'lumot: `childProfileProvider(childId)` -> ChildProfile
// (streakDays + achievements ID'lari).

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ── Tokenlar (steps ekrani bilan bir xil) ──
const _bg = Color(0xFF00060A);
const _bgTop = Color(0xFF0A2942);
const _panel2 = Color(0xFF161C24);
const _dim = Color(0x8CFFFFFF);
const _line = Color(0x14FFFFFF);
const _flame = Color(0xFFFB923C);
const _flameSoft = Color(0xFFFFB86B);

// Streak bosqichlari — keyingi maqsad shu ro'yxatdan olinadi.
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
  const StreakDetailScreen({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(childProfileProvider(childId)).valueOrNull;
    final streak = profile?.streakDays ?? 0;
    final unlocked = profile?.achievements.toSet() ?? const <String>{};

    bool earned(_Medal m) =>
        unlocked.contains(m.id) || (m.id == 'streak_10' && streak >= 10);

    final earnedCount = _medals.where(earned).length;

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
                                'total': '${_medals.length}',
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
                      for (var r = 0; r < _medals.length; r += 2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _MedalCard(
                                  medal: _medals[r],
                                  earned: earned(_medals[r]),
                                  streak: streak,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (r + 1 < _medals.length)
                                Expanded(
                                  child: _MedalCard(
                                    medal: _medals[r + 1],
                                    earned: earned(_medals[r + 1]),
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

// ── Ketma-ket kunlar — olovli halqa (keyingi bosqichgacha progress) ──
class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final next = _milestones.firstWhere(
      (m) => m > streak,
      orElse: () => streak,
    );
    final pct = next > 0 ? (streak / next).clamp(0.0, 1.0) : 1.0;
    final atMax = next <= streak;
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
                // Yumshoq olov yog'du (halqa ortida).
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
                    const Icon(SolarIconsBold.fire, size: 34, color: _flame),
                    const SizedBox(height: 6),
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

// ── "e / N medal" hisoblagich pill ──
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

// ── Bitta medal kartasi (erishilgan = rangli, yopiq = kulrang + qulf) ──
class _MedalCard extends StatelessWidget {
  const _MedalCard({
    required this.medal,
    required this.earned,
    required this.streak,
  });

  final _Medal medal;
  final bool earned;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final showProgress = !earned && medal.id == 'streak_10';
    final progress = (streak / 10).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: earned ? null : _panel2,
        gradient: earned
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  medal.color.withValues(alpha: 0.20),
                  medal.color.withValues(alpha: 0.05),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: earned ? medal.color.withValues(alpha: 0.45) : _line,
        ),
        boxShadow: earned
            ? [
                BoxShadow(
                  color: medal.color.withValues(alpha: 0.16),
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
                decoration: BoxDecoration(
                  color: medal.color.withValues(alpha: earned ? 0.22 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  medal.icon,
                  size: 27,
                  color: earned
                      ? medal.color
                      : Colors.white.withValues(alpha: 0.38),
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
                      SolarIconsBold.lock,
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
            medal.descKey.tr(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _pop(11, c: _dim),
          ),
          const SizedBox(height: 12),
          if (earned)
            _FooterChip(
              icon: SolarIconsBold.checkCircle,
              label: 'streakDetail.achieved'.tr(),
              color: medal.color,
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
              icon: SolarIconsBold.lock,
              label: 'streakDetail.locked'.tr(),
              color: _dim,
              tinted: false,
            ),
        ],
      ),
    );
  }
}

// ── Medal kartasi pastidagi holat chipi (Erishildi / Yopiq) ──
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
          Icon(icon, size: 13, color: color),
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

// ── Medallar katalogi (bola ilovasidagi 6 ta yutuq bilan bir xil) ──
class _Medal {
  const _Medal({
    required this.id,
    required this.titleKey,
    required this.descKey,
    required this.icon,
    required this.color,
  });

  final String id;
  final String titleKey;
  final String descKey;
  final IconData icon;
  final Color color;
}

const _medals = <_Medal>[
  _Medal(
    id: 'first_book',
    titleKey: 'streakDetail.mFirstBookTitle',
    descKey: 'streakDetail.mFirstBookDesc',
    icon: SolarIconsBold.book,
    color: Color(0xFF60A5FA),
  ),
  _Medal(
    id: 'streak_10',
    titleKey: 'streakDetail.mStreak10Title',
    descKey: 'streakDetail.mStreak10Desc',
    icon: SolarIconsBold.fire,
    color: Color(0xFFFB923C),
  ),
  _Medal(
    id: 'math_top10',
    titleKey: 'streakDetail.mMathTop10Title',
    descKey: 'streakDetail.mMathTop10Desc',
    icon: SolarIconsBold.calculatorMinimalistic,
    color: Color(0xFFA78BFA),
  ),
  _Medal(
    id: 'contest_winner',
    titleKey: 'streakDetail.mContestWinnerTitle',
    descKey: 'streakDetail.mContestWinnerDesc',
    icon: SolarIconsBold.cupStar,
    color: Color(0xFFFBBF24),
  ),
  _Medal(
    id: 'content_creator',
    titleKey: 'streakDetail.mContentCreatorTitle',
    descKey: 'streakDetail.mContentCreatorDesc',
    icon: SolarIconsBold.clapperboard,
    color: Color(0xFFE4405F),
  ),
  _Medal(
    id: 'helper',
    titleKey: 'streakDetail.mHelperTitle',
    descKey: 'streakDetail.mHelperDesc',
    icon: SolarIconsBold.handHeart,
    color: Color(0xFF34D399),
  ),
];

// ── Header + fon (steps ekrani bilan bir xil) ──
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
