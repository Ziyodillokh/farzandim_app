// ─────────────────────────────────────────────────────────────────────
// StatisticsScreen — "Statistika" (Figma 1:1, Parvoz ko'k)
// ─────────────────────────────────────────────────────────────────────
//
// Dashboard'dagi 3 stat chip bosilganda ochiladi. Tarkibi (Figma):
//   • Header: "Statistika" + chat + bildirishnoma
//   • 2x2 stat kartalar: kitoblar / testlar / qadamlar / rivojlanish
//   • "Kunlik rivojlanish" — badge + N kun + hafta trekeri (olov/muz)
//   • "Kunlik qadamlar" — badge + bugungi/10 000 + hafta trekeri (✓)
//   • "DON balansi" + reyting (bola atrofida 3 qator)
//   • "Kunlik o'rtacha ekran vaqti" + grafik + top ilovalar
//
// Real: todayStepsProvider, gamificationProfile (don/streak), allUsers
// (reyting), dailyUsage (ekran vaqti + top ilovalar). Bo'sh bo'lsa PREVIEW.

import 'dart:convert';

import 'package:farzandim_child/features/analytics/data/models/app_usage_entry.dart';
import 'package:farzandim_child/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/ranking/presentation/providers/ranking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Figma tokenlar ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _glass = Color(0x14FFFFFF);
const _glassBorder = Color(0x24FFFFFF);
const _dim = Color(0x99FFFFFF);
const _amber = Color(0xFFFFAE00);
const _stepsBlue = Color(0xFF66B3FF);
const _green = Color(0xFF41DD7A);
const _purple = Color(0xFFA78BFA);
const _freeze = Color(0xFF4FC3F7);
const _red = Color(0xFFEF5350);

const _weekLabels = ['Du', 'Se', 'Cho', 'Pa', 'Ju', 'Sha', 'Ya'];

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w700,
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
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.4);

String _fmtNum(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

enum _Day { fire, freeze, check, empty }

/// "Statistika" sahifasi.
class StatisticsScreen extends ConsumerWidget {
  /// `StatisticsScreen` konstruktor.
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(gamificationProfileProvider).valueOrNull;
    // PREVIEW: real 0 bo'lsa Figma namunasi.
    final rawStreak = profile?.streak ?? 0;
    final rawDon = profile?.don ?? 0;
    final rawSteps = ref.watch(todayStepsProvider).valueOrNull ?? 0;
    final streak = rawStreak > 0 ? rawStreak : 30;
    final don = rawDon > 0 ? rawDon : 1250;
    final steps = rawSteps > 0 ? rawSteps : 8837;

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      extendBody: true,
      bottomNavigationBar: const ChildBottomNavigation(),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 120 + bottomInset),
          children: [
            const _Header(),
            const SizedBox(height: 18),
            _StatGrid(steps: steps, streak: streak),
            const SizedBox(height: 12),
            _StreakCard(streak: streak),
            const SizedBox(height: 12),
            _StepsCard(steps: steps),
            const SizedBox(height: 12),
            _DonCard(don: don),
            const SizedBox(height: 20),
            const _ScreenTimeSection(),
          ],
        ),
      ),
    );
  }
}

