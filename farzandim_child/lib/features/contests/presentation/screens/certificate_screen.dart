// ─────────────────────────────────────────────────────────────────────
// CertificateScreen — olimpiada sertifikati (ko'rish + saqlash/ulashish) (#56)
// ─────────────────────────────────────────────────────────────────────
//
// Sertifikat widget sifatida render qilinadi (RepaintBoundary), so'ng PNG
// rasm sifatida tortib olinib `share_plus` orqali ulashiladi/saqlanadi.
// Privacy: bola nick (to'liq ism emas) ko'rsatiladi.
//
// Dizayn: "Parvoz Premium" — deep navy sertifikat kartasi, gold #FFC83D
// aksent + aqua #22D3EE glow. Karta o'zi (RepaintBoundary ichi) qat'iy
// (non-adaptive) palitra — PNG har doim premium chiqishi uchun. Ekran
// chrome (Scaffold/AppBar/tugma) esa CP adaptiv palitradan foydalanadi.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/contests/data/repositories/certificate_repository.dart';
import 'package:farzandim_child/features/contests/presentation/contests_theme.dart';
import 'package:farzandim_child/shared/widgets/parvoz_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ── Sertifikat kartasi qat'iy palitrasi (PNG uchun, theme'dan mustaqil) ──
const _kCertBgTop = Color(0xFF0B1C30); // deep navy
const _kCertBgBottom = Color(0xFF132A45);
const _kCertCard = Color(0xFF16293E);
const _kGold = Color(0xFFFFC83D);
const _kGoldSoft = Color(0xFFFFE08A);
const _kAqua = Color(0xFF22D3EE);
const _kAquaSoft = Color(0xFF8AEBFF);
const _kInk = Color(0xFFEAF1F2);
const _kMuted = Color(0xFFA7B7BD);
const _kFaint = Color(0xFF6E8090);

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
    'yanvar',
    'fevral',
    'mart',
    'aprel',
    'may',
    'iyun',
    'iyul',
    'avgust',
    'sentabr',
    'oktabr',
    'noyabr',
    'dekabr',
  ];

  String get _dateText {
    final d = widget.data.date;
    return '${d.day}-${_months[d.month - 1]}, ${d.year}';
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject()
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
    final pv = context.adaptive;
    return Scaffold(
      backgroundColor: pv.pvBg,
      body: Column(
        children: [
          ParvozHeader(title: 'Sertifikat', onBack: () => context.pop()),
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
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: _ShareButton(
              sharing: _sharing,
              onTap: _sharing ? null : _share,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aqua "Saqlash / Ulashish" tugmasi — glow bilan.
class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.sharing, this.onTap});

  final bool sharing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pv = context.adaptive;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: pv.pvGreen,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: pv.pvGreen.withValues(alpha: 0.40),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (sharing)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(pv.pvOnGreen),
                ),
              )
            else
              Icon(Icons.ios_share_rounded, size: 20, color: pv.pvOnGreen),
            const SizedBox(width: 10),
            Text(
              sharing ? 'Tayyorlanmoqda…' : 'Saqlash / Ulashish',
              style: cjak(
                CP(pv.isDark),
                size: 16,
                weight: FontWeight.w800,
                color: pv.pvOnGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tortib olinadigan (PNG) sertifikat dizayni — qat'iy premium palitra.
class _Certificate extends StatelessWidget {
  const _Certificate({required this.data, required this.dateText});

  final CertificateData data;
  final String dateText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      // Tashqi gold "ramka" — nozik gradient hoshiya.
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kGold, Color(0xFFB7861F), _kGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _kGold.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kCertBgTop, _kCertBgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Stack(
          children: [
            // Yuqorida aqua glow halqasi (dekorativ).
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _kAqua.withValues(alpha: 0.22),
                      _kAqua.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _kGold.withValues(alpha: 0.14),
                      _kGold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Brend ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.flight_takeoff_rounded,
                        color: _kAqua,
                        size: 22,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'PARVOZ',
                        style: cjak(
                          CP(true),
                          size: 18,
                          weight: FontWeight.w900,
                          color: _kAquaSoft,
                          spacing: 3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  // ── Kubok medallioni ──
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _kGold.withValues(alpha: 0.28),
                          _kGold.withValues(alpha: 0.04),
                        ],
                      ),
                      border: Border.all(
                        color: _kGold.withValues(alpha: 0.55),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _kGold.withValues(alpha: 0.35),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: _kGold,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'SERTIFIKAT',
                    style: cjak(
                      CP(true),
                      size: 26,
                      weight: FontWeight.w900,
                      color: _kInk,
                      spacing: 5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Gold ajratuvchi chiziq.
                  Container(
                    width: 64,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kGoldSoft, _kGold],
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Ushbu sertifikat',
                    style: cjak(
                      CP(true),
                      size: 13,
                      weight: FontWeight.w500,
                      color: _kMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.childNick,
                    textAlign: TextAlign.center,
                    style: cjak(
                      CP(true),
                      size: 23,
                      weight: FontWeight.w800,
                      color: _kGold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "“${data.olympiadTitle}” olimpiadasini\nmuvaffaqiyatli "
                    'yakunlagani uchun beriladi',
                    textAlign: TextAlign.center,
                    style: cjak(
                      CP(true),
                      size: 13,
                      weight: FontWeight.w500,
                      color: _kMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  // ── Natija paneli ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _kCertCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kAqua.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Stat(label: 'Natija', value: '${data.percent}%'),
                        const _Divider(),
                        _Stat(label: 'Ball', value: '${data.score}'),
                        const _Divider(),
                        _Stat(label: 'Fan', value: data.subject),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Sana + ID ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: _kFaint,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            dateText,
                            style: cjak(
                              CP(true),
                              size: 11,
                              weight: FontWeight.w500,
                              color: _kFaint,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        data.certificateId,
                        style: cjak(
                          CP(true),
                          size: 10,
                          weight: FontWeight.w500,
                          color: _kFaint.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
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

/// Natija panelidagi vertikal ajratuvchi.
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withValues(alpha: 0.08),
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
          style: cjak(
            CP(true),
            size: 16,
            weight: FontWeight.w800,
            color: _kAquaSoft,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: cjak(
            CP(true),
            size: 10,
            weight: FontWeight.w500,
            color: _kMuted,
          ),
        ),
      ],
    );
  }
}
