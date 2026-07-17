// ─────────────────────────────────────────────────────────────────────
// ReportsScreen — "Hisobotlar" (Parvoz dizayn, REAL backend)
// ─────────────────────────────────────────────────────────────────────
//
// Dashboard'dagi "Hisobotlar" kartasidan ochiladi. Real provayderlar:
//   • Ekran vaqti      → weeklyChildUsageProvider (7 kunlik totallar)
//   • Top ilovalar     → todayUsageProvider (displayApps)
//   • DON + streak     → childProfileProvider
//   • Reyting          → leaderboardProvider
// Kitob/test/qadam backend'da hali yo'q → 0. Bola ulanmasa data bo'sh.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_usage.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_usage_repository.dart'
    show DailySteps;
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_icon_widget.dart';
import 'package:farzandim/features/dashboard/presentation/widgets/screen_time_chart.dart';
import 'package:farzandim/features/gamification/data/models/leaderboard_models.dart';
import 'package:farzandim/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:farzandim/features/gamification/presentation/providers/leaderboard_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _card = Color(0xFF12171E);
const _chipBg = Color(0xFF1B2128);
const _fieldBorder = Color(0x1FFFFFFF);
const _dim = Color(0x8CFFFFFF);

const _weekdayShort = ['Du', 'Se', 'Cho', 'Pa', 'Ju', 'Sha', 'Ya'];

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

String _fmtHm(int ms) {
  final h = ms ~/ 3600000;
  final m = (ms % 3600000) ~/ 60000;
  if (h == 0) return '$m min';
  return '${h}s $m min';
}

/// "Hisobotlar" ekrani (real ma'lumot).
class ReportsScreen extends StatelessWidget {
  /// `ReportsScreen` konstruktor.
  const ReportsScreen({required this.childId, super.key});

  /// Qaysi bola hisoboti (route parametri).
  final String childId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  _BackButton(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.dashboard);
                      }
                    },
                  ),
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
                children: [
                  _StatGrid(childId: childId),
                  const SizedBox(height: 12),
                  _DonCard(childId: childId),
                  const SizedBox(height: 18),
                  _ScreenTimeSection(childId: childId),
                  const SizedBox(height: 14),
                  _TopAppsCard(childId: childId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════ 2x2 statistika ════════════

class _StatGrid extends ConsumerWidget {
  const _StatGrid({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(childProfileProvider(childId)).valueOrNull;
    final streak = profile?.streakDays ?? 0;
    // REAL: haftalik kitoblar/testlar (backend dev-summary) + bugungi qadam.
    final summary = ref.watch(developmentSummaryProvider(childId)).valueOrNull;
    final books = summary?.booksRead ?? 0;
    final tests = summary?.testsCompleted ?? 0;
    final weeklySteps = ref.watch(weeklyStepsProvider(childId)).valueOrNull;
    final todayKey = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 5))
        .toIso8601String()
        .substring(0, 10);
    var todaySteps = 0;
    for (final d in weeklySteps?.days ?? const <DailySteps>[]) {
      if (d.date.toIso8601String().substring(0, 10) == todayKey) {
        todaySteps = d.steps;
      }
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: const Icon(
                  SolarIconsBold.notebookMinimalistic,
                  size: 30,
                  color: Color(0xFFA78BFA),
                ),
                value: '$books',
                label: 'reports.booksRead'.tr(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: const Image(
                  image: AssetImage('assets/icons/ic_tests.png'),
                  width: 32,
                  height: 32,
                ),
                value: '$tests',
                label: 'reports.testsDone'.tr(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Image.asset(
                  'assets/icons/ic_steps.png',
                  width: 34,
                  height: 34,
                ),
                value: _fmtSteps(todaySteps),
                label: 'reports.dailySteps'.tr(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: const Icon(
                  SolarIconsBold.flame,
                  size: 34,
                  color: Color(0xFFFF7A1A),
                ),
                value: '$streak kun',
                label: 'reports.dailyProgress'.tr(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _fmtSteps(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
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
          SizedBox(
            height: 40,
            child: Align(alignment: Alignment.centerLeft, child: icon),
          ),
          const Spacer(),
          Text(value, style: _unb(22, w: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _pop(13, c: _dim),
          ),
        ],
      ),
    );
  }
}

// ════════════ DON balansi + reyting ════════════

class _DonCard extends ConsumerWidget {
  const _DonCard({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(childProfileProvider(childId)).valueOrNull;
    final don = profile?.donBalance ?? 0;
    final lb = ref.watch(
      leaderboardProvider((childId: childId, period: 'all', region: null)),
    );
    final rows = _leaderboardWindow(lb, childId);
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
          Text('reports.donBalance'.tr(), style: _pop(13, c: _dim)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('$don', style: _unb(24, w: FontWeight.w700)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('DON', style: _pop(11, w: FontWeight.w700)),
              ),
            ],
          ),
          if (rows.isEmpty) ...[
            const SizedBox(height: 12),
            Text('reports.noRatingYet'.tr(), style: _pop(13, c: _dim)),
          ] else ...[
            const SizedBox(height: 12),
            for (final e in rows)
              _RankRow(entry: e, highlight: e.childId == childId),
          ],
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.highlight});

  final LeaderboardEntry entry;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? _blue : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          _LetterAvatar(letter: entry.name, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${entry.rank}. ${entry.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _pop(15, w: FontWeight.w600, c: color),
            ),
          ),
          Text(
            '${entry.don}',
            style: _pop(13, w: FontWeight.w600, c: _dim),
          ),
        ],
      ),
    );
  }
}

