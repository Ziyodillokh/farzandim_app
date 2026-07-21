// "Tariflar" — obuna (paywall) sahifasi. Tizim sozlamalari sahifasidagi
// premium banner "Batafsil" tugmasidan ochiladi.
//
// Dizayn (Figma) 1:1: ko'k→qora diagonal fon + tepadan tushuvchi nur
// (god-ray), "+1k obunachi" badge, "Tariflar" sarlavha va 3 ta tarif kartasi:
//   • Start   — Tekin (shisha karta, tugmasiz)
//   • Standart — $5/oy (ko'k karta, oq "Standart ulanish" tugma)
//   • Premium  — $10/oy (to'q karta, ko'k "Premiumga ulanish" tugma)
//
// Eslatma: hozircha xarid tizimi (in-app purchase) ulanmagan — ulanish
// tugmalari "tez kunda" toast ko'rsatadi. Real to'lov keyin ulanadi.

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/settings/data/repositories/backend_payments_repository.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

// ════════════ Tokenlar (lokal) ════════════
const _bg = Color(0xFF00060A);
const _bgTop = Color(0xFF034470); // fon gradient tepasi (chuqur ko'k)
const _blue = Color(0xFF216BFF); // brend ko'k (badge, ko'k karta, CTA)
const _rayCore = Color(0xFF1859FF); // nur o'zagi
const _rayHalo = Color(0xFF5D8BFF); // nur halosi
const _icon = Color(0xFFF9F9F9); // ikon/near-white (yopish tugmasi)
const _ctaDark = Color(0xFF0A1B30); // oq tugmadagi to'q matn (Standart)

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

/// Har tarif kartasida bir xil 4 imkoniyat (ikon + i18n kalit).
const _features = <(IconData, String)>[
  (SolarIconsBold.usersGroupTwoRounded, 'premium.benefit1'),
  (SolarIconsBold.smartphone, 'premium.benefit2'),
  (SolarIconsBold.handHeart, 'premium.benefit3'),
  (SolarIconsBold.chatRound, 'premium.benefit4'),
];

/// Tarif kartasi ko'rinishi.
enum _PlanStyle { glass, blue, dark }

/// Tariflar (paywall) ekrani — HAQIQIY tariflar backend'dan, "Ulanish"
/// tugmasi Click to'lov sahifasini ochadi.
class ParvozPremiumScreen extends ConsumerStatefulWidget {
  /// `ParvozPremiumScreen` konstruktor.
  const ParvozPremiumScreen({super.key});

  @override
  ConsumerState<ParvozPremiumScreen> createState() =>
      _ParvozPremiumScreenState();
}

class _ParvozPremiumScreenState extends ConsumerState<ParvozPremiumScreen> {
  /// Hozir checkout ochilayotgan tarif id (tugmada spinner). `null` — bo'sh.
  String? _busyPlanId;

  /// Tarifni sotib olish: checkout -> Click to'lov sahifasini ochish.
  Future<void> _subscribe(PlanEntry plan) async {
    if (_busyPlanId != null) return;
    setState(() => _busyPlanId = plan.id);
    try {
      final url = await ref
          .read(backendPaymentsRepositoryProvider)
          .checkout(planId: plan.id);
      if (url.isEmpty) throw Exception('empty checkout url');
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception('launch failed');
    } catch (_) {
      if (mounted) AppToast.error(context, 'premium.checkoutError'.tr());
    } finally {
      if (mounted) setState(() => _busyPlanId = null);
    }
  }

  /// Tarif uslubi tier bo'yicha: free -> glass, standard -> blue, aks -> dark.
  _PlanStyle _styleFor(PlanEntry p) {
    if (p.isFree) return _PlanStyle.glass;
    if (p.entitlementTier == 'premium') return _PlanStyle.dark;
    return _PlanStyle.blue;
  }

