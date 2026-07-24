// ─────────────────────────────────────────────────────────────────────
// DonHistoryScreen — "DON tarixi" (ota-ona bolasining DON'ini ko'radi)
// ─────────────────────────────────────────────────────────────────────
//
// DON reytingi (LeaderboardScreen) header'idagi tarix ikonasidan ochiladi.
// Tuzilishi (Parvoz ko'k):
//   • Hero: jami yig'ilgan DON
//   • "Qayerdan": manba bo'yicha yig'indi (qadam / audiokitob / test / ...)
//   • "Barcha tarix": xronologik ro'yxat (har yozuv + sana + "+N DON")

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/don_history/data/models/don_history_entry.dart';
import 'package:farzandim/features/don_history/presentation/providers/don_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar ════════════
const _bg = Color(0xFF00060A);
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x14FFFFFF);
const _blue = Color(0xFF216BFF);
const _dim = Color(0x99FFFFFF);
const _dimmer = Color(0x66FFFFFF);

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.45,
}) => GoogleFonts.unbounded(
  fontSize: s,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.3,
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

String _fmtDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = today.difference(that).inDays;
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  if (diff == 0) return "${'donHistory.today'.tr()} $hh:$mm";
  if (diff == 1) return "${'donHistory.yesterday'.tr()} $hh:$mm";
  final months = 'donHistory.months'.tr().split(',');
  return '${d.day}-${months[d.month - 1]}';
}

/// DON tarixi ekrani — berilgan bola uchun.
class DonHistoryScreen extends ConsumerWidget {
  /// `DonHistoryScreen` konstruktor.
  const DonHistoryScreen({required this.childId, super.key});

  /// Qaysi bolaning DON tarixi.
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(donHistoryProvider(childId));
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  _SquareButton(
                    icon: SolarIconsOutline.arrowLeft,
                    onTap: () => context.pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'donHistory.title'.tr(),
                        style: _unb(20, w: FontWeight.w500, ls: -0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                data: (entries) =>
                    _Body(entries: entries, bottomInset: bottomInset),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: _blue),
                ),
                error: (_, __) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'donHistory.loadError'.tr(),
                      textAlign: TextAlign.center,
                      style: _pop(14, c: _dim),
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

class _Body extends StatelessWidget {
  const _Body({required this.entries, required this.bottomInset});

  final List<DonHistoryEntry> entries;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const _Empty();

    final totalDon = entries.fold<int>(0, (s, e) => s + e.don);
    final totals = summarizeByType(entries);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + bottomInset),
      children: [
        _HeroCard(totalDon: totalDon, sourceCount: totals.length),
        const SizedBox(height: 22),
        _SectionTitle('donHistory.sectionSource'.tr()),
        const SizedBox(height: 10),
        for (final t in totals) ...[
          _SourceTotalCard(total: t, grandTotal: totalDon),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 14),
        _SectionTitle('donHistory.sectionAll'.tr()),
        const SizedBox(height: 10),
        _HistoryCard(entries: entries),
      ],
    );
  }
}

// ════════════ Hero: jami DON ════════════
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.totalDon, required this.sourceCount});

  final int totalDon;
  final int sourceCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B4FD0), Color(0xFF216BFF)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            'donHistory.heroTitle'.tr(),
            style: _pop(13, c: const Color(0xCCFFFFFF)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars_rounded, color: Colors.white, size: 30),
              const SizedBox(width: 8),
              Text(_fmtNum(totalDon), style: _unb(34, ls: -1)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            sourceCount > 0
                ? 'donHistory.fromSources'.tr(
                    namedArgs: {'count': '$sourceCount'},
                  )
                : 'donHistory.empty'.tr(),
            style: _pop(12, c: const Color(0xB3FFFFFF)),
          ),
        ],
      ),
    );
  }
}

// ════════════ Manba yig'indisi ════════════
class _SourceTotalCard extends StatelessWidget {
  const _SourceTotalCard({required this.total, required this.grandTotal});

  final DonSourceTotal total;
  final int grandTotal;

  @override
  Widget build(BuildContext context) {
    final src = total.source;
    final pct = grandTotal > 0 ? total.total / grandTotal : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: src.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(src.icon, color: src.color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(src.label.tr(), style: _pop(15, w: FontWeight.w600)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: const Color(0x1FFFFFFF),
                    valueColor: AlwaysStoppedAnimation(src.color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'donHistory.times'.tr(namedArgs: {'count': '${total.count}'}),
                  style: _pop(11, c: _dimmer),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text('+${_fmtNum(total.total)}', style: _unb(16, c: src.color)),
        ],
      ),
    );
  }
}

// ════════════ Xronologik ro'yxat ════════════
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entries});

  final List<DonHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            _HistoryRow(entry: entries[i]),
            if (i < entries.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 66,
                endIndent: 14,
                color: Color(0x14FFFFFF),
              ),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final DonHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final src = entry.source;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: src.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(src.icon, color: src.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(src.label.tr(), style: _pop(14, w: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(_fmtDate(entry.date), style: _pop(12, c: _dimmer)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '+${_fmtNum(entry.don)}',
            style: _unb(15, c: const Color(0xFF34C759)),
          ),
        ],
      ),
    );
  }
}

// ════════════ Holatlar ════════════
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded, size: 56, color: _dimmer),
            const SizedBox(height: 16),
            Text(
              'donHistory.empty'.tr(),
              textAlign: TextAlign.center,
              style: _unb(17),
            ),
            const SizedBox(height: 8),
            Text(
              'donHistory.emptySubtitle'.tr(),
              textAlign: TextAlign.center,
              style: _pop(13, c: _dim),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text, style: _unb(15, ls: -0.3)),
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
