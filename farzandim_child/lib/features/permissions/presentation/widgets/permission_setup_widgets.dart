// ─────────────────────────────────────────────────────────────────────
// Ruxsatlar ekrani vidjetlari — Android va iOS ekranlari uchun umumiy
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Parvoz tokenlari (lokal, ko'k).
abstract final class PermColors {
  static const bg = Color(0xFF02060D);
  static const blue = Color(0xFF216BFF);
  static const blueLight = Color(0xFF3C82FF);
  static const green = Color(0xFF34C759);
  static const dim = Color(0x99FFFFFF);
}

// ════════════ Bo'lim sarlavhasi ════════════
class PermSectionLabel extends StatelessWidget {
  const PermSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: const Color(0xCCFFFFFF),
        ),
      ),
    );
  }
}

// ════════════ Guruh kartasi (shisha) ════════════
class PermGroupCard extends StatelessWidget {
  const PermGroupCard({super.key, required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i < rows.length - 1) {
        children.add(
          const Divider(
            height: 1,
            thickness: 1,
            indent: 14,
            endIndent: 14,
            color: Color(0x14FFFFFF),
          ),
        );
      }
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x14FFFFFF), Color(0x08FFFFFF)],
        ),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Column(children: children),
    );
  }
}

// ════════════ Bitta ruxsat qatori ════════════
class PermRow extends StatelessWidget {
  const PermRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(icon, size: 22, color: const Color(0xFF12171E)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          PermToggle(value: value, onTap: onChanged),
        ],
      ),
    );
  }
}

// ════════════ Yashil toggle ════════════
class PermToggle extends StatelessWidget {
  const PermToggle({super.key, required this.value, required this.onTap});
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? PermColors.green : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════ "Keyingisi" tugma (ko'k) ════════════
class PermNextButton extends StatelessWidget {
  const PermNextButton({
    super.key,
    required this.enabled,
    required this.onTap,
    this.label,
  });
  final bool enabled;
  final VoidCallback onTap;

  /// Tugma matni; berilmasa `permissionSetup.next`.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [PermColors.blueLight, PermColors.blue],
            ),
            boxShadow: [
              BoxShadow(
                color: PermColors.blue.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: -2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label ?? 'permissionSetup.next'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════ Burchak ko'k yog'du ════════════
class PermCornerGlow extends StatelessWidget {
  const PermCornerGlow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 320,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0x40216BFF), Color(0x00216BFF)],
          stops: [0, 0.7],
        ),
      ),
    );
  }
}
