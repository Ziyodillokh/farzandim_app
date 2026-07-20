// ─────────────────────────────────────────────────────────────────────
// RankingScreen — "DON reytingi" (Figma 1:1, Parvoz ko'k)
// ─────────────────────────────────────────────────────────────────────
//
// Statistika'dagi "DON balansi" bosilganda ochiladi. Tuzilishi (Figma):
//   • Header: ← + "DON reytingi" + ? (yordam)
//   • Filtr: ko'k pill "Viloyat bo'yicha ✕" + chevron (viloyat tanlash)
//   • Podium top-3: markazda 1-o'rin (toj) + 2/3 yon tomonlarda, medal
//     ustunlari (oltin/kumush/bronza gradient)
//   • Ro'yxat: 4+ qatorlar (avatar + ism + "N DON" pill)
//   • Pastda yopishgan: bolaning O'Z qatori (yorug' karta)
//
// Real: filteredUsersProvider (+ viloyat filtri). Bo'sh bo'lsa PREVIEW.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/constants/uzbekistan_regions.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/ranking/presentation/providers/ranking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

import 'package:farzandim_child/features/ranking/presentation/widgets/ranking_avatar.dart';

// ════════════ Figma tokenlar ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _glass = Color(0x14FFFFFF);
const _glassBorder = Color(0x24FFFFFF);
const _dim = Color(0x99FFFFFF);
const _gold = Color(0xFFF2B233);
const _silver = Color(0xFFB7C3D6);
const _bronze = Color(0xFFE0703A);

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w700,
  Color c = Colors.white,
  double ls = -0.4,
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

