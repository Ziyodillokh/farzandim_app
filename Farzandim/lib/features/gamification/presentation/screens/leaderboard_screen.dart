// "DON reytingi" — Parvoz dizayn. Tepada orqa/yordam tugmalari, davr
// tablari, top-3 podium (medallar), paginated ro'yxat va pastda yopishqoq
// "Siz" pill'i. Pill'ni bossa bola qatoriga silliq scroll + porlash.
// Reyting DON'dan hisoblanadi (ChildProfile.donBalance) — panel'dagi "DON
// balansi" bilan AYNAN bir xil son. Avval qiymat XP edi, lekin "DON" deb
// yozilardi → bitta bola panelda 210, shu ekranda 260 ko'rinardi.

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/gamification/data/models/leaderboard_models.dart';
import 'package:farzandim/features/gamification/data/repositories/leaderboard_repository.dart';
import 'package:farzandim/features/gamification/presentation/providers/leaderboard_provider.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _bg = Color(0xFF00060A);
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x14FFFFFF); // oq ~8%
const _row = Color(0xFF21262A); // oddiy qator foni
const _meRow = Color(0xFF173654); // "Siz" qatori
const _meGlow = Color(0xFF1E4D80); // "Siz" qatori (porlaganda)
const _blue = Color(0xFF216BFF); // DON tegi
const _dim = Color(0x99FFFFFF); // oq 60%
const _sheetBg = Color(0xFF12171E); // "DON qanday yig'iladi?" varag'i foni
const _divider = Color(0x14FFFFFF); // oq ~8% ajratgich

// Podium bar ranglari
const _barSilver = Color(0xFFC9C9C9);
const _barGold = Color(0xFFD9AA46);
const _barBronze = Color(0xFFFF8951);

