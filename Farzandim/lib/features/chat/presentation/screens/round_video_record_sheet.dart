// ─────────────────────────────────────────────────────────────────────
// round_video_record_sheet — Dumaloq video yozish oynasi (preview)
// ─────────────────────────────────────────────────────────────────────
//
// Chat detalidagi kamera bosilganda ochiladi. To'liq ekran qora fon,
// markazda dumaloq kamera preview (bu yerda placeholder) + aylanuvchi
// progress halqa + taymer, pastda: bekor / Yuborish / kamerani almashtirish.
//
// ⚠️ Bu PREVIEW — haqiqiy kamera yozuvi `voice_message` feature'idagi
// `round_video_recorder.dart`'da (camera + video_compress).

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

const _blue = Color(0xFF216BFF);
const _chipBg = Color(0xFF1B2128);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.2);

/// Dumaloq video yozish oynasini ochadi (preview).
///
/// "Yuborish" bosilsa yozib olingan davomiylik (soniya) qaytadi; bekor
/// qilinsa `null`.
Future<int?> showRoundVideoRecord(BuildContext context) {
  return showGeneralDialog<int>(
    context: context,
    barrierColor: const Color(0xF2000000), // qora ~95%
    barrierLabel: 'record',
    pageBuilder: (_, __, ___) => const _RecordOverlay(),
    transitionBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

class _RecordOverlay extends StatefulWidget {
  const _RecordOverlay();

  @override
  State<_RecordOverlay> createState() => _RecordOverlayState();
}

class _RecordOverlayState extends State<_RecordOverlay> {
  static const int _maxMs = 30000; // progress halqa to'lish vaqti
  Timer? _timer;
  int _ms = 0;

  @override
  void initState() {
    super.initState();
    // Preview: taymer avtomatik yuradi (haqiqiy yozuv o'rniga).
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() => _ms += 50);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formatted {
    final m = (_ms ~/ 60000).toString().padLeft(2, '0');
    final s = ((_ms ~/ 1000) % 60).toString().padLeft(2, '0');
    final cc = ((_ms ~/ 10) % 100).toString().padLeft(2, '0');
    return '$m:$s.$cc';
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_ms / _maxMs).clamp(0.0, 1.0);
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // ── Dumaloq preview + progress halqa ──
            SizedBox(
              width: 276,
              height: 276,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 276,
                    height: 276,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor: const Color(0x22FFFFFF),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  Container(
                    width: 258,
                    height: 258,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2A3340), _chipBg],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        SolarIconsBold.videocameraRecord,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            // ── Taymer pill ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 10, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(_formatted, style: _pop(14, w: FontWeight.w600)),
                ],
              ),
            ),
            const Spacer(),
            // ── Boshqaruv tugmalari ──
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _SendButton(
                    onTap: () => Navigator.of(context).pop(_ms ~/ 1000),
                  ),
                  _CircleButton(
                    icon: Icons.cameraswitch_rounded,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

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
        decoration: const BoxDecoration(color: _chipBg, shape: BoxShape.circle),
        child: Icon(icon, size: 24, color: Colors.white),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('chat.send'.tr(), style: _pop(15, w: FontWeight.w600)),
      ),
    );
  }
}