String _fmtNum(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// Ro'yxat elementi (real yoki preview).
class _Row {
  const _Row(
    this.rank,
    this.name,
    this.don,
    this.color, {
    this.me = false,
    this.age = 10,
    this.gender,
    this.id = '',
  });
  final int rank;
  final String name;
  final int don;
  final Color color;
  final bool me;
  final int age;
  final String? gender;
  final String id;
}

/// Ro'yxat bo'sh bo'lgandagi HALOL holat.
///
/// Avval bu yerda ~100 ta SOXTA "preview" qator bor edi (o'ylab topilgan
/// ismlar va DON ballari). Natijada viloyat tanlanganda ro'yxat bo'sh
/// chiqsa ham ekran o'sha soxta ro'yxatni ko'rsatardi — foydalanuvchi
/// "viloyat filtri ishlamayapti" deb o'ylardi. Endi real holat ko'rsatiladi.
class _EmptyRanking extends StatelessWidget {
  const _EmptyRanking();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 56,
            color: Colors.white.withValues(alpha: 0.28),
          ),
          const SizedBox(height: 14),
          Text(
            'ranking.emptyTitle'.tr(),
            textAlign: TextAlign.center,
            style: _unb(16),
          ),
          const SizedBox(height: 8),
          Text(
            'ranking.emptySubtitle'.tr(),
            textAlign: TextAlign.center,
            style: _pop(13, c: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

/// "DON reytingi" sahifasi.
class RankingScreen extends ConsumerStatefulWidget {
  /// `RankingScreen` konstruktor.
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {
  final _scroll = ScrollController();

  // Bitta qator balandligi: tile (10+38+10) + oraliq 8.
  static const double _rowExtent = 66;
  // Yig'ilgan holatdagi ro'yxat geometriyasi: list tepa padding (8) +
  // panel ichki padding (12) + panel ichidagi top-3 blok (3 qator).
  static const double _collapsedListTop = 8 + 12 + 3 * _rowExtent;

  /// Scroll boshlanganda podium YIG'ILIB 1/2/3 oddiy qatorga aylanadi;
  /// tepaga qaytilganda yana podium ochiladi.
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final off = _scroll.offset;
      // Histerezis: ozgina scroll bo'lishi bilanoq yig'iladi — shunda
      // 1-o'rin qatori ekranda ko'rinib qoladi; podium faqat eng tepaga
      // to'liq qaytilgandagina ochiladi.
      if (!_collapsed && off > 10) {
        setState(() => _collapsed = true);
      } else if (_collapsed && off <= 2) {
        setState(() => _collapsed = false);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Pastdagi O'Z qatori bosilganda ro'yxatda o'z atrofiga scroll qiladi
  /// (o'z qatori ekran markazida bo'ladi). Ro'yxatda bo'lmasa — oxiriga.
  void _jumpToMe(int? myIndex) {
    if (!_scroll.hasClients) return;
    // Scroll paytida podium yig'ilgan bo'ladi — hisob shu (oxirgi) holat
    // geometriyasi bo'yicha (podium balandligi 0).
    setState(() => _collapsed = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final viewport = _scroll.position.viewportDimension;
      double target;
      if (myIndex == null) {
        target = _scroll.position.maxScrollExtent;
      } else {
        target = _collapsedListTop + myIndex * _rowExtent - viewport / 2;
        target = target.clamp(0, _scroll.position.maxScrollExtent);
      }
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(filteredUsersProvider);
    final range = ref.watch(timeRangeProvider);
    final region = ref.watch(selectedRegionProvider);
    final childId = ref.watch(pairingStateProvider).childId;

    // Real ro'yxat → _Row'lar. MOCK PREVIEW OLIB TASHLANDI: avval ro'yxat
    // bo'sh bo'lsa 100 ta SOXTA qator ko'rsatilardi. Natijada viloyat
    // tanlanganda (ro'yxat bo'sh chiqsa) ekran o'sha soxta ro'yxatni
    // ko'rsatib turardi va "viloyat filtri ishlamayapti" deb tushunilardi.
    // Endi bo'sh bo'lsa — HALOL bo'sh holat (`_EmptyRanking`).
    final rows = [
      for (var i = 0; i < users.length; i++)
        _Row(
          i + 1,
          users[i].name,
          scoreFor(users[i], range),
          users[i].avatarColor,
          me: users[i].id == childId,
          age: users[i].age,
          gender: users[i].gender,
          id: users[i].id,
        ),
    ];
    final meIdx = rows.indexWhere((r) => r.me);
    final _Row? meRow = meIdx >= 0 ? rows[meIdx] : null;
    final top3 = rows.take(3).toList();
    final rest = rows.length > 3 ? rows.sublist(3) : const <_Row>[];
    // O'z o'rnining `rest` ichidagi indeksi (scroll hisobi uchun).
    final myIdxInRest = rest.indexWhere((r) => r.me);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Row(
                    children: [
                      _RoundBtn(
                        icon: Icons.arrow_back_rounded,
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/dashboard');
                          }
                        },
                      ),
                      Expanded(
                        child: Text(
                          'ranking.title'.tr(),
                          textAlign: TextAlign.center,
                          style: _unb(20),
                        ),
                      ),
                      // DON tarixi — donlar qayerdan yig'ilgani.
                      _RoundBtn(
                        icon: Icons.history_rounded,
                        onTap: () => context.push('/don-history'),
                      ),
                      const SizedBox(width: 8),
                      _RoundBtn(
                        icon: Icons.question_mark_rounded,
                        onTap: () => _showHelp(context),
                      ),
                    ],
                  ),
                ),
                // ── Viloyat filtri ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: _RegionFilter(region: region),
                ),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(
                      10,
                      8,
                      10,
                      // Pastdagi yopishgan o'z qatori uchun joy.
                      90 + bottomInset,
                    ),
                    children: [
                      // Ro'yxat bo'sh — halol xabar (soxta preview o'rniga).
                      if (rows.isEmpty) const _EmptyRanking(),
                      // Podium bo'limi (naqshli to'q-ko'k fon, Figma) —
                      // scroll boshlanganda butunlay yig'iladi, top-3 esa
                      // pastdagi panel ichida oddiy qator bo'lib chiqadi.
                      if (top3.isNotEmpty)
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 260),
                          sizeCurve: Curves.easeOutCubic,
                          crossFadeState: _collapsed
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: _PodiumSection(top3: top3),
                          secondChild: const SizedBox(width: double.infinity),
                        ),
                      // Qatorlar paneli — yumaloq burchakli katta karta.
                      // Ro'yxat bo'sh bo'lsa bo'sh karta chiqmasin.
                      if (rows.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0F16),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            children: [
                              // Yig'ilganda 1/2/3 ham panel ichida qator.
                              if (top3.isNotEmpty)
                                AnimatedCrossFade(
                                  duration: const Duration(milliseconds: 260),
                                  sizeCurve: Curves.easeOutCubic,
                                  crossFadeState: _collapsed
                                      ? CrossFadeState.showSecond
                                      : CrossFadeState.showFirst,
                                  firstChild: const SizedBox(
                                    width: double.infinity,
                                  ),
                                  secondChild: Column(
                                    children: [
                                      for (final r in top3) ...[
                                        _RankTile(row: r, highlight: r.me),
                                        const SizedBox(height: 8),
                                      ],
                                    ],
                                  ),
                                ),
                              // O'z qatori (r.me) ro'yxatda ham ko'k bilan
                              // ajralib turadi — scroll qilinganda topiladi.
                              for (final r in rest) ...[
                                _RankTile(row: r, highlight: r.me),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // ── Pastga yopishgan O'Z qatori (bosilsa o'z atrofiga scroll) ──
            if (meRow != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: 10 + bottomInset,
                child: GestureDetector(
                  onTap: () => _jumpToMe(myIdxInRest >= 0 ? myIdxInRest : null),
                  behavior: HitTestBehavior.opaque,
                  child: _RankTile(row: meRow, highlight: true),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF12171E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _glassBorder),
        ),
        title: Text('ranking.helpTitle'.tr(), style: _unb(16)),
        content: Text(
          "Kitob o'qish, test ishlash va kunlik faollik uchun DON ball "
          "to'planadi. Reyting viloyat yoki butun O'zbekiston bo'yicha "
          'hisoblanadi.',
          style: _pop(13.5, c: _dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ranking.helpClose'.tr(), style: _pop(14, c: _blue)),
          ),
        ],
      ),
    );
  }
}

// ════════════ Viloyat filtri ════════════

class _RegionFilter extends ConsumerWidget {
  const _RegionFilter({required this.region});

  final String? region;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _pickRegion(context, ref),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: _glass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _glassBorder),
        ),
        child: Row(
          children: [
            if (region != null)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ranking.byRegion'.tr(),
                      style: _pop(13, w: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () =>
                          ref.read(selectedRegionProvider.notifier).state =
                              null,
                      child: const Icon(
                        Icons.cancel_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  'ranking.allUzbekistan'.tr(),
                  style: _pop(13.5, w: FontWeight.w500),
                ),
              ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 24,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRegion(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0E1319),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            ListTile(
              title: Text('ranking.allUzbekistan'.tr(), style: _pop(15)),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final r in UzbekistanRegions.all)
              ListTile(
                title: Text(r, style: _pop(15)),
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    ref.read(selectedRegionProvider.notifier).state = picked.isEmpty
        ? null
        : picked;
  }
}

// ════════════ Podium (top-3) ════════════

/// Podium bo'limi — Figma'dagidek to'q-ko'k gradient fon ustida xira
/// skuter naqshlari va top-3 podium.
class _PodiumSection extends StatelessWidget {
  const _PodiumSection({required this.top3});

  final List<_Row> top3;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1A2E), Color(0xFF040A12)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          // Xira skuter naqshlari (Figma fonidagi kabi).
          const Positioned(top: 6, left: 20, child: _BgScooter(angle: -0.3)),
          const Positioned(
            top: 2,
            right: 64,
            child: _BgScooter(angle: 0.25, size: 20),
          ),
          const Positioned(
            top: 96,
            left: 92,
            child: _BgScooter(angle: 0.15, size: 22),
          ),
          const Positioned(top: 72, right: 16, child: _BgScooter(angle: -0.2)),
          const Positioned(
            bottom: 44,
            left: 44,
            child: _BgScooter(angle: 0.3, size: 20),
          ),
          const Positioned(
            bottom: 20,
            right: 100,
            child: _BgScooter(angle: -0.35, size: 24),
          ),
          const Positioned(
            top: 40,
            left: 150,
            child: _BgScooter(angle: 0.1, size: 18),
          ),
          _Podium(top3: top3),
        ],
      ),
    );
  }
}

