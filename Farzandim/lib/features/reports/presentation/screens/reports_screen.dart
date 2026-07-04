// ─────────────────────────────────────────────────────────────────────
// ReportsScreen — "Hisobotlar" (Parvoz dizayn)
// ─────────────────────────────────────────────────────────────────────
//
// Dashboard'dagi "Hisobotlar" kartasidan ochiladi. Davr filtri (Oldingi oy),
// 2x2 statistika (kitoblar / testlar / qadamlar / rivojlanish), DON balansi +
// reyting, kunlik o'rtacha ekran vaqti (ustunli grafik), top ilovalar.
//
// Ma'lumot hozircha namunaviy (design preview) — keyin real provayderlarga
// ulanadi. IP: ilova ikonlari brend-rangli harf-belgi (asl logotip emas).

import 'package:farzandim/core/routing/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _green = Color(0xFF34C759);
const _card = Color(0xFF12171E);
const _chipBg = Color(0xFF1B2128);
const _fieldBorder = Color(0x1FFFFFFF);
const _dim = Color(0x8CFFFFFF);

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
}) => GoogleFonts.unbounded(fontSize: s, fontWeight: w, color: c, height: 1.15);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.35);

/// Namunaviy top ilova (rank + nom + rang + vaqt).
class _AppRow {
  const _AppRow(this.rank, this.name, this.color, this.time);
  final int rank;
  final String name;
  final Color color;
  final String time;
}

const _apps = <_AppRow>[
  _AppRow(1, 'PUBG', Color(0xFFE9A23B), '1s 34 min'),
  _AppRow(2, 'Instagram', Color(0xFFE1306C), '1s 34 min'),
  _AppRow(3, 'Telegram', Color(0xFF2AABEE), '1s 34 min'),
  _AppRow(4, 'Chrome', Color(0xFF4285F4), '1s 34 min'),
  _AppRow(5, 'Spotify', Color(0xFF1DB954), '1s 34 min'),
];

// Ekran vaqti ustunlari (0..1, 60 daqiqaga nisbatan) — 12 soat = 12 ustun.
const _bars = <double>[
  0.12, 0.22, 0.3, 0.2, 0.48, 0.62, 0.78, 0.92, 0.5, 0.66, 0.4, 1,
];

/// "Hisobotlar" ekrani.
class ReportsScreen extends StatelessWidget {
  /// `ReportsScreen` konstruktor.
  const ReportsScreen({required this.childId, super.key});

  /// Bola id'si (route parametri; kelajakda real ma'lumot uchun).
  final String childId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  _BackButton(onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.dashboard);
                    }
                  }),
                  Expanded(
                    child: Text(
                      'Hisobotlar',
                      textAlign: TextAlign.center,
                      style: _unb(22),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: const [
                  _PeriodFilter(),
                  SizedBox(height: 14),
                  _StatGrid(),
                  SizedBox(height: 12),
                  _DonCard(),
                  SizedBox(height: 18),
                  _ScreenTimeSection(),
                  SizedBox(height: 14),
                  _TopAppsCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════ Davr filtri ════════════

class _PeriodFilter extends StatelessWidget {
  const _PeriodFilter();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 9, 8, 9),
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Oldingi oy', style: _pop(14, w: FontWeight.w600)),
              const SizedBox(width: 8),
              const Icon(SolarIconsBold.closeCircle, size: 20,
                  color: Colors.white),
            ],
          ),
        ),
        const Spacer(),
        Container(
          width: 48,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _fieldBorder),
          ),
          child: const Icon(SolarIconsOutline.calendar, size: 22,
              color: Colors.white),
        ),
      ],
    );
  }
}

// ════════════ 2x2 statistika ════════════

class _StatGrid extends StatelessWidget {
  const _StatGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icon(SolarIconsBold.notebookMinimalistic, size: 30,
                    color: Color(0xFFA78BFA)),
                value: '2ta',
                label: "O'qilgan kitoblar",
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icon(SolarIconsBold.questionCircle, size: 30,
                    color: _green),
                value: '102 ta',
                label: 'Ishlangan testlar',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: SvgPicture.asset('assets/icons/ic_shoe.svg',
                    width: 40, height: 40),
                value: '~10 000',
                label: 'Kunlik qadamlar',
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: _StatCard(
                icon: Icon(SolarIconsBold.flame, size: 34,
                    color: Color(0xFFFF7A1A)),
                value: '30 kun',
                label: 'Kunlik rivojlanish',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final Widget icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 40, child: Align(
            alignment: Alignment.centerLeft, child: icon)),
          const Spacer(),
          Text(value, style: _unb(22, w: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: _pop(13, c: _dim)),
        ],
      ),
    );
  }
}