// ════════════ Header ════════════

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    return Row(
      children: [
        _RoundIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        const SizedBox(width: 12),
        Expanded(child: Text('Statistika', style: _unb(24))),
        _RoundIconButton(
          icon: Icons.chat_bubble_rounded,
          onTap: () => context.push('/voice-chat'),
        ),
        const SizedBox(width: 10),
        _RoundIconButton(
          icon: Icons.notifications_rounded,
          showDot: unread > 0,
          onTap: () => context.push('/notifications'),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0x1AFFFFFF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          if (showDot)
            Positioned(
              right: 3,
              top: 3,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D4F),
                  shape: BoxShape.circle,
                  border: Border.all(color: _bg, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════ 2x2 stat kartalar ════════════

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.steps, required this.streak});

  final int steps;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: _BigStatCard(
                tint: _purple,
                icon: Icon(Icons.menu_book_rounded, size: 26, color: _purple),
                value: '2ta',
                label: "O'qilgan kitoblar",
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigStatCard(
                tint: _green,
                icon: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                  ),
                  child: Text('?', style: _unb(15, w: FontWeight.w700)),
                ),
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
              child: _BigStatCard(
                tint: _stepsBlue,
                icon: Image.asset(
                  'assets/icons/ic_steps.png',
                  width: 28,
                  height: 28,
                ),
                value: '~${_fmtNum(steps >= 10000 ? steps : 10000)}',
                label: 'Kunlik qadamlar',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigStatCard(
                tint: _amber,
                icon: const Icon(
                  Icons.local_fire_department_rounded,
                  size: 28,
                  color: _amber,
                ),
                value: '$streak kun',
                label: 'Kunlik rivojlanish',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BigStatCard extends StatelessWidget {
  const _BigStatCard({
    required this.tint,
    required this.icon,
    required this.value,
    required this.label,
  });

  final Color tint;
  final Widget icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(tint.withValues(alpha: 0.08), _glass),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const Spacer(),
          Text(value, style: _unb(21, w: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _pop(12.5, c: _dim),
          ),
        ],
      ),
    );
  }
}

// ════════════ Kunlik rivojlanish (streak + hafta) ════════════

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final todayIdx = DateTime.now().weekday - 1;
    final days = [
      for (var i = 0; i < 7; i++)
        (i <= todayIdx && (todayIdx - i) < streak) ? _Day.fire : _Day.empty,
    ];
    return _PanelCard(
      child: Column(
        children: [
          Row(
            children: [
              Image.asset(
                'assets/icons/badge_streak.png',
                width: 48,
                height: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kunlik rivojlanish', style: _pop(13, c: _dim)),
                    const SizedBox(height: 2),
                    Text('$streak kun', style: _unb(20)),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _WeekTracker(days: days),
        ],
      ),
    );
  }
}

// ════════════ Kunlik qadamlar (bugun + hafta) ════════════

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.steps});

  final int steps;

  @override
  Widget build(BuildContext context) {
    final todayIdx = DateTime.now().weekday - 1;
    // Bugungacha bo'lgan kunlar bajarilgan deb ko'rsatiladi (preview);
    // real haftalik qadamlar backend'dan kelganda shu yerga ulanadi.
    final days = [
      for (var i = 0; i < 7; i++) i <= todayIdx ? _Day.check : _Day.empty,
    ];
    return _PanelCard(
      child: Column(
        children: [
          Row(
            children: [
              Image.asset(
                'assets/icons/badge_steps.png',
                width: 48,
                height: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kunlik qadamlar', style: _pop(13, c: _dim)),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(_fmtNum(steps), style: _unb(20)),
                        Text(
                          ' / ${_fmtNum(10000)}',
                          style: _unb(14, w: FontWeight.w600, c: _dim),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _WeekTracker(days: days),
        ],
      ),
    );
  }
}

// ════════════ Hafta trekeri (pill kunlar) ════════════

class _WeekTracker extends StatelessWidget {
  const _WeekTracker({required this.days});

  final List<_Day> days;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          Expanded(
            child: _DayPill(label: _weekLabels[i], state: days[i]),
          ),
          if (i < 6) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.label, required this.state});

  final String label;
  final _Day state;

  @override
  Widget build(BuildContext context) {
    final Widget indicator = switch (state) {
      _Day.fire => const Icon(
        Icons.local_fire_department_rounded,
        size: 18,
        color: _amber,
      ),
      _Day.freeze => const Icon(
        Icons.ac_unit_rounded,
        size: 17,
        color: _freeze,
      ),
      _Day.check => Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
      ),
      _Day.empty => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x33FFFFFF), width: 1.4),
        ),
      ),
    };
    final active = state != _Day.empty;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: active
            ? Color.alphaBlend(
                (state == _Day.check ? _blue : _amber).withValues(alpha: 0.14),
                _glass,
              )
            : _glass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _glassBorder),
      ),
      child: Column(
        children: [
          Text(label, style: _pop(10.5, w: FontWeight.w600)),
          const SizedBox(height: 6),
          SizedBox(height: 20, child: Center(child: indicator)),
        ],
      ),
    );
  }
}

// ════════════ DON balansi + reyting ════════════

class _DonCard extends ConsumerWidget {
  const _DonCard({required this.don});

  final int don;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childId = ref.watch(pairingStateProvider).childId;
    final all = ref.watch(allUsersProvider);
    // Bola atrofidagi 3 qator (yuqori-bola-quyi); reyting bo'sh — preview.
    final rows = _window(all, childId);
    return GestureDetector(
      onTap: () => context.push('/ranking'),
      behavior: HitTestBehavior.opaque,
      child: _PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DON balansi', style: _pop(13, c: _dim)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(_fmtNum(don), style: _unb(22)),
                const SizedBox(width: 8),
                Text('+560', style: _unb(17, c: _green)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _blue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('DON', style: _pop(10, w: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty) ...[
              const _RankRow(rank: 94, name: 'Soliha', me: false),
              const _RankRow(rank: 95, name: 'Akmal', me: true, delta: '+3'),
              const _RankRow(rank: 96, name: 'Javohir', me: false),
            ] else
              for (final r in rows) _RankRow(rank: r.$1, name: r.$2, me: r.$3),
          ],
        ),
      ),
    );
  }

  List<(int, String, bool)> _window(List<dynamic> all, String? childId) {
    if (all.isEmpty || childId == null) return const [];
    final sorted = [...all]
      ..sort((a, b) => (b.totalScore as int).compareTo(a.totalScore as int));
    final idx = sorted.indexWhere((u) => u.id == childId);
    if (idx < 0) return const [];
    var start = idx - 1;
    final maxStart = sorted.length - 3;
    if (start < 0) start = 0;
    if (maxStart >= 0 && start > maxStart) start = maxStart;
    final end = (start + 3).clamp(0, sorted.length);
    return [
      for (var i = start; i < end; i++)
        (i + 1, sorted[i].name as String, sorted[i].id == childId),
    ];
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.name,
    required this.me,
    this.delta,
  });

  final int rank;
  final String name;
  final bool me;
  final String? delta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0x1AFFFFFF),
              shape: BoxShape.circle,
            ),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: _pop(12, w: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$rank. $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _pop(14, w: FontWeight.w600, c: me ? _blue : Colors.white),
            ),
          ),
          if (delta != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_drop_up_rounded,
                  size: 20,
                  color: _green,
                ),
                Text(
                  delta!,
                  style: _pop(12, w: FontWeight.w600, c: _green),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ════════════ Ekran vaqti + grafik + top ilovalar ════════════

class _ScreenTimeSection extends ConsumerWidget {
  const _ScreenTimeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(dailyUsageProvider).valueOrNull;
    final hasReal = day != null && day.apps.isNotEmpty;
    final title = hasReal ? day.formattedTotal : '2s 44 min';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Kunlik o'rtacha ekran vaqti", style: _pop(13, c: _dim)),
        const SizedBox(height: 2),
        Text(title, style: _unb(26)),
        const SizedBox(height: 12),
        const _HourChart(),
        const SizedBox(height: 12),
        _TopApps(apps: hasReal ? day.apps : const []),
      ],
    );
  }
}

