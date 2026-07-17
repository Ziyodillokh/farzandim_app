// Ota-ona "joylashuvni yoqing" so'rovi kelganda (FCM type: location_request)
// bolada chiqadigan modal. "Yoqish" bosilsa ruxsat so'raladi va/yoki tizim
// joylashuv sozlamasi ochiladi (Android'da ilova GPS'ni o'zi yoqolmaydi).

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

class LocationEnableModal extends StatelessWidget {
  const LocationEnableModal({super.key});

  static const _pBlue = Color(0xFF216BFF);
  static const _pSheetBg = Color(0xFF15181E);
  static const _pDim = Color(0x8CFFFFFF);

  /// Modalni ko'rsatadi. Bir vaqtda bittadan ortiq chiqmasin — chaqiruvchi
  /// (fcm_provider) `rootNavigator` konteksti bilan chaqiradi.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const LocationEnableModal(),
    );
  }

  /// "Yoqish" — ruxsatni so'raydi, so'ng kerak bo'lsa tizim sozlamasini ochadi.
  ///
  /// Android'da ilova GPS'ni to'g'ridan yoqa olmaydi — faqat foydalanuvchini
  /// sozlamaga yo'naltiradi.
  Future<void> _enable(BuildContext context) async {
    Navigator.of(context).pop();
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      // Doimiy rad — ilova sozlamasi (ruxsatni qo'lda yoqish).
      await Geolocator.openAppSettings();
      return;
    }
    // Ruxsat bor, lekin GPS xizmati o'chiq bo'lishi mumkin — sozlamani ochamiz.
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _pSheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tortish dastagi.
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 26),
              // Ko'k porlash + joylashuv ikonasi.
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _pBlue.withValues(alpha: 0.16),
                  border: Border.all(color: _pBlue.withValues(alpha: 0.35)),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF3C82FF),
                  size: 34,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Ota-onangiz joylashuvni yoqishingizni so\'rayapti',
                textAlign: TextAlign.center,
                style: GoogleFonts.unbounded(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.4,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Joylashuvni yoqsangiz ota-onangiz sizni xaritada '
                'ko\'ra oladi va xavfsizligingizni bilib turadi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: _pDim,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              // Yoqish tugmasi.
              SizedBox(
                width: double.infinity,
                height: 54,
                child: Material(
                  color: _pBlue,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _enable(context),
                    child: Center(
                      child: Text(
                        'Yoqish',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Keyinroq',
                  style: GoogleFonts.poppins(fontSize: 14, color: _pDim),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
