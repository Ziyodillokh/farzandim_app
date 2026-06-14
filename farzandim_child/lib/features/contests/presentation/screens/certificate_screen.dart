// ─────────────────────────────────────────────────────────────────────
// CertificateScreen — olimpiada sertifikati (ko'rish + saqlash/ulashish) (#56)
// ─────────────────────────────────────────────────────────────────────
//
// Sertifikat widget sifatida render qilinadi (RepaintBoundary), so'ng PNG
// rasm sifatida tortib olinib `share_plus` orqali ulashiladi/saqlanadi.
// Privacy: bola nick (to'liq ism emas) ko'rsatiladi.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/contests/data/repositories/certificate_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CertificateScreen extends StatefulWidget {
  const CertificateScreen({required this.data, super.key});

  final CertificateData data;

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _sharing = false;

  static const _months = [
    'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
    'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
  ];

  String get _dateText {
    final d = widget.data.date;
    return '${d.day}-${_months[d.month - 1]}, ${d.year}';
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/parvoz-sertifikat-${widget.data.certificateId}.png',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            "Men Parvoz ilovasida '${widget.data.olympiadTitle}' "
            'olimpiadasida sertifikat oldim! 🏆',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ulashib bo\'lmadi. Qayta urining.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Sertifikat',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: _Certificate(data: widget.data, dateText: _dateText),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sharing ? null : _share,
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_rounded, size: 20),
                label: Text(_sharing ? 'Tayyorlanmoqda…' : 'Saqlash / Ulashish'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tortib olinadigan (PNG) sertifikat dizayni.
class _Certificate extends StatelessWidget {
  const _Certificate({required this.data, required this.dateText});

  final CertificateData data;
  final String dateText;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    return Container(
      width: 340,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF235347), Color(0xFF2F6B5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: gold, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Brend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.flight_takeoff_rounded,
                    color: Color(0xFF235347), size: 22),
                const SizedBox(width: 6),
                Text(
                  'PARVOZ',
                  style: TextStyle(
                    color: const Color(0xFF235347),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Icon(Icons.emoji_events_rounded, color: gold, size: 56),
            const SizedBox(height: 12),
            const Text(
              'SERTIFIKAT',
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 4),
            Container(width: 60, height: 3, color: gold),
            const SizedBox(height: 20),
            const Text(
              'Ushbu sertifikat',
              style: TextStyle(color: Color(0xFF6B6B78), fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              data.childNick,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "“${data.olympiadTitle}” olimpiadasini\nmuvaffaqiyatli "
              'yakunlagani uchun beriladi',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF4A4A4A),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            // Natija
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(label: 'Natija', value: '${data.percent}%'),
                  Container(width: 1, height: 28, color: const Color(0xFFE0E0E0)),
                  _Stat(label: 'Ball', value: '${data.score}'),
                  Container(width: 1, height: 28, color: const Color(0xFFE0E0E0)),
                  _Stat(label: 'Fan', value: data.subject),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateText,
                  style:
                      const TextStyle(color: Color(0xFF6B6B78), fontSize: 11),
                ),
                Text(
                  data.certificateId,
                  style:
                      const TextStyle(color: Color(0xFF9999A8), fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF235347),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF6B6B78), fontSize: 10),
        ),
      ],
    );
  }
}