/// Fon uchun xira, biroz burilgan skuter ikonchasi.
class _BgScooter extends StatelessWidget {
  const _BgScooter({required this.angle, this.size = 26});

  final double angle;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Icon(
        SolarIconsOutline.scooter,
        size: size,
        color: const Color(0x14FFFFFF),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top3});

  final List<_Row> top3;

  @override
  Widget build(BuildContext context) {
    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: second == null
              ? const SizedBox.shrink()
              : _PodiumColumn(
                  row: second,
                  place: 2,
                  medal: _silver,
                  columnH: 96,
                  avatarSize: 76,
                ),
        ),
        Expanded(
          child: first == null
              ? const SizedBox.shrink()
              : _PodiumColumn(
                  row: first,
                  place: 1,
                  medal: _gold,
                  columnH: 128,
                  avatarSize: 92,
                  crown: true,
                ),
        ),
        Expanded(
          child: third == null
              ? const SizedBox.shrink()
              : _PodiumColumn(
                  row: third,
                  place: 3,
                  medal: _bronze,
                  columnH: 80,
                  avatarSize: 76,
                ),
        ),
      ],
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn({
    required this.row,
    required this.place,
    required this.medal,
    required this.columnH,
    required this.avatarSize,
    this.crown = false,
  });

  final _Row row;
  final int place;
  final Color medal;
  final double columnH;
  final double avatarSize;
  final bool crown;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (crown) Text('👑', style: _pop(20)),
        const SizedBox(height: 4),
        _Avatar(
          name: row.name,
          color: row.color,
          size: avatarSize,
          childId: row.id,
          gender: row.gender,
          age: row.age,
        ),
        const SizedBox(height: 8),
        Text(
          row.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _unb(place == 1 ? 15 : 13, w: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: medal,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${_fmtNum(row.don)} DON',
            style: _pop(
              11,
              w: FontWeight.w700,
              c: place == 2 ? const Color(0xFF2A3340) : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Medal ustuni — yorqin oltin/kumush/bronza gradient (Figma).
        Container(
          height: columnH,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(medal, Colors.white, 0.20)!,
                Color.lerp(medal, Colors.black, 0.30)!,
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 6),
          child: _Medal(place: place, base: medal),
        ),
      ],
    );
  }
}

