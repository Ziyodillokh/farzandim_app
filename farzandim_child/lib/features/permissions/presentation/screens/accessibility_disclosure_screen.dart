// ─────────────────────────────────────────────────────────────────────
// AccessibilityDisclosureScreen — "Tez bloklash" xizmati oshkoraligi
// ─────────────────────────────────────────────────────────────────────
//
// ⚠️ Google Play MAJBURIY talabi: AccessibilityService yoqishdan OLDIN
// foydalanuvchiga ALOHIDA ekranda quyidagilar aytilishi shart:
//   1. xizmat NIMA qiladi,
//   2. QANDAY ma'lumotga tegadi (va nimaga TEGMAYDI),
//   3. haqiqiy RAD ETISH imkoniyati bo'lishi kerak.
// Bu tushuntirishni umumiy rozilik ekraniga qo'shib yuborish MUMKIN EMAS —
// u o'z ekranida turishi kerak. Shuningdek tizim UI'siga taqlid qilmasligi
// kerak (aks holda "aldov" deb rad etiladi).
//
// Ekran hech narsani majburlamaydi: "Hozir emas" bosilsa ilova to'liq
// ishlayveradi, faqat bloklash sekinroq (UsageStats poll) ishga tushadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════ Parvoz tokenlar (ruxsat ekrani bilan bir xil) ════════════
const _bg = Color(0xFF02060D);
const _blue = Color(0xFF216BFF);
const _blueLight = Color(0xFF3C82FF);
const _dim = Color(0x99FFFFFF);

/// Rozilik berilgan vaqt (Play auditi uchun dalil sifatida saqlanadi).
const kAccessibilityConsentAtKey = 'accessibility.consent_at';

class AccessibilityDisclosureScreen extends StatelessWidget {
  const AccessibilityDisclosureScreen({super.key});

  /// Modal sifatida ochadi. Foydalanuvchi roziligini bildirsa `true`.
  static Future<bool> show(BuildContext context) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AccessibilityDisclosureScreen(),
        fullscreenDialog: true,
      ),
    );
    return ok ?? false;
  }

  Future<void> _accept(BuildContext context) async {
    // Rozilik vaqtini yozib qo'yamiz (Play tekshiruvida dalil).
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        kAccessibilityConsentAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      /* saqlanmasa ham oqim to'xtamasin */
    }
    if (!context.mounted) return;
    Navigator.of(context).pop(true);
    // Tizim sozlamalarini ochamiz — foydalanuvchi u yerda qo'lda yoqadi.
    await UsageStatsService().openAccessibilitySettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded, color: _dim),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _blue.withValues(alpha: 0.35)),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: _blueLight,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'a11yDisclosure.title'.tr(),
                style: GoogleFonts.unbounded(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'a11yDisclosure.subtitle'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.5,
                  color: _dim,
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _Bullet(
                      icon: Icons.block_rounded,
                      title: 'a11yDisclosure.doesTitle'.tr(),
                      text: 'a11yDisclosure.doesText'.tr(),
                    ),
                    _Bullet(
                      icon: Icons.visibility_off_rounded,
                      title: 'a11yDisclosure.notCollectTitle'.tr(),
                      text: 'a11yDisclosure.notCollectText'.tr(),
                    ),
                    _Bullet(
                      icon: Icons.tune_rounded,
                      title: 'a11yDisclosure.optionalTitle'.tr(),
                      text: 'a11yDisclosure.optionalText'.tr(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _PrimaryButton(
                label: 'a11yDisclosure.accept'.tr(),
                onTap: () => _accept(context),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                child: Text(
                  'a11yDisclosure.decline'.tr(),
                  style: GoogleFonts.poppins(fontSize: 14, color: _dim),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _blueLight, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.45,
                    color: _dim,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_blueLight, _blue]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _blue.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