// ════════════ DON balansi + reyting ════════════

class _DonCard extends StatelessWidget {
  const _DonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DON balansi', style: _pop(13, c: _dim)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('1 250', style: _unb(24, w: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('+560', style: _unb(20, w: FontWeight.w700, c: _green)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('DON', style: _pop(11, w: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _RankRow(rank: 94, name: 'Soliha', color: Color(0xFFEF7DA0)),
          const _RankRow(
            rank: 95,
            name: 'Akmal',
            color: Color(0xFF7B61FF),
            highlight: true,
            delta: '+3',
          ),
          const _RankRow(rank: 96, name: 'Javohir', color: Color(0xFF4285F4)),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.name,
    required this.color,
    this.highlight = false,
    this.delta,
  });

  final int rank;
  final String name;
  final Color color;
  final bool highlight;
  final String? delta;

  @override
  Widget build(BuildContext context) {
    final textColor = highlight ? _blue : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          _LetterAvatar(letter: name[0], color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$rank. $name',
              style: _pop(15, w: FontWeight.w600, c: textColor),
            ),
          ),
          if (delta != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_drop_up_rounded, size: 20,
                    color: _green),
                Text(delta!, style: _pop(13, w: FontWeight.w600, c: _green)),
              ],
            ),
        ],
      ),
    );
  }
}

// ════════════ Ekran vaqti + grafik ════════════

class _ScreenTimeSection extends StatelessWidget {
  const _ScreenTimeSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text("Kunlik o'rtacha ekran vaqti", style: _pop(13, c: _dim)),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('2s 44 min', style: _unb(26, w: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        Container(
          height: 240,
          padding: const EdgeInsets.fromLTRB(8, 14, 12, 8),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _fieldBorder),
          ),
          child: const _BarChart(),
        ),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart();

  @override
  Widget build(BuildContext context) {
    // Y o'qi belgilari (4s..0s), 3s — qizil chegara.
    return LayoutBuilder(
      builder: (context, c) {
        final chartH = c.maxHeight - 22; // pastki o'q belgilariga joy
        return Column(
          children: [
            SizedBox(
              height: chartH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Y o'qi belgilari (soatiga ekran vaqti — maksimal 60 min).
                  SizedBox(
                    width: 44,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('60 min', style: _pop(11, c: _dim)),
                        Text('45 min',
                            style: _pop(11, c: const Color(0xFFEF5350))),
                        Text('30 min', style: _pop(11, c: _dim)),
                        Text('0', style: _pop(11, c: _dim)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        // 45 min qizil punktir chegara (60 min dan 3/4).
                        Positioned(
                          left: 0,
                          right: 0,
                          top: chartH * 0.25,
                          child: const _DashedLine(color: Color(0x66EF5350)),
                        ),
                        // 30 min kulrang chiziq.
                        Positioned(
                          left: 0,
                          right: 0,
                          top: chartH * 0.5,
                          child: const _DashedLine(color: Color(0x1AFFFFFF)),
                        ),
                        // Ustunlar.
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final h in _bars)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    child: FractionallySizedBox(
                                      heightFactor: h.clamp(0.04, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _blue,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
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
            ),
            const SizedBox(height: 6),
            // X o'qi belgilari.
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('00:00', style: _pop(11, c: _dim)),
                  Text('06:00', style: _pop(11, c: _dim)),
                  Text('12:00', style: _pop(11, c: _dim)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const dash = 6.0;
        const gap = 5.0;
        final count = (c.maxWidth / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: dash, height: 1.4, color: color),
          ),
        );
      },
    );
  }
}

// ════════════ Top ilovalar ════════════

class _TopAppsCard extends StatelessWidget {
  const _TopAppsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _fieldBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _apps.length; i++) ...[
            _AppTile(app: _apps[i]),
            if (i < _apps.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 14,
                endIndent: 14,
                color: Color(0x14FFFFFF),
              ),
          ],
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.app});

  final _AppRow app;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          _LetterAvatar(letter: app.name[0], color: app.color, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Text('${app.rank}. ${app.name}', style: _unb(15)),
          ),
          Text(app.time, style: _pop(13, c: _dim)),
        ],
      ),
    );
  }
}

// ════════════ Umumiy widgetlar ════════════

/// Brend-rangli harf-avatar (IP-xavfsiz — asl logotip emas).
class _LetterAvatar extends StatelessWidget {
  const _LetterAvatar({
    required this.letter,
    required this.color,
    required this.size,
  });

  final String letter;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        letter.toUpperCase(),
        style: _unb(size * 0.42, w: FontWeight.w700),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _fieldBorder),
        ),
        child: const Icon(SolarIconsOutline.arrowLeft, size: 22,
            color: Colors.white),
      ),
    );
  }
}