const _rowExtent = 71.0; // qator 68 + 3 gap (scroll matematikasi uchun)

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.45,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.4,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// DON qiymatini "1 250" ko'rinishida (mingliklar bo'sh joy bilan).
String _fmtDon(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Reyting (DON reytingi) ekrani.
class LeaderboardScreen extends ConsumerStatefulWidget {
  /// `LeaderboardScreen` konstruktor.
  const LeaderboardScreen({required this.childId, super.key});

  /// Qaysi bola uchun ("Siz" reytingi).
  final String childId;

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _period = 'all';
  final ScrollController _scroll = ScrollController();
  bool _glow = false; // "Siz" qatori porlashi (pill bosilgach)
  bool _jumping = false; // pill: bola qatorigacha yuklanmoqda
  bool _showPill = false;
  bool _needScrollReset = false; // davr almashgach ro'yxatni tepaga qaytarish

  // Scroll ichida yig'iluvchi header (tab + podium) — scroll paytida tepaga
  // chiqib ketadi. Balandligi o'lchanadi (pill/jump matematikasi tayanadi).
  final GlobalKey _headerKey = GlobalKey();
  double _headerExtent = 330;

  static const _periods = ['weekly', 'monthly', 'all'];

  LeaderboardArgs get _args =>
      (childId: widget.childId, period: _period, region: null);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final st = ref.read(leaderboardProvider(_args));
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 320) {
      ref.read(leaderboardProvider(_args).notifier).loadMore();
    }
    _syncPill(st);
  }

  /// Pill ko'rinishi: bola podium'da emas va qatori ko'rinmayotgan bo'lsa.
  void _syncPill(LeaderboardState st) {
    final cc = st.currentChild;
    // rank 0 = bu davrda DON yo'q — pill baribir ko'rsatiladi (bosilsa
    // hech narsa qilmaydi, faqat "Siz reytingda yo'q"ni bildiradi).
    final show =
        cc != null &&
        (cc.rank >= 4 || cc.rank == 0) &&
        !_childRowVisible(st, cc);
    if (show != _showPill && mounted) setState(() => _showPill = show);
  }

  /// Yig'iluvchi header (tab + podium) balandligini o'lchaydi — scroll
  /// matematikasi (pill ko'rinishi, qatorga sakrash) shunga tayanadi.
  void _measureHeader() {
    final h = _headerKey.currentContext?.size?.height;
    if (h != null && (h - _headerExtent).abs() > 0.5 && mounted) {
      setState(() => _headerExtent = h);
    }
  }

  bool _childRowVisible(LeaderboardState st, LeaderboardEntry cc) {
    final listIndex = cc.rank - 4; // `rest` ichidagi 0-indeks
    final restLen = st.entries.length > 3 ? st.entries.length - 3 : 0;
    if (listIndex < 0 || listIndex >= restLen) return false; // yuklanmagan
    if (!_scroll.hasClients) return false;
    final off = _scroll.offset;
    final vp = _scroll.position.viewportDimension;
    final top = _headerExtent + listIndex * _rowExtent;
    final visTop = math.max(top, off);
    final visBottom = math.min(top + _rowExtent, off + vp);
    return (visBottom - visTop) / _rowExtent >= 0.6;
  }

  /// Pill bosilganda — bola qatorigacha sahifalarni yuklab, silliq scroll +
  /// porlash animatsiyasi.
  Future<void> _jumpToChild() async {
    // Provider kalitini bir marta olamiz — await'lar orasida davr almashsa
    // (mutable _args), jump noto'g'ri provider'ga o'tib ketmasin.
    final args = _args;
    var st = ref.read(leaderboardProvider(args));
    final cc = st.currentChild;
    if (cc == null || cc.rank < 4) return;
    final listIndex = cc.rank - 4;

    setState(() => _jumping = true);
    var restLen = st.entries.length > 3 ? st.entries.length - 3 : 0;
    var guard = 0;
    while (listIndex >= restLen && st.hasMore && guard < 60) {
      await ref.read(leaderboardProvider(args).notifier).loadMore();
      // Fonda yuklash ketayotgan bo'lsa loadMore darhol qaytadi — biroz
      // kutamiz (aks holda sikl bo'sh aylanadi).
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted || _args != args) {
        if (mounted) setState(() => _jumping = false);
        return;
      }
      st = ref.read(leaderboardProvider(args));
      restLen = st.entries.length > 3 ? st.entries.length - 3 : 0;
      guard++;
    }
    if (!mounted || _args != args) {
      if (mounted) setState(() => _jumping = false);
      return;
    }
    setState(() => _jumping = false);
    if (listIndex >= restLen || !_scroll.hasClients) return;

    final vp = _scroll.position.viewportDimension;
    final target =
        (_headerExtent + listIndex * _rowExtent - vp / 2 + _rowExtent / 2)
            .clamp(0.0, _scroll.position.maxScrollExtent);
    await _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    setState(() => _glow = true);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _glow = false);
    });
  }

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const _HowToEarnSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(leaderboardProvider(_args));
    // Ma'lumot o'zgarganda (loadMore/refresh) pill ko'rinishini qayta
    // hisoblaymiz — frame'dan keyin (scroll o'lchamlari yangilangach).
    ref.listen(leaderboardProvider(_args), (_, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _measureHeader();
        // Davr almashib yangi ro'yxat yuklangach — tepaga qaytaramiz.
        if (_needScrollReset && !next.initialLoading && _scroll.hasClients) {
          _scroll.jumpTo(0);
          _needScrollReset = false;
        }
        _syncPill(next);
      });
    });
    final top3 = st.entries.take(3).toList();
    final rest = st.entries.length > 3
        ? st.entries.sublist(3)
        : <LeaderboardEntry>[];
    final cc = st.currentChild;

    // Header balandligini build'dan keyin o'lchaymiz (podium yuklangach);
    // farq bo'lsagina setState qiladi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureHeader();
    });

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const _BlueGlow(),
          SafeArea(
            child: Column(
              children: [
                _Header(onBack: () => context.pop(), onHelp: _showHelp),
                Expanded(child: _buildScroll(st, top3, rest)),
              ],
            ),
          ),
          // Yopishqoq "Siz" pill'i.
          if (cc != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: IgnorePointer(
                ignoring: !_showPill,
                child: AnimatedOpacity(
                  opacity: _showPill ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: AnimatedSlide(
                    offset: _showPill ? Offset.zero : const Offset(0, 0.3),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _StickyPill(
                        entry: cc,
                        childId: widget.childId,
                        loading: _jumping,
                        onTap: _jumping ? null : _jumpToChild,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScroll(
    LeaderboardState st,
    List<LeaderboardEntry> top3,
    List<LeaderboardEntry> rest,
  ) {
    if (st.initialLoading) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: _blue),
        ),
      );
    }
    if (st.error) {
      return Center(
        child: Text('leaderboard.loadFailed'.tr(), style: _pop(14, c: _dim)),
      );
    }
    if (st.entries.isEmpty) {
      return Center(
        child: Text('leaderboard.noRatingYet'.tr(), style: _pop(14, c: _dim)),
      );
    }
    return CustomScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Yig'iluvchi header (davr tablari + podium) — scroll paytida tepaga
        // chiqib ketadi (2-rasmdagi holat: faqat sarlavha + ro'yxat + pill).
        SliverToBoxAdapter(
          child: Column(
            key: _headerKey,
            children: [
              const SizedBox(height: 14),
              _PeriodTabs(
                periods: _periods,
                active: _period,
                onChanged: (p) {
                  if (p == _period) return;
                  setState(() {
                    _period = p;
                    _glow = false;
                    _showPill = false;
                    _needScrollReset = true;
                  });
                },
              ),
              const SizedBox(height: 20),
              _Podium(top3: top3),
              const SizedBox(height: 16),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverFixedExtentList(
            itemExtent: _rowExtent,
            delegate: SliverChildBuilderDelegate((context, i) {
              if (i >= rest.length) {
                return const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _dim,
                    ),
                  ),
                );
              }
              final e = rest[i];
              final isMe = e.childId == widget.childId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: _LeaderRow(entry: e, isMe: isMe, glowing: isMe && _glow),
              );
            }, childCount: rest.length + (st.hasMore ? 1 : 0)),
          ),
        ),
        // Oxirgi qator pill ostida qolmasligi uchun bo'sh joy.
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}