/// Soatlik ustunlar (preview shakl — soatlik real ma'lumot hali yo'q).
class _HourChart extends StatelessWidget {
  const _HourChart();

  static const _bars = <double>[
    0.10,
    0.16,
    0.22,
    0.30,
    0.42,
    0.55,
    0.68,
    0.82,
    0.95,
    0.60,
    0.45,
    0.66,
    0.50,
    0.36,
    0.44,
    1.0,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(10, 14, 12, 10),
      decoration: BoxDecoration(
        color: _glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _glassBorder),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('4s', style: _pop(10.5, c: _dim)),
                      Text('3s', style: _pop(10.5, c: _red)),
                      Text('2s', style: _pop(10.5, c: _dim)),
                      Text('0s', style: _pop(10.5, c: _dim)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      return Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: c.maxHeight * 0.25,
                            child: const _DashedLine(color: Color(0x66EF5350)),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final h in _bars)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: FractionallySizedBox(
                                      heightFactor: h,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _blue,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('00:00', style: _pop(10.5, c: _dim)),
                Text('06:00', style: _pop(10.5, c: _dim)),
                Text('12:00', style: _pop(10.5, c: _dim)),
              ],
            ),
          ),
        ],
      ),
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

/// Top ilovalar — real `dailyUsage.apps` (bo'sh bo'lsa PREVIEW ro'yxat).
class _TopApps extends StatelessWidget {
  const _TopApps({required this.apps});

  final List<AppUsageEntry> apps;

  static const _preview = [
    ('PUBG', Color(0xFFE9A23B), '1s 34 min'),
    ('Instagram', Color(0xFFE1306C), '1s 34 min'),
    ('Telegram', Color(0xFF2AABEE), '1s 34 min'),
    ('Chrome', Color(0xFF4285F4), '1s 34 min'),
    ('Spotify', Color(0xFF1DB954), '1s 34 min'),
  ];

  @override
  Widget build(BuildContext context) {
    final sorted = [...apps]
      ..sort((a, b) => b.totalTimeMs.compareTo(a.totalTimeMs));
    final top = sorted.take(5).toList();
    return Container(
      decoration: BoxDecoration(
        color: _glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _glassBorder),
      ),
      child: Column(
        children: [
          if (top.isEmpty)
            for (var i = 0; i < _preview.length; i++) ...[
              _AppTile(
                rank: i + 1,
                name: _preview[i].$1,
                color: _preview[i].$2,
                time: _preview[i].$3,
              ),
              if (i < _preview.length - 1) const _RowDivider(),
            ]
          else
            for (var i = 0; i < top.length; i++) ...[
              _AppTile(
                rank: i + 1,
                name: top[i].appName,
                color: _blue,
                time: top[i].formattedTime,
                iconBase64: top[i].iconBase64,
              ),
              if (i < top.length - 1) const _RowDivider(),
            ],
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 14,
      endIndent: 14,
      color: Color(0x14FFFFFF),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.rank,
    required this.name,
    required this.color,
    required this.time,
    this.iconBase64,
  });

  final int rank;
  final String name;
  final Color color;
  final String time;
  final String? iconBase64;

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    final b64 = iconBase64;
    if (b64 != null && b64.isNotEmpty) {
      avatar = ClipOval(
        child: Image.memory(
          base64Decode(b64),
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _letter(),
        ),
      );
    } else {
      avatar = _letter();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$rank. $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _unb(14, w: FontWeight.w600, ls: -0.2),
            ),
          ),
          Text(time, style: _pop(12.5, c: _dim)),
        ],
      ),
    );
  }

  Widget _letter() {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: _pop(13, w: FontWeight.w700),
      ),
    );
  }
}

// ════════════ Umumiy panel karta ════════════

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _glass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _glassBorder),
      ),
      child: child,
    );
  }
}
