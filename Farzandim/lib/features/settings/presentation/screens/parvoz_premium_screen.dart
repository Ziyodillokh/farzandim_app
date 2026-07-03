// "Parvoz Premium" — obuna (paywall) sahifasi. Tizim so'zlamalari
// sahifasidagi premium banner "Batafsil" tugmasidan ochiladi.
//
// Dizayn (Figma Make) 1:1: ko'k→qora diagonal fon + tepadan tushuvchi
// nur (god-ray) porlashi, "+1k obunachi" badge (3 memoji avatar), katta
// "Parvoz Premium" sarlavha, "Afzalliklar" shisha kartasi (4 qator) va
// pastda "$5/oy" ko'k CTA tugma.
//
// Eslatma: hozircha xarid tizimi (in-app purchase) ulanmagan — CTA
// "tez kunda" toast ko'rsatadi. Real to'lov keyin ulanadi.

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _bg = Color(0xFF00060A);
const _bgTop = Color(0xFF034470); // fon gradient tepasi (chuqur ko'k)
const _blue = Color(0xFF216BFF); // brend ko'k (badge, CTA)
const _rayCore = Color(0xFF1859FF); // nur o'zagi
const _rayHalo = Color(0xFF5D8BFF); // nur halosi
const _icon = Color(0xFFF9F9F9); // ikon/near-white
const _footerGrey = Color(0xFFA6A8A9);
const _glass = Color(0x1AFFFFFF); // oq 10% (shisha karta)
const _divider = Color(0x4DFFFFFF); // oq 30% (ajratgich)

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.5,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.3,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// Parvoz Premium (paywall) ekrani.
class ParvozPremiumScreen extends StatelessWidget {
  /// `ParvozPremiumScreen` konstruktor.
  const ParvozPremiumScreen({super.key});

  void _subscribe(BuildContext context) {
    AppToast.info(context, 'premium.comingSoon'.tr());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          SafeArea(
            child: Column(
              children: [
                // Tepa qator — o'ngda yopish (x) tugmasi.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _CloseButton(
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        const _SubscribersBadge(),
                        const SizedBox(height: 16),
                        Text(
                          'premium.title'.tr(),
                          textAlign: TextAlign.center,
                          style: _unb(32, ls: -1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'premium.subtitle'.tr(),
                          textAlign: TextAlign.center,
                          style: _pop(
                            14,
                            c: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 26),
                        const _BenefitsCard(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                // Pastdagi CTA + izoh.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  child: Column(
                    children: [
                      _SubscribeButton(onTap: () => _subscribe(context)),
                      const SizedBox(height: 12),
                      Text(
                        'premium.footer'.tr(),
                        textAlign: TextAlign.center,
                        style: _pop(12, w: FontWeight.w500, c: _footerGrey),
                      ),
                    ],
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

// ════════════ Fon: gradient + god-ray porlash ════════════
class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Asosiy diagonal fon: chuqur ko'k (tepa-chap) → qora (past-o'ng).
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bgTop, _bg],
          stops: [0, 0.93],
        ),
      ),
      child: Stack(
        children: [
          // Tepa-markazda umumiy porlash (nurlar manbai).
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.95),
                  radius: 1.05,
                  colors: [
                    Color(0x8C1859FF), // ko'k 55%
                    Color(0x405D8BFF), // periwinkle 25%
                    Colors.transparent,
                  ],
                  stops: [0, 0.4, 1],
                ),
              ),
            ),
          ),
          // Bir nechta xira aylantirilgan nur "pichoq"lari.
          _ray(angleDeg: -13, opacity: 0.55, width: 120),
          _ray(angleDeg: -4, opacity: 0.7, width: 130),
          _ray(angleDeg: 6, opacity: 0.45, width: 110),
          _ray(angleDeg: 15, opacity: 0.4, width: 100),
        ],
      ),
    );
  }

  /// Bitta xira nur pichog'i — tepa-markazdan ma'lum burchakda tushadi.
  Widget _ray({
    required double angleDeg,
    required double opacity,
    required double width,
  }) {
    return Positioned.fill(
      child: Transform.translate(
        offset: const Offset(0, -140), // manba ekran tepasidan yuqorida
        child: Transform.rotate(
          angle: angleDeg * math.pi / 180,
          alignment: Alignment.topCenter,
          child: Align(
            alignment: Alignment.topCenter,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: Container(
                width: width,
                height: 560,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _rayCore.withValues(alpha: opacity),
                      _rayHalo.withValues(alpha: opacity * 0.5),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════ Yopish (x) tugmasi ════════════
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Opacity(
            opacity: 0.35,
            child: Icon(SolarIconsBold.closeCircle, size: 30, color: _icon),
          ),
        ),
      ),
    );
  }
}

// ════════════ "+1k obunachi" badge ════════════
class _SubscribersBadge extends StatelessWidget {
  const _SubscribersBadge();

  static const _avatars = [
    'assets/images/premium/premium_avatar_14.png',
    'assets/images/premium/premium_avatar_15.png',
    'assets/images/premium/premium_avatar_16.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20 + 2 * (20 - 7.7),
            height: 20,
            child: Stack(
              children: [
                for (var i = 0; i < _avatars.length; i++)
                  Positioned(
                    left: i * (20 - 7.7),
                    child: _Avatar(asset: _avatars[i]),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('premium.subscribers'.tr(), style: _pop(14, w: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF21262A),
        border: Border.all(color: _blue, width: 1.2),
        image: DecorationImage(image: AssetImage(asset), fit: BoxFit.cover),
      ),
    );
  }
}

// ════════════ "Afzalliklar" shisha kartasi ════════════
class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard();

  static const _benefits = [
    (SolarIconsBold.usersGroupTwoRounded, 'premium.benefit1'),
    (SolarIconsBold.smartphone, 'premium.benefit2'),
    (SolarIconsBold.handHeart, 'premium.benefit3'),
    (SolarIconsBold.chatRound, 'premium.benefit4'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _glass,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('premium.benefitsTitle'.tr(), style: _unb(20, ls: -0.6)),
          const SizedBox(height: 20),
          for (var i = 0; i < _benefits.length; i++) ...[
            _BenefitRow(icon: _benefits[i].$1, textKey: _benefits[i].$2),
            if (i != _benefits.length - 1) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: _divider),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.textKey});

  final IconData icon;
  final String textKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 24, color: _icon),
        const SizedBox(width: 10),
        Expanded(
          child: Text(textKey.tr(), style: _pop(16, w: FontWeight.w500)),
        ),
      ],
    );
  }
}

// ════════════ "Premiumga ulanish $5/oy" CTA ════════════
class _SubscribeButton extends StatelessWidget {
  const _SubscribeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(60),
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Asos: to'liq ko'k (Positioned.fill — aks holda 0 o'lcham).
              const Positioned.fill(child: ColoredBox(color: _blue)),
              // Diagonal oq yaltiroq (sheen) — o'rtadan o'tadi.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1, -0.6),
                    end: Alignment(1, 0.6),
                    colors: [
                      Colors.transparent,
                      Color(0x80FFFFFF), // oq 50%
                      Colors.transparent,
                    ],
                    stops: [0.16, 0.53, 0.96],
                  ),
                ),
                child: SizedBox.expand(),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('premium.cta'.tr(), style: _pop(16, w: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Text(
                    'premium.price'.tr(),
                    style: _pop(16, w: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
