// ─────────────────────────────────────────────────────────────────────
// LocationDisclosureScreen — fon joylashuvi (background location) oshkoraligi
// ─────────────────────────────────────────────────────────────────────
//
// ⚠️ Google Play rad etdi: "Inadequate Prominent Disclosure — The in-app
// Prominent Disclosure does not disclose the usage of accessed or collected
// Location data." (2026-08-04 xat).
//
// Sabab: `consent_screen.dart` joylashuvni umumiy aytadi, lekin
// `Permission.locationAlways` (ACCESS_BACKGROUND_LOCATION) so'ralishidan
// OLDIN alohida, aynan shu ruxsatga bog'liq tushuntirish YO'Q edi. Google'ning
// rasmiy talabi (support.google.com/googleplay/android-developer/answer/9799150):
// fon joylashuvi uchun OS ruxsat oynasidan BEVOSITA OLDIN, ilova-ichi ekranda:
//   1. "location" so'zi aniq ishlatilishi,
//   2. "ilova yopiq/ishlatilmayotganda ham" iborasi aniq bo'lishi,
//   3. HAR BIR funksiya alohida sanalishi (bitta umumiy jumla YETARLI EMAS),
//   4. ma'lumot kimga borishi (faqat ota-ona) va reklama uchun
//      ishlatilMAsligi aytilishi kerak.
// Bu ekran aynan shu naqshni takrorlaydi: [AccessibilityDisclosureScreen].
//
// ⚠️ Bu ruxsat ILOVANING ASOSIY funksiyasi uchun ZARUR (joylashuv kuzatuvi —
// mahsulotning o'zi). Shuning uchun "Hozir emas" bosilsa — accessibility'dan
// farqli o'laroq — foydalanuvchi ruxsat ekranida qoladi (xuddi OS ruxsat
// oynasini rad etgandagidek — bu YANGI qamash emas, MAVJUD xulqning bir
// qismi: `permission_setup_screen.dart`da `_location` (locationAlways)
// `_allGranted`ga kiradi).

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Parvoz tokenlar (boshqa disclosure ekranlari bilan bir xil) ════════════
const _bg = Color(0xFF02060D);
const _blue = Color(0xFF216BFF);
const _blueLight = Color(0xFF3C82FF);
const _dim = Color(0x99FFFFFF);

class LocationDisclosureScreen extends StatelessWidget {
  const LocationDisclosureScreen({super.key});

  /// Modal sifatida ochadi. Foydalanuvchi roziligini bildirsa `true`.
  static Future<bool> show(BuildContext context) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const LocationDisclosureScreen(),
        fullscreenDialog: true,
      ),
    );
    return ok ?? false;
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
                  Icons.location_on_rounded,
                  color: _blueLight,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'locationDisclosure.title'.tr(),
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
                'locationDisclosure.subtitle'.tr(),
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
                      icon: Icons.my_location_rounded,
                      title: 'locationDisclosure.doesTitle'.tr(),
                      text: 'locationDisclosure.doesText'.tr(),
                    ),
                    _Bullet(
                      icon: Icons.sync_rounded,
                      title: 'locationDisclosure.alwaysOnTitle'.tr(),
                      text: 'locationDisclosure.alwaysOnText'.tr(),
                    ),
                    _Bullet(
                      icon: Icons.family_restroom_rounded,
                      title: 'locationDisclosure.privacyTitle'.tr(),
                      text: 'locationDisclosure.privacyText'.tr(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _PrimaryButton(
                label: 'locationDisclosure.accept'.tr(),
                onTap: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                child: Text(
                  'locationDisclosure.decline'.tr(),
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