/// Dashboard bilan bir xil 3-qatorli reyting oynasi.
List<LeaderboardEntry> _leaderboardWindow(LeaderboardState lb, String childId) {
  if (lb.initialLoading || lb.error) return const [];
  final all = lb.entries;
  if (all.isEmpty) {
    final me = lb.currentChild;
    return me != null ? [me] : const [];
  }
  final idx = all.indexWhere((e) => e.childId == childId);
  if (idx >= 0) {
    if (all.length <= 3) return all;
    var start = idx - 1;
    final maxStart = all.length - 3;
    if (start < 0) start = 0;
    if (start > maxStart) start = maxStart;
    return all.sublist(start, start + 3);
  }
  final out = <LeaderboardEntry>[];
  final me = lb.currentChild;
  if (me != null) out.add(me);
  for (final e in all) {
    if (out.length >= 3) break;
    if (e.childId != childId) out.add(e);
  }
  out.sort((a, b) => a.rank.compareTo(b.rank));
  return out.take(3).toList();
}

// ════════════ Ekran vaqti + grafik (7 kunlik) ════════════

class _ScreenTimeSection extends ConsumerWidget {
  const _ScreenTimeSection({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly =
        ref.watch(weeklyChildUsageProvider(childId)).valueOrNull ?? const [];
    // Oxirgi 7 kun (bugundan orqaga) — har kun uchun totalMs.
    final now = DateTime.now();
    String key(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final byDay = {for (final x in weekly) key(x.date): x.totalMs};
    final days = <({String label, int ms})>[];
    for (var i = 6; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day - i);
      days.add((label: _weekdayShort[d.weekday - 1], ms: byDay[key(d)] ?? 0));
    }
    final withData = days.where((d) => d.ms > 0).toList();
    final avgMs = withData.isEmpty
        ? 0
        : withData.fold<int>(0, (s, d) => s + d.ms) ~/ withData.length;
    final maxMs = days.fold<int>(0, (m, d) => d.ms > m ? d.ms : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('reports.avgScreenTime'.tr(), style: _pop(13, c: _dim)),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            avgMs == 0 ? '—' : _fmtHm(avgMs),
            style: _unb(26, w: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 220,
          padding: const EdgeInsets.fromLTRB(10, 14, 12, 10),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _fieldBorder),
          ),
          child: maxMs == 0
              ? Center(
                  child: Text(
                    'reports.noScreenTimeData'.tr(),
                    style: _pop(13, c: _dim),
                  ),
                )
              : _WeekBars(days: days, maxMs: maxMs),
        ),
      ],
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days, required this.maxMs});

  final List<({String label, int ms})> days;
  final int maxMs;

  @override
  Widget build(BuildContext context) {
    // Y-o'qi QAT'IY 24 soat (foydalanuvchi talabi).
    const maxHours = 24;
    const topMs = maxHours * 3600000;
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 30,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${maxHours}s', style: _pop(11, c: _dim)),
                    Text(
                      '${(maxHours / 2).round()}s',
                      style: _pop(11, c: _dim),
                    ),
                    Text('0', style: _pop(11, c: _dim)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final d in days)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FractionallySizedBox(
                            heightFactor: (d.ms / topMs).clamp(0.02, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _blue,
                                borderRadius: BorderRadius.circular(6),
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
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 38),
          child: Row(
            children: [
              for (final d in days)
                Expanded(
                  child: Text(
                    d.label,
                    textAlign: TextAlign.center,
                    style: _pop(10, c: _dim),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════ Top ilovalar ════════════

class _TopAppsCard extends ConsumerWidget {
  const _TopAppsCard({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(todayUsageProvider(childId)).valueOrNull;
    final apps = (usage?.displayApps ?? const <AppUsageEntry>[])
        .take(5)
        .toList();
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _fieldBorder),
      ),
      child: apps.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              child: Center(
                child: Text(
                  'reports.noAppsData'.tr(),
                  textAlign: TextAlign.center,
                  style: _pop(13, c: _dim),
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < apps.length; i++) ...[
                  _AppTile(rank: i + 1, app: apps[i]),
                  if (i < apps.length - 1)
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
  const _AppTile({required this.rank, required this.app});

  final int rank;
  final AppUsageEntry app;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 34,
              height: 34,
              child: AppIconWidget(
                packageName: app.packageName,
                iconUrl: app.iconUrl,
                iconBase64: app.iconBase64,
                size: 34,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$rank. ${app.appName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _unb(15),
            ),
          ),
          Text(_fmtHm(app.totalTimeMs), style: _pop(13, c: _dim)),
        ],
      ),
    );
  }
}

// ════════════ Umumiy widgetlar ════════════

/// Ism bosh harfli dumaloq avatar (reyting uchun).
class _LetterAvatar extends StatelessWidget {
  const _LetterAvatar({required this.letter, required this.size});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ch = letter.isNotEmpty ? letter[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _chipBg, shape: BoxShape.circle),
      child: Text(ch, style: _unb(size * 0.42, w: FontWeight.w700)),
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
        child: const Icon(
          SolarIconsOutline.arrowLeft,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}