// ════════════ Fon: ko'k porlash ════════════
class _BlueGlow extends StatelessWidget {
  const _BlueGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            width: 360,
            height: 360,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x59216BFF), Color(0x00216BFF)],
                stops: [0, 0.72],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════ Sarlavha ════════════
class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onHelp});

  final VoidCallback onBack;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _SquareButton(icon: SolarIconsOutline.arrowLeft, onTap: onBack),
          Expanded(
            child: Center(
              child: Text(
                'leaderboard.title'.tr(),
                style: _unb(20, w: FontWeight.w500, ls: -0.6),
              ),
            ),
          ),
          _SquareButton(icon: SolarIconsBold.questionCircle, onTap: onHelp),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

// ════════════ Davr tablari ════════════
class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({
    required this.periods,
    required this.active,
    required this.onChanged,
  });

  final List<String> periods;
  final String active;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _cardBorder),
        ),
        child: Row(
          children: [
            for (final p in periods)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(p),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p == active ? _blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'leaderboard.periods.$p'.tr(),
                      style: _pop(
                        13,
                        w: FontWeight.w500,
                        c: p == active ? Colors.white : _dim,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════ Podium (top-3) ════════════
class _Podium extends StatelessWidget {
  const _Podium({required this.top3});

  final List<LeaderboardEntry> top3;

  LeaderboardEntry? _at(int rank) {
    for (final e in top3) {
      if (e.rank == rank) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final first = _at(1);
    final second = _at(2);
    final third = _at(3);
    if (first == null) return const SizedBox(height: 8);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: second == null
                  ? const SizedBox.shrink()
                  : _PodiumCard(
                      entry: second,
                      medal: 'assets/images/leaderboard/medal_silver.png',
                      barColor: _barSilver,
                      badge: const [
                        Color(0xFF929292),
                        Color(0xFFD2D2D2),
                        Color(0xFF6D6D6D),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _PodiumCard(
                entry: first,
                first: true,
                medal: 'assets/images/leaderboard/medal_gold.png',
                barColor: _barGold,
                badge: const [
                  Color(0xFFFFAE00),
                  Color(0xFFFFD16F),
                  Color(0xFF996900),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: third == null
                  ? const SizedBox.shrink()
                  : _PodiumCard(
                      entry: third,
                      medal: 'assets/images/leaderboard/medal_bronze.png',
                      barColor: _barBronze,
                      badge: const [
                        Color(0xFFFF4800),
                        Color(0xFFFFA16F),
                        Color(0xFF991700),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.entry,
    required this.medal,
    required this.barColor,
    required this.badge,
    this.first = false,
  });

  final LeaderboardEntry entry;
  final String medal;
  final Color barColor;
  final List<Color> badge;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final avatarSz = first ? 88.0 : 72.0;
    final barH = first ? 96.0 : 74.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Avatar(childId: entry.childId, name: entry.name, size: avatarSz),
        const SizedBox(height: 8),
        Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _unb(13, ls: -0.39),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: badge,
              stops: const [0.04, 0.39, 0.96],
            ),
          ),
          child: Text('${_fmtDon(entry.don)} DON', style: _unb(10, ls: -0.3)),
        ),
        const SizedBox(height: 8),
        Container(
          height: barH,
          width: double.infinity,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Image.asset(medal, width: 54, height: 54, cacheWidth: 120),
          ),
        ),
      ],
    );
  }
}

// ════════════ Reyting qatori ════════════
class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.entry,
    required this.isMe,
    required this.glowing,
  });

  final LeaderboardEntry entry;
  final bool isMe;
  final bool glowing;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isMe ? (glowing ? _meGlow : _meRow) : _row,
        borderRadius: BorderRadius.circular(24),
        boxShadow: glowing
            ? [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ]
            : null,
        border: glowing
            ? Border.all(color: const Color(0xFF3B82F6), width: 2)
            : null,
      ),
      child: Row(
        children: [
          _Avatar(childId: entry.childId, name: entry.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${entry.rank}. ${entry.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _unb(15),
            ),
          ),
          const SizedBox(width: 8),
          Text(_fmtDon(entry.don), style: _unb(15)),
          const SizedBox(width: 6),
          const _DonTag(),
        ],
      ),
    );
  }
}

