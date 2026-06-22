// ─────────────────────────────────────────────────────────────────────
// RankingScreen — "Reyting" (Parvoz Premium / Stitch dark-navy redizayn)
// ─────────────────────────────────────────────────────────────────────
//
// Ilova umumiy UI'siga (Bosh sahifa / Bildirishnoma) moslangan: deep navy
// fon, glass kartalar, aqua aksent, Plus Jakarta Sans. Logika o'zgarmagan —
// filteredUsersProvider / timeRangeProvider / selectedRegionProvider va
// scoreFor o'sha-o'sha ishlatiladi.

import 'package:farzandim_child/core/constants/uzbekistan_regions.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/ranking/data/models/ranking_user.dart';
import 'package:farzandim_child/features/ranking/presentation/providers/ranking_providers.dart';
import 'package:farzandim_child/shared/widgets/empty_state_mascot.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────── Stitch palette (bosh sahifa bilan bir xil) ───────────────

class _P {
  _P(this.dark);
  final bool dark;

  Color get bg => dark ? const Color(0xFF0B1C30) : const Color(0xFFF8F9FF);
  Color get card => dark ? const Color(0xFF213145) : Colors.white;
  Color get cardAlt => dark ? const Color(0xFF18283D) : const Color(0xFFEEF3FF);
  Color get text => dark ? const Color(0xFFF8F9FF) : const Color(0xFF0B1C30);
  Color get muted => dark ? const Color(0xFFCBDBF5) : const Color(0xFF5A6B66);
  Color get aqua => dark ? const Color(0xFF22D3EE) : const Color(0xFF0E7490);
  Color get border =>
      dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFD3E4FE);

  static const Color gold = Color(0xFFFFC83D);
  static const Color silver = Color(0xFFB7C3D6);
  static const Color bronze = Color(0xFFE08A4B);

  Color medalColor(int rank) => switch (rank) {
        1 => gold,
        2 => silver,
        3 => bronze,
        _ => aqua,
      };
}

TextStyle _jak(
  _P p, {
  double size = 14,
  FontWeight weight = FontWeight.w600,
  Color? color,
  double? height,
  double? spacing,
}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? p.text,
      height: height,
      letterSpacing: spacing,
    );

String _rangeLabel(TimeRange r) => switch (r) {
      TimeRange.kunlik => 'Kunlik',
      TimeRange.haftalik => 'Haftalik',
      TimeRange.oylik => 'Oylik',
      TimeRange.butunDavr => 'Butun davr',
    };

// ─────────────── SCREEN ───────────────

class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});

  // Screenshotdagi 3 ta pill.
  static const _ranges = [
    TimeRange.haftalik,
    TimeRange.oylik,
    TimeRange.butunDavr,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = _P(context.adaptive.isDark);
    final users = ref.watch(filteredUsersProvider);
    final range = ref.watch(timeRangeProvider);
    final region = ref.watch(selectedRegionProvider);
    final currentRank = ref.watch(currentUserRankProvider);

    return Scaffold(
      backgroundColor: p.bg,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(p: p, subtitle: _rangeLabel(range)),
            const SizedBox(height: 14),
            _RangePills(p: p, ranges: _ranges, active: range, ref: ref),
            const SizedBox(height: 12),
            _RegionFilter(p: p, region: region),
            const SizedBox(height: 6),
            Expanded(
              child: users.length < 3
                  ? _EmptyState(p: p)
                  : _List(
                      p: p,
                      users: users,
                      range: range,
                      currentRank: currentRank,
                      ref: ref,
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ChildBottomNavigation(),
    );
  }
}

// ─────────────── Header ───────────────

class _Header extends StatelessWidget {
  const _Header({required this.p, required this.subtitle});
  final _P p;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: p.text),
            onPressed: () => Navigator.maybeOf(context)?.maybePop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text('Reyting',
                    style: _jak(p, size: 22, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: _jak(p, size: 13, color: p.muted)),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.aqua.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.emoji_events_rounded, color: p.aqua, size: 22),
          ),
        ],
      ),
    );
  }
}

// ─────────────── Time-range pills (sliding aqua indicator) ───────────────

