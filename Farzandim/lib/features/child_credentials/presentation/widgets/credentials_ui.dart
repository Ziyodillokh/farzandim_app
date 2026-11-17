// ─────────────────────────────────────────────────────────────────────
// credentials_ui — kirish ma'lumotlari ekranlarining umumiy qismlari
// ─────────────────────────────────────────────────────────────────────
//
// Tokenlar (maktab ekranlari bilan bir xil palitra), matn uslublari, karta,
// qator va tasdiqlash oynasi. Varaqlar `enableDrag: false` bilan ochiladi:
// vaqtinchalik parol tasodifan pastga tortib yopilmasin.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Rang va matn uslublari.
abstract final class CredStyle {
  static const Color card = Color(0xFF1A1F23);
  static const Color cardBorder = Color(0x1FFFFFFF); // oq 12%
  static const Color chipBg = Color(0xFF1B2128);
  static const Color row = Color(0x0AFFFFFF); // oq 4%
  static const Color rowBorder = Color(0x14FFFFFF); // oq 8%
  static const Color dim = Color(0x99FFFFFF); // oq 60%
  static const Color blue = Color(0xFF216BFF);
  static const Color green = Color(0xFF34C759);
  static const Color amber = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFFF5A5D);

  /// Sarlavha va katta qiymatlar uchun.
  static TextStyle unb(
    double size, {
    FontWeight w = FontWeight.w600,
    Color c = Colors.white,
    double ls = -0.4,
  }) => GoogleFonts.unbounded(
    fontSize: size,
    fontWeight: w,
    color: c,
    letterSpacing: ls,
    height: 1.3,
  );

  /// Matn, yorliq va tugmalar uchun.
  static TextStyle pop(
    double size, {
    FontWeight w = FontWeight.w400,
    Color c = Colors.white,
  }) =>
      GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);
}

/// Yassi karta (oq 7%/to'q fon, yumaloq burchak, ingichka chegara).
class CredCard extends StatelessWidget {
  const CredCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: CredStyle.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CredStyle.cardBorder),
      ),
      child: child,
    );
  }
}

/// "Yorliq ........ qiymat" qatori.
class CredInfoRow extends StatelessWidget {
  const CredInfoRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: CredStyle.pop(13.5, c: CredStyle.dim)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: CredStyle.pop(14, w: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Doira ichidagi ikon (karta va bo'sh holat uchun).
class CredIconChip extends StatelessWidget {
  const CredIconChip({
    required this.icon,
    this.size = 44,
    this.color = Colors.white,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: CredStyle.chipBg,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Varaq ochadi: qorong'i fon, tortib yopilmaydi ([dismissible] bo'lsa
/// fon bosilsa yopiladi).
Future<T?> showCredentialsSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    isDismissible: dismissible,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: builder,
  );
}

/// Ikki tugmali tasdiqlash oynasi; `true` — tasdiqlandi. [destructive] —
/// tasdiqlash tugmasi qizil (qaytarib bo'lmaydigan amal).
Future<bool> showCredentialsConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: CredStyle.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: CredStyle.cardBorder),
      ),
      title: Text(title, style: CredStyle.unb(17)),
      content: Text(body, style: CredStyle.pop(14, c: CredStyle.dim)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel, style: CredStyle.pop(15, c: CredStyle.dim)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            confirmLabel,
            style: CredStyle.pop(
              15,
              w: FontWeight.w600,
              c: destructive ? CredStyle.danger : Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