/// Lentali dumaloq medal — ustun tepasida (Figma'dagi 🥇 uslubida).
class _Medal extends StatelessWidget {
  const _Medal({required this.place, required this.base});

  final int place;
  final Color base;

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(base, Colors.black, 0.35)!;
    final light = Color.lerp(base, Colors.white, 0.45)!;
    final numColor = place == 2 ? const Color(0xFF39424E) : Colors.white;
    return SizedBox(
      width: 58,
      height: 62,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Lentalar (medal orqasida, ikki tomonga qiya).
          Positioned(
            top: 0,
            left: 13,
            child: Transform.rotate(
              angle: 0.45,
              child: Container(
                width: 11,
                height: 26,
                decoration: BoxDecoration(
                  color: dark,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 13,
            child: Transform.rotate(
              angle: -0.45,
              child: Container(
                width: 11,
                height: 26,
                decoration: BoxDecoration(
                  color: dark,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          // Medal doirasi.
          Positioned(
            top: 14,
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [light, base, dark],
                ),
                border: Border.all(color: light, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: base.withValues(alpha: 0.55),
                  border: Border.all(
                    color: light.withValues(alpha: 0.85),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  '$place',
                  style: _unb(15, w: FontWeight.w800, c: numColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════ Ro'yxat qatori ════════════

class _RankTile extends StatelessWidget {
  const _RankTile({required this.row, this.highlight = false});

  final _Row row;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        // "Siz" qatori ko'k bilan aniq ajralib turadi.
        color: highlight ? const Color(0xFF102A4F) : _glass,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlight ? const Color(0xB3216BFF) : _glassBorder,
          width: highlight ? 1.4 : 1,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: _blue.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          _Avatar(
            name: row.name,
            color: row.color,
            size: 38,
            childId: row.id,
            gender: row.gender,
            age: row.age,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${row.rank}. ${row.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _unb(15, w: FontWeight.w600, ls: -0.2),
            ),
          ),
          if (highlight) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _blue),
              ),
              child: Text(
                'ranking.you'.tr(),
                style: _pop(10, w: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(_fmtNum(row.don), style: _unb(15, w: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('DON', style: _pop(10, w: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ════════════ Umumiy ════════════

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.color,
    required this.size,
    this.childId,
    this.gender,
    this.age,
  });

  final String name;
  final Color color;
  final double size;
  final String? childId;
  final String? gender;
  final int? age;

  // Ichki chegara YO'Q: rasm doirani chetigacha to'ldirsin. Avval 2px oq
  // chegara bor edi va rasm undan ichkariga qisilib, podium halqasi bilan
  // qo'shilganda "doira ichi to'la emas" bo'lib ko'rinardi.
  @override
  Widget build(BuildContext context) => RankingAvatar(
        name: name,
        size: size,
        childId: childId,
        gender: gender,
        age: age,
        color: color,
      );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});

  final IconData icon;
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
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}