class _RangePills extends StatelessWidget {
  const _RangePills({
    required this.p,
    required this.ranges,
    required this.active,
    required this.ref,
  });
  final _P p;
  final List<TimeRange> ranges;
  final TimeRange active;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final idx = ranges.indexOf(active).clamp(0, ranges.length - 1);
    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.cardAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / ranges.length;
          return Stack(
            children: [
              AnimatedAlign(
                alignment: Alignment(-1 + 2 * (idx / (ranges.length - 1)), 0),
                duration: const Duration(milliseconds: 320),
                curve: const Cubic(0.34, 1.4, 0.5, 1),
                child: Container(
                  width: w,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: p.aqua,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final r in ranges)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(timeRangeProvider.notifier).state = r;
                        },
                        child: Center(
                          child: Text(
                            _rangeLabel(r),
                            style: _jak(
                              p,
                              size: 14,
                              weight: r == active
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: r == active
                                  ? const Color(0xFF06222B)
                                  : p.muted,
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
    );
  }
}

// ─────────────── Region filter pill ───────────────

class _RegionFilter extends ConsumerWidget {
  const _RegionFilter({required this.p, required this.region});
  final _P p;
  final String? region;

  void _open(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RegionSheet(p: p),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: p.cardAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.place_rounded, size: 18, color: p.aqua),
              const SizedBox(width: 8),
              Text(
                region ?? "Viloyatlar bo'yicha",
                style: _jak(p, size: 14, weight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegionSheet extends ConsumerWidget {
  const _RegionSheet({required this.p});
  final _P p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedRegionProvider);
    void pick(String? region) {
      ref.read(selectedRegionProvider.notifier).state = region;
      ref.read(rankingTabProvider.notifier).state =
          region == null ? RankingTab.umumiy : RankingTab.hudud;
      Navigator.pop(context);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Hududni tanlang',
                  style: _jak(p, size: 18, weight: FontWeight.w800)),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  _regionTile(p, "Barchasi (Viloyatlar bo'yicha)",
                      selected == null, () => pick(null)),
                  for (final r in UzbekistanRegions.all)
                    _regionTile(p, r, r == selected, () => pick(r)),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _regionTile(_P p, String label, bool sel, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      title: Text(label,
          style: _jak(p,
              size: 15,
              weight: sel ? FontWeight.w800 : FontWeight.w500,
              color: sel ? p.aqua : p.text)),
      trailing:
          sel ? Icon(Icons.check_rounded, color: p.aqua, size: 20) : null,
    );
  }
}

// ─────────────── List (podium + tiles + sticky current user) ───────────────

class _List extends StatelessWidget {
  const _List({
    required this.p,
    required this.users,
    required this.range,
    required this.currentRank,
    required this.ref,
  });
  final _P p;
  final List<RankingUser> users;
  final TimeRange range;
  final int currentRank;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    // Sticky: joriy user ro'yxatda (ko'rinmaydigan joyda) bo'lsa pastda pin.
    final showSticky = currentRank > 3 && currentRank <= users.length;

    return Stack(
      children: [
        RefreshIndicator(
          color: p.aqua,
          backgroundColor: p.card,
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            ref.invalidate(backendRankingProvider);
            await ref.read(backendRankingProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 12, 16, showSticky ? 180 : 120),
            children: [
              _Podium(p: p, users: users, range: range),
              const SizedBox(height: 20),
              for (int i = 3; i < users.length; i++)
                _RankTile(
                  p: p,
                  user: users[i],
                  rank: i + 1,
                  range: range,
                )
                    .animate()
                    .fadeIn(duration: 260.ms, delay: (45 * (i - 3)).ms)
                    .moveY(
                      begin: 14,
                      end: 0,
                      duration: 260.ms,
                      delay: (45 * (i - 3)).ms,
                      curve: Curves.easeOutCubic,
                    ),
            ],
          ),
        ),
        if (showSticky)
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: _StickyCurrentUser(
              p: p,
              user: users[currentRank - 1],
              rank: currentRank,
              range: range,
            ),
          ),
      ],
    );
  }
}

// ─────────────── Podium (2 - 1 - 3) ───────────────

class _Podium extends StatelessWidget {
  const _Podium({required this.p, required this.users, required this.range});
  final _P p;
  final List<RankingUser> users;
  final TimeRange range;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _PodiumSlot(p: p, user: users[1], rank: 2, range: range)),
        Expanded(child: _PodiumSlot(p: p, user: users[0], rank: 1, range: range)),
        Expanded(child: _PodiumSlot(p: p, user: users[2], rank: 3, range: range)),
      ],
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.p,
    required this.user,
    required this.rank,
    required this.range,
  });
  final _P p;
  final RankingUser user;
  final int rank;
  final TimeRange range;

  @override
  Widget build(BuildContext context) {
    final isFirst = rank == 1;
    final medal = p.medalColor(rank);
    final size = isFirst ? 88.0 : 68.0;

    return Padding(
      padding: EdgeInsets.only(bottom: isFirst ? 0 : 14),
      child: Column(
        children: [
          if (isFirst)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Icon(Icons.emoji_events_rounded,
                  color: _P.gold, size: 28),
            ),
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: medal, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: medal.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: _Avatar(user: user, size: size - 6),
              ),
              Positioned(
                bottom: -10,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: medal,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.bg, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text('$rank',
                      style: _jak(p,
                          size: 12,
                          weight: FontWeight.w800,
                          color: const Color(0xFF06222B))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _jak(p, size: 14, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _ScorePill(p: p, score: scoreFor(user, range)),
        ],
      ),
    );
  }
}