/// Ko'k "DON" tegi.
class _DonTag extends StatelessWidget {
  const _DonTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text('DON', style: _pop(13, w: FontWeight.w600)),
    );
  }
}

// ════════════ Avatar (tarmoq + harf fallback) ════════════
class _Avatar extends ConsumerWidget {
  const _Avatar({
    required this.childId,
    required this.name,
    required this.size,
  });

  final String childId;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.read(leaderboardRepositoryProvider).avatarUrl(childId);
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: 200,
          placeholder: (_, __) => _fallback(),
          errorWidget: (_, __, ___) => _fallback(),
        ),
      ),
    );
  }

  // Rasm yo'q/yuklanmagan — HARF emas, DEFAULT AVATAR (jingalak-ko'zoynak).
  // Dashboard mini-reyting bilan bir xil (ChildAvatar'dagi kabi asset SVG).
  Widget _fallback() {
    return ColoredBox(
      color: const Color(0xFF2A3038),
      child: SvgPicture.asset(
        'assets/stickers/default_avatar.svg',
        fit: BoxFit.cover,
      ),
    );
  }
}

// ════════════ Yopishqoq "Siz" pill'i ════════════
class _StickyPill extends StatelessWidget {
  const _StickyPill({
    required this.entry,
    required this.childId,
    required this.loading,
    required this.onTap,
  });

  final LeaderboardEntry entry;
  final String childId;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rankText = entry.rank > 0 ? '${entry.rank}. ' : '';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                _Avatar(childId: childId, name: entry.name, size: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$rankText${entry.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _unb(15),
                  ),
                ),
                const SizedBox(width: 10),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else ...[
                  Text(_fmtDon(entry.don), style: _unb(15)),
                  const SizedBox(width: 6),
                  const _DonTag(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════ "DON qanday yig'iladi?" varag'i ════════════
class _HowToEarnSheet extends StatelessWidget {
  const _HowToEarnSheet();

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return Container(
      height: math.max(h * 0.62, 480),
      decoration: const BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: _cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            children: [
              // Tortish dastagi
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 22),
              Text('leaderboard.howToEarn.title'.tr(), style: _unb(17)),
              const SizedBox(height: 22),
              _EarnRow(
                icon: SolarIconsBold.book,
                title: 'leaderboard.howToEarn.readBook.title'.tr(),
                sub: 'leaderboard.howToEarn.readBook.sub'.tr(),
                don: 100,
              ),
              const _EarnDivider(),
              _EarnRow(
                icon: SolarIconsBold.clipboard,
                title: 'leaderboard.howToEarn.doTest.title'.tr(),
                sub: 'leaderboard.howToEarn.doTest.sub'.tr(),
                don: 100,
              ),
              const _EarnDivider(),
              _EarnRow(
                icon: SolarIconsBold.play,
                title: 'leaderboard.howToEarn.watchVideo.title'.tr(),
                sub: 'leaderboard.howToEarn.watchVideo.sub'.tr(),
                don: 100,
              ),
              const Spacer(),
              ParvozSecondaryButton(
                label: 'common.close'.tr(),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bitta "yo'l" qatori: ikon + sarlavha/quyi sarlavha + DON qiymati.
class _EarnRow extends StatelessWidget {
  const _EarnRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.don,
  });

  final IconData icon;
  final String title;
  final String sub;
  final int don;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _row,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cardBorder),
            ),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _unb(14),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _pop(12, c: _dim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(_fmtDon(don), style: _unb(15)),
          const SizedBox(width: 6),
          const _DonTag(),
        ],
      ),
    );
  }
}

/// Qatorlar orasidagi ingichka ajratgich.
class _EarnDivider extends StatelessWidget {
  const _EarnDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: _divider);
  }
}