  /// "29 000 so'm/oy" ko'rinishidagi narx. Bepul bo'lsa i18n "Tekin".
  String _priceLabel(PlanEntry p) {
    if (p.isFree) return 'premium.startPrice'.tr();
    final s = p.priceUzs.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    final suffix = switch (p.period) {
      'yearly' => '/${'premium.perYear'.tr()}',
      'monthly' => '/${'premium.perMonth'.tr()}',
      _ => '',
    };
    return "$b ${'premium.sum'.tr()}$suffix";
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(plansProvider);
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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    child: Column(
                      children: [
                        const Center(child: _SubscribersBadge()),
                        const SizedBox(height: 14),
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
                        const SizedBox(height: 24),
                        plansAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: CircularProgressIndicator(color: _blue),
                          ),
                          error: (_, __) => Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Text(
                              'premium.loadError'.tr(),
                              textAlign: TextAlign.center,
                              style: _pop(
                                14,
                                c: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          data: (res) => _PlansList(
                            plans: res.plans,
                            busyPlanId: _busyPlanId,
                            styleFor: _styleFor,
                            priceLabel: _priceLabel,
                            onSubscribe: _subscribe,
                          ),
                        ),
                      ],
                    ),
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

/// Tariflar ro'yxati — har biri `_PlanCard` (dizayn saqlanadi).
class _PlansList extends StatelessWidget {
  const _PlansList({
    required this.plans,
    required this.busyPlanId,
    required this.styleFor,
    required this.priceLabel,
    required this.onSubscribe,
  });

  final List<PlanEntry> plans;
  final String? busyPlanId;
  final _PlanStyle Function(PlanEntry) styleFor;
  final String Function(PlanEntry) priceLabel;
  final Future<void> Function(PlanEntry) onSubscribe;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < plans.length; i++) ...[
          if (i != 0) const SizedBox(height: 16),
          _PlanCard(
            name: plans[i].name,
            price: priceLabel(plans[i]),
            style: styleFor(plans[i]),
            // Bepul tarifda tugma yo'q (obuna talab qilmaydi).
            ctaLabel: plans[i].isFree ? null : 'premium.subscribeCta'.tr(),
            loading: busyPlanId == plans[i].id,
            onCta: plans[i].isFree ? null : () => onSubscribe(plans[i]),
          ),
        ],
      ],
    );
  }
}

// ════════════ Tarif kartasi ════════════
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.price,
    required this.style,
    this.ctaLabel,
    this.onCta,
    this.loading = false,
  });

  final String name;
  final String price;
  final _PlanStyle style;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final blue = style == _PlanStyle.blue;
    final featureColor = switch (style) {
      _PlanStyle.glass => Colors.white.withValues(alpha: 0.78),
      _PlanStyle.blue => Colors.white,
      _PlanStyle.dark => Colors.white.withValues(alpha: 0.9),
    };
    final dividerColor = blue
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.1);

    final content = Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: _unb(26, ls: -0.8))),
              const SizedBox(width: 12),
              Text(price, style: _unb(19, ls: -0.4)),
            ],
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < _features.length; i++) ...[
            _PlanFeature(
              icon: _features[i].$1,
              textKey: _features[i].$2,
              color: featureColor,
            ),
            if (i != _features.length - 1) ...[
              const SizedBox(height: 12),
              Divider(height: 1, thickness: 1, color: dividerColor),
              const SizedBox(height: 12),
            ],
          ],
          if (ctaLabel != null) ...[
            const SizedBox(height: 20),
            _PlanCta(
              label: ctaLabel!,
              filled: style == _PlanStyle.dark,
              loading: loading,
              onTap: onCta,
            ),
          ],
        ],
      ),
    );

    switch (style) {
      case _PlanStyle.glass:
        // Frosted shisha — ort fondagi god-ray xiralashadi.
        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: content,
            ),
          ),
        );
      case _PlanStyle.blue:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(28),
          ),
          child: content,
        );
      case _PlanStyle.dark:
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF141C28), Color(0xFF0B111A)],
            ),
          ),
          child: content,
        );
    }
  }
}

class _PlanFeature extends StatelessWidget {
  const _PlanFeature({
    required this.icon,
    required this.textKey,
    required this.color,
  });

  final IconData icon;
  final String textKey;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            textKey.tr(),
            style: _pop(15, w: FontWeight.w500, c: color),
          ),
        ),
      ],
    );
  }
}

/// Tarif kartasi tugmasi. `filled` — ko'k fon + oq matn (Premium); aks holda
/// oq fon + to'q matn (Standart).
class _PlanCta extends StatelessWidget {
  const _PlanCta({
    required this.label,
    required this.filled,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : _ctaDark;
    return GestureDetector(
      onTap: loading ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? _blue : Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
              )
            : Text(label, style: _pop(16, w: FontWeight.w600, c: fg)),
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
