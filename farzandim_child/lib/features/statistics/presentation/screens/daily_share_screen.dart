// ─────────────────────────────────────────────────────────────────────
// DailyShareScreen — bugungi rivojlanishni (qadam / DON / streak) chiroyli
// kartochka sifatida ulashish (share_plus). Sertifikat ekranidagi
// RepaintBoundary → PNG → Share.shareXFiles patterni asosida.
// ─────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';

// PNG'da chiroyli chiqishi uchun qat'iy (temadan mustaqil) premium palitra —
// shaffof/glass kartalar rasmga aylanganda xunuk chiqadi.
const _cardTop = Color(0xFF0E1730);
const _cardBottom = Color(0xFF060B18);
const _blue = Color(0xFF216BFF);
const _gold = Color(0xFFF5C451);
const _dim = Color(0xB3FFFFFF);
const _line = Color(0x1FFFFFFF);

TextStyle _pop(double s, {FontWeight w = FontWeight.w400, Color c = Colors.white}) =>
    GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.2);

class DailyShareScreen extends ConsumerStatefulWidget {
  const DailyShareScreen({super.key});

  @override
  ConsumerState<DailyShareScreen> createState() => _DailyShareScreenState();
}

class _DailyShareScreenState extends ConsumerState<DailyShareScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _sharing = false;

  static const _months = [
    'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
    'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
  ];

  String get _dateText {
    final d = DateTime.now();
    return '${d.day}-${_months[d.month - 1]}, ${d.year}';
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/parvoz-kunlik-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'statistics.shareText'.tr(),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('contests.shareFailed'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(pairingStateProvider).childName ?? 'Farzand';
    final backend = ref.watch(backendGamificationProvider).valueOrNull;
    final steps = ref.watch(todayStepsProvider).valueOrNull ?? 0;
    final don = backend?.don ?? 0;
    final streak = backend?.streak ?? 0;

    return Scaffold(
      backgroundColor: _cardBottom,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text('statistics.shareTitle'.tr(), style: _pop(17, w: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: _DailyCard(
                    name: name,
                    dateText: _dateText,
                    steps: steps,
                    don: don,
                    streak: streak,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20, 4, 20, 20 + MediaQuery.paddingOf(context).bottom,
            ),
            child: _ShareButton(sharing: _sharing, onTap: _sharing ? null : _share),
          ),
        ],
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.name,
    required this.dateText,
    required this.steps,
    required this.don,
    required this.streak,
  });

  final String name;
  final String dateText;
  final int steps;
  final int don;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cardTop, _cardBottom],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Brend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.rocket_launch_rounded, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 9),
              Text('Parvoz', style: _pop(20, w: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 20),
          Text('statistics.shareCardTitle'.tr(), style: _pop(13, c: _gold, w: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(name, style: _pop(24, w: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(dateText, style: _pop(12.5, c: _dim)),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _Stat(value: _fmt(steps), label: 'statistics.shareSteps'.tr(), color: _blue)),
              const SizedBox(width: 10),
              Expanded(child: _Stat(value: _fmt(don), label: 'DON', color: _gold)),
              const SizedBox(width: 10),
              Expanded(child: _Stat(value: '$streak', label: 'statistics.shareStreak'.tr(), color: const Color(0xFF34D399))),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: _line),
          const SizedBox(height: 14),
          Text(
            'statistics.shareTagline'.tr(),
            style: _pop(12.5, c: _dim),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1424).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Text(value, style: _pop(20, w: FontWeight.w700, c: color)),
          const SizedBox(height: 5),
          Text(
            label,
            style: _pop(11, c: _dim),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.sharing, this.onTap});

  final bool sharing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _blue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: sharing
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.ios_share_rounded, size: 20, color: Colors.white),
                  const SizedBox(width: 9),
                  Text('statistics.shareButton'.tr(), style: _pop(16, w: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}
