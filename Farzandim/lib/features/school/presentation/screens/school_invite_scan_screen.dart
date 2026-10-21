// Maktab taklifi QR skaneri (`scan_account_screen` naqshi, Parvoz uslubida).
// Panel QR'i `https://parvoz.uz/link?code=XXXXXXXX` ni kodlaydi; xom kod
// ham qabul qilinadi. Topilgan kod chaqiruvchiga qaytariladi
// (`Navigator.pop(code)`); begona QR'da xabar chiqadi va skaner ishlashda
// davom etadi. Kamera ruxsatini mobile_scanner o'zi so'raydi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/invite_code.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:solar_icons/solar_icons.dart';

const _blue = Color(0xFF216BFF);
const _danger = Color(0xFFFF5A5D);

/// QR skaner; kod topilsa `String` (normallashtirilgan) bilan yopiladi.
class SchoolInviteScanScreen extends StatefulWidget {
  const SchoolInviteScanScreen({super.key});

  @override
  State<SchoolInviteScanScreen> createState() => _SchoolInviteScanScreenState();
}

class _SchoolInviteScanScreenState extends State<SchoolInviteScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Kod topildi — qayta ishlanmaydi (bir kadrda bir nechta barcode).
  bool _handled = false;
  bool _invalid = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      final code = raw == null ? null : InviteCode.fromScan(raw);
      if (code == null) continue;
      _handled = true;
      Navigator.of(context).pop(code);
      return;
    }
    if (!_invalid) setState(() => _invalid = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => const _CameraError(),
          ),
          // Skaner ramkasi.
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: _blue, width: 3),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          // Tepada: orqaga + sarlavha.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  ParvozBackButton(onTap: () => Navigator.of(context).pop()),
                  Expanded(
                    child: Text(
                      'school.link.scanTitle'.tr(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.unbounded(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
          ),
          // Pastda: yo'riqnoma + begona QR xabari.
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_invalid)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _danger.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'school.link.invalidQr'.tr(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Text(
                      'school.link.scanHint'.tr(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kamera ochilmasa / ruxsat berilmasa — kodni qo'lda kiritishga undash.
class _CameraError extends StatelessWidget {
  const _CameraError();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                SolarIconsBold.cameraRotate,
                color: Colors.white54,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                'school.link.cameraError'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
