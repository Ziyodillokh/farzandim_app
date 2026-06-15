// ─────────────────────────────────────────────────────────────────────
// ContestCard — Stitch "Konkurslar Parvoz Premium" kartasi
// ─────────────────────────────────────────────────────────────────────
//
// Rasm-tepa glass karta: subject badge (rasm ustida), title + tavsif,
// star + bonus XP, stats qatori (ishtirokchi · yosh · deadline pill).
// Aktiv → /contest-start. Yakunlangan → SnackBar (real logika saqlandi).

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/presentation/contests_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class ContestCard extends StatefulWidget {
  const ContestCard({required this.contest, super.key});
  final ContestModel contest;

  @override
  State<ContestCard> createState() => _ContestCardState();
}

class _ContestCardState extends State<ContestCard> {
  bool _pressed = false;

  void _onTap() {
    final c = widget.contest;
    if (c.isActive) {
      HapticFeedback.selectionClick();
      context.push('/contest-start', extra: c);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konkurs natijalari tez orada'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CP(context.adaptive.isDark);
    final c = widget.contest;
    final finished = !c.isActive;

    final card = Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _pressed ? p.accent.withValues(alpha: 0.45) : p.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _image(p, c),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: cjak(p, size: 17, weight: FontWeight.w700, spacing: -0.2)),
                          const SizedBox(height: 3),
                          Text(c.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: cjak(p, size: 13, weight: FontWeight.w400, color: p.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(Icons.star_rounded, color: p.accent, size: 20),
                        const SizedBox(height: 1),
                        Text('+${c.bonus} XP',
                            style: cjak(p, size: 12, weight: FontWeight.w800, color: p.accent, spacing: -0.2)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _stats(p, c, finished),
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: _onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          child: Opacity(opacity: finished ? 0.74 : 1, child: card),
        ),
      ),
    );
  }

  // ─── rasm + badge ───
  Widget _image(CP p, ContestModel c) {
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (c.imageUrl.isNotEmpty)
            Image.network(c.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder(c))
          else
            _placeholder(c),
          // Badge o'qilishi uchun yengil tepa scrim.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Color(0x550B1C30), Colors.transparent],
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: SubjectBadge(label: c.soha, color: c.placeholderColor, icon: c.placeholderIcon),
          ),
          if (!c.isActive)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1C30).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Text('YAKUNLANGAN',
                    style: cjak(p, size: 9.5, weight: FontWeight.w800, color: Colors.white, spacing: 0.5)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(ContestModel c) {
    final col = c.placeholderColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(col.withValues(alpha: 0.55), const Color(0xFF0B1C30)),
            const Color(0xFF0B1C30),
          ],
        ),
      ),
      child: Center(child: Icon(c.placeholderIcon, size: 54, color: col.withValues(alpha: 0.9))),
    );
  }

  // ─── stats qatori ───
  Widget _stats(CP p, ContestModel c, bool finished) {
    Widget dot() => Container(
        width: 3, height: 3, margin: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(color: p.dot, shape: BoxShape.circle));

    final children = <Widget>[
      Icon(Icons.group_rounded, size: 15, color: p.muted),
      const SizedBox(width: 4),
      Text('${compactCount(c.ishtirokchilarSoni)} ishtirokchi',
          style: cjak(p, size: 12, weight: FontWeight.w500, color: p.muted)),
    ];

    if (c.ageLabel != null) {
      children..add(dot())..add(Text(c.ageLabel!, style: cjak(p, size: 12, weight: FontWeight.w500, color: p.muted)));
    }

    children.add(const Spacer());

    if (finished) {
      children.add(_pill(p, p.muted, Icons.flag_rounded, 'Yakunlandi'));
    } else {
      final r = c.remaining;
      final col = p.deadlineColor(r);
      final label = r.isNegative ? 'Tugadi' : '${c.remainingFormatted} qoldi';
      children.add(_pill(p, col, Icons.schedule_rounded, label));
    }

    return Row(children: children);
  }

  Widget _pill(CP p, Color color, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label, style: cjak(p, size: 11.5, weight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
