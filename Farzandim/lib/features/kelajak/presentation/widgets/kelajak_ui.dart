// ─────────────────────────────────────────────────────────────────────
// kelajak_ui — Kelajak sahifasining umumiy qismlari (Parvoz dizayn)
// ─────────────────────────────────────────────────────────────────────
//
// Uslub Growth kartalari bilan bir xil: karta #1A1F23, hairline oq 12%,
// radius 24, Unbounded sarlavha + Poppins matn. Gradient, binafsha rang
// va qo'shimcha animatsiya yo'q. Uch tilli backend matni joriy tilda
// (EasyLocalization bo'lmasa — o'zbekcha).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Tokenlar (Growth bilan bir xil) ════════════
const Color kelajakCard = Color(0xFF1A1F23);
const Color kelajakCardBorder = Color(0x1FFFFFFF); // oq 12%
const Color kelajakChipBg = Color(0xFF1B2128);
const Color kelajakTrack = Color(0x14FFFFFF); // oq 8%
const Color kelajakBlue = Color(0xFF216BFF);
const Color kelajakDim = Color(0x99FFFFFF); // oq 60%
const Color kelajakGreen = Color(0xFF34C759);
const Color kelajakAmber = Color(0xFFFBBF24);
const Color kelajakOrange = Color(0xFFFB923C);

/// Zaxira til (backend matnlari o'zbekchada to'liq).
const String _fallbackLanguage = 'uz';

TextStyle kelajakUnb(double size) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  letterSpacing: -0.6,
  height: 1.25,
);

TextStyle kelajakPop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.45);

/// Joriy til kodi; EasyLocalization yo'q (testlar) → o'zbekcha.
String kelajakLanguage(BuildContext context) =>
    EasyLocalization.of(context)?.locale.languageCode ?? _fallbackLanguage;

/// Backend matni joriy tilda; matn yo'q → bo'sh satr.
String kelajakText(BuildContext context, LocalizedText? text) =>
    text?.of(kelajakLanguage(context)) ?? '';

/// Bo'lim kartasi: ikon + sarlavha (+ izoh) va mazmun.
class KelajakSection extends StatelessWidget {
  const KelajakSection({
    required this.icon,
    required this.title,
    required this.child,
    this.hint,
    this.iconColor = Colors.white,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kelajakCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kelajakCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KelajakIconBadge(icon: icon, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: kelajakUnb(15)),
                ),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(hint, style: kelajakPop(12.5, c: kelajakDim)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Doiradagi ikon (bo'lim va kartalar uchun).
class KelajakIconBadge extends StatelessWidget {
  const KelajakIconBadge({
    required this.icon,
    this.color = Colors.white,
    this.size = 36,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: kelajakChipBg,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Kichik pill (yo'nalish, soha nomi).
class KelajakChip extends StatelessWidget {
  const KelajakChip({required this.label, this.icon, super.key});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kelajakChipBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: kelajakGreen),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: kelajakPop(12.5, w: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill'lar qatori (tor ekranda keyingi qatorga o'tadi).
class KelajakChipWrap extends StatelessWidget {
  const KelajakChipWrap({required this.labels, this.icon, super.key});

  final List<String> labels;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final label in labels)
          if (label.isNotEmpty) KelajakChip(label: label, icon: icon),
      ],
    );
  }
}

/// Sarlavha + izoh qatori (kuchli tomon, maslahat, tavsiya).
class KelajakTextTile extends StatelessWidget {
  const KelajakTextTile({required this.title, this.body, super.key});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final body = this.body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: kelajakPop(14.5, w: FontWeight.w600)),
        if (body != null && body.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(body, style: kelajakPop(13, c: kelajakDim)),
        ],
      ],
    );
  }
}

/// Ro'yxat elementlari orasiga bo'shliq qo'yadi.
List<Widget> kelajakSpaced(Iterable<Widget> items, {double gap = 12}) => [
  for (final (i, item) in items.indexed) ...[
    if (i > 0) SizedBox(height: gap),
    item,
  ],
];