// ─────────────── Rank tile (4+) ───────────────

class _RankTile extends StatelessWidget {
  const _RankTile({
    required this.p,
    required this.user,
    required this.rank,
    required this.range,
  });
  final _P p;
  final RankingUser user;
  final int rank;
  final TimeRange range;

  @override
  Widget build(BuildContext context) {
    final me = user.isCurrentUser;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: me ? p.aqua.withValues(alpha: 0.12) : p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: me ? p.aqua.withValues(alpha: 0.55) : p.border,
          width: me ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('$rank',
                textAlign: TextAlign.center,
                style: _jak(p,
                    size: 15, weight: FontWeight.w800, color: p.muted)),
          ),
          const SizedBox(width: 8),
          _Avatar(user: user, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _jak(p, size: 15, weight: FontWeight.w700)),
                    ),
                    if (me) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.aqua,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('SIZ',
                            style: _jak(p,
                                size: 9,
                                weight: FontWeight.w800,
                                color: const Color(0xFF06222B))),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.region.isEmpty ? '—' : user.region,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _jak(p, size: 12, color: p.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ScorePill(p: p, score: scoreFor(user, range)),
        ],
      ),
    );
  }
}

// ─────────────── Sticky current user ───────────────

class _StickyCurrentUser extends StatelessWidget {
  const _StickyCurrentUser({
    required this.p,
    required this.user,
    required this.rank,
    required this.range,
  });
  final _P p;
  final RankingUser user;
  final int rank;
  final TimeRange range;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: p.aqua,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: p.aqua.withValues(alpha: 0.4),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('$rank',
                textAlign: TextAlign.center,
                style: _jak(p,
                    size: 15,
                    weight: FontWeight.w800,
                    color: const Color(0xFF06222B))),
          ),
          const SizedBox(width: 8),
          _Avatar(user: user, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Siz — ${user.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _jak(p,
                    size: 15,
                    weight: FontWeight.w800,
                    color: const Color(0xFF06222B))),
          ),
          Row(
            children: [
              const Icon(Icons.star_rounded,
                  color: Color(0xFF06222B), size: 18),
              const SizedBox(width: 3),
              Text('${scoreFor(user, range)}',
                  style: _jak(p,
                      size: 16,
                      weight: FontWeight.w800,
                      color: const Color(0xFF06222B))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────── Shared bits ───────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.size});
  final RankingUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            user.avatarColor,
            user.avatarColor.withValues(alpha: 0.7),
          ],
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.p, required this.score});
  final _P p;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: p.cardAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: _P.gold, size: 16),
          const SizedBox(width: 4),
          Text('$score', style: _jak(p, size: 14, weight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.p});
  final _P p;

  @override
  Widget build(BuildContext context) {
    return EmptyStateMascot(
      faroVariant: FaroVariant.faceExcited,
      accentColor: p.aqua,
      title: "Reyting hozircha bo'sh",
      subtitle: 'Konkurslarda ishtirok eting va reytingda joy oling!',
    );
  }
}
