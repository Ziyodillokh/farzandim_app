// ─────────────────────────────────────────────────────────────────────
// test_card — "Testlar" bo'limi umumiy Parvoz tokenlari + TestCard
// ─────────────────────────────────────────────────────────────────────
//
// ContestsScreen (grid) va Sevimli testlar sahifasi bir xil premium kartani
// ishlatadi: soha ikoni (rangli kvadrat + glow) + "N DON" bonus + sarlavha +
// "N ta test" + qiyinlik yorlig'i. Faol → shartlar sheet, yakunlangan → xira.

import 'dart:ui' show ImageFilter;

import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/data/models/test_difficulty.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Parvoz tokenlar (dashboard/videolar bilan bir xil) ════════════
const tBg = Color(0xFF00060A); // sahifa foni
const tBlue = Color(0xFF216BFF); // brend / DON / hero
const tGlass = Color(0x14FFFFFF); // karta foni — oq ~8%
const tGlassBorder = Color(0x24FFFFFF); // karta chegarasi — oq ~14%
const tDim = Color(0x99FFFFFF); // oq 60%
const tMuted = Color(0xFFA6A8A9); // xira kulrang

TextStyle tUnb(
  double s, {
  FontWeight w = FontWeight.w700,
  Color c = Colors.white,
  double ls = -0.5,
}) => GoogleFonts.unbounded(
  fontSize: s,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.15,
);

TextStyle tPop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.3);

/// Ko'k "DON" pill (narx yonida).
class DonBadge extends StatelessWidget {
  const DonBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: tBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('DON', style: tPop(9, w: FontWeight.w700)),
    );
  }
}

/// Kartadagi kichik qiyinlik yorlig'i — "● Qiyin" (rangli).
class _DiffLabel extends StatelessWidget {
  const _DiffLabel({required this.difficulty});

  final TestDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final col = difficulty.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: col.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: col),
          ),
          const SizedBox(width: 5),
          Text(
            difficulty.label,
            style: tPop(10.5, w: FontWeight.w600, c: col),
          ),
        ],
      ),
    );
  }
}

/// Yumshoq rangli glow (ikon ortida — kartaga soha rangini beradi).
class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, this.size = 60});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.42),
        ),
      ),
    );
  }
}

/// Test kartasi — soha ikoni + "N DON" + sarlavha + "N ta test".
class TestCard extends StatelessWidget {
  const TestCard({
    required this.contest,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  final ContestModel contest;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = contest;
    final col = c.placeholderColor;
    final finished = !c.isActive;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: finished ? 0.62 : 1,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: tGlass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tGlassBorder),
          ),
          child: Stack(
            children: [
              // Soha rangidagi glow — chap-yuqori (ikon ortida) + o'ng-past.
              Positioned(top: -14, left: -14, child: _GlowOrb(color: col)),
              Positioned(
                right: -22,
                bottom: -22,
                child: _GlowOrb(color: col, size: 72),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: col.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(c.placeholderIcon, size: 24, color: col),
                        ),
                        const Spacer(),
                        // "250 DON" — narx kesilmasin uchun FittedBox.
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${c.bonus}',
                                  style: tUnb(15, w: FontWeight.w600, ls: -0.4),
                                ),
                                const SizedBox(width: 4),
                                const DonBadge(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tUnb(16, w: FontWeight.w600, ls: -0.4),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${c.savollarSoni} ta test',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tPop(12.5, c: tMuted),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _DiffLabel(
                          difficulty: inherentDifficulty(c.savollarSoni),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
