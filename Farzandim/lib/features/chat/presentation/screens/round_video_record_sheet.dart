// ─────────────────────────────────────────────────────────────────────
// round_video_record_sheet — Dumaloq video yozish oynasi (haqiqiy kamera)
// ─────────────────────────────────────────────────────────────────────
//
// Chat detalidagi kamera bosilganda ochiladi. Jonli kamera preview (dumaloq)
// + aylanuvchi progress halqa + taymer, pastda: bekor / Yuborish / (kamera).
// Web: brauzer MediaRecorder; telefon: camera paketi (VideoCapture).

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/chat/data/video/video_capture.dart';
import 'package:farzandim/features/chat/data/video/video_capture_factory.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _blue = Color(0xFF216BFF);
const _chipBg = Color(0xFF1B2128);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.2);

/// Yozib olingan video natijasi.
class RecordedVideo {
  /// `RecordedVideo` konstruktor.
  const RecordedVideo(this.url, this.seconds);

  /// Manba (web: blob URL, qurilma: fayl yo'li).
  final String url;

  /// Davomiylik (soniya).
  final int seconds;
}

/// Dumaloq video yozish oynasini ochadi. "Yuborish" bosilsa `RecordedVideo`,
/// bekor qilinsa `null` qaytadi.
Future<RecordedVideo?> showRoundVideoRecord(BuildContext context) {
  return showGeneralDialog<RecordedVideo>(
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
  final VideoCapture _capture = createVideoCapture();
  Timer? _timer;
  int _ms = 0;
  bool _ready = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    try {
      await _capture.init();
      await _capture.start();
      if (!mounted) return;
      setState(() => _ready = true);
      _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (!mounted) return;
        setState(() => _ms += 50);
        if (_ms >= _maxMs) _send(); // 30 sek — avtomatik yuborish
      });
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, 'chat.cameraDenied'.tr());
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _capture.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_finishing) return;
    _finishing = true;
    _timer?.cancel();
    final secs = (_ms / 1000).round();
    final url = await _capture.stop();
    if (!mounted) return;
    Navigator.of(context).pop(
      url == null ? null : RecordedVideo(url, secs < 1 ? 1 : secs),
    );
  }

  Future<void> _cancel() async {
    if (_finishing) return;
    _finishing = true;
    _timer?.cancel();
    await _capture.cancel();
    if (mounted) Navigator.of(context).pop();
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
                  ClipOval(
                    child: SizedBox(
                      width: 258,
                      height: 258,
                      child: _ready
                          ? _capture.preview()
                          : const ColoredBox(
                              color: Color(0xFF2A3340),
                              child: Center(
                                child: SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.6,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleButton(icon: Icons.close_rounded, onTap: _cancel),
                  _SendButton(onTap: _send),
                  const _CircleButton(
                    icon: Icons.cameraswitch_rounded,
                    onTap: null,
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(color: _chipBg, shape: BoxShape.circle),
        child: Icon(
          icon,
          size: 24,
          color: onTap == null ? Colors.white54 : Colors.white,
        ),
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
