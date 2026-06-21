// ─────────────────────────────────────────────────────────────────────
// Konkurslar — "Parvoz Premium" dizayn tizimi (Stitch)
// ─────────────────────────────────────────────────────────────────────
//
// Butun contests feature shu palitradan foydalanadi (asosiy + ichki
// sahifalar). Night asosiy (Stitch aniq), light — sodda oq versiya.
// Brend aqua #22D3EE bilan birxil (boshqa redizayn ekranlar bilan).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Konkurslar palitrasi — `CP(context.adaptive.isDark)`.
class CP {
  CP(this.dark);
  final bool dark;

  Color get bg => dark ? const Color(0xFF0B1C30) : const Color(0xFFF6F8FC);
  Color get card => dark ? const Color(0xFF213145) : Colors.white;
  Color get cardHigh => dark ? const Color(0xFF2A3C54) : const Color(0xFFEEF3FB);
  Color get border => dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFDCE6F2);
  Color get tabBg => dark ? const Color(0xFF18283D) : const Color(0xFFE9EFF8);

  Color get text => dark ? const Color(0xFFEAF1F2) : const Color(0xFF0B1C30);
  Color get muted => dark ? const Color(0xFFA7B7BD) : const Color(0xFF5A6B73);
  Color get dot => dark ? const Color(0xFF3C494C) : const Color(0xFFC3D0D4);

  /// Brend aqua aksent (logo, star, +XP, faol tab, CTA).
  Color get accent => const Color(0xFF22D3EE);
  Color get accentSoft => const Color(0xFF8AEBFF);
  Color get onAccent => const Color(0xFF06222E);

  Color get danger => const Color(0xFFF43F5E);
  Color get warn => const Color(0xFFFBBF24);
  Color get gold => const Color(0xFFFFC83D);

  /// Deadline pill rangi — qolgan vaqtga qarab.
  Color deadlineColor(Duration r) {
    if (r.isNegative) return muted;
    final d = r.inDays;
    if (d <= 2) return danger;
    if (d <= 5) return warn;
    return accent;
  }
}

/// Plus Jakarta Sans matn yordamchisi.
TextStyle cjak(
  CP p, {
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

/// "1.2k" / "850" — ishtirokchi sonini ixcham format.
String compactCount(int n) =>
    n >= 1000 ? '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k' : '$n';

/// Subject badge — to'q-shisha fon + rangli border/matn (Stitch premium).
class SubjectBadge extends StatelessWidget {
  const SubjectBadge({required this.label, required this.color, required this.icon, super.key});
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.22), const Color(0xFF0B1C30)).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.40), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.2)),
        ],
      ),
    );
  }
}
