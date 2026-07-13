// ─────────────────────────────────────────────────────────────────────
// AddressesSetupScreen — "Bolangiz manzillarini kiriting" (wizard 3-qadam)
// ─────────────────────────────────────────────────────────────────────
//
// Onboarding wizardning 3-qadami (controls-setup'dan keyin, oila kodidan
// oldin). Bola tez-tez boradigan manzillarni (geo-zonalar) qo'shadi.
// "+ Manzil qo'shish" → mavjud "Yangi manzil" (AddEditGeoZoneScreen).
// Qo'shilgan zonalar ro'yxat sifatida (tap → tahrirlash). "Tayyor" →
// oila kodi (pairing).
//
// Ma'lumot: `geoZonesProvider(childId)` real zonalar; ikon
// `GeoZone.iconFromString`.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/geo_zones/data/models/geo_zone.dart';
import 'package:farzandim/features/geo_zones/presentation/providers/geo_zones_provider.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar (lokal) ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _chipBg = Color(0xFF1B2128);
const _card = Color(0xFF12171E);
const _stepInactive = Color(0xFF1B2128);
const _fieldBorder = Color(0x1FFFFFFF); // oq 12%
const _line = Color(0x1AFFFFFF); // qadam chizig'i (oq 10%)
const _dim = Color(0x8CFFFFFF); // oq 55%

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
  height: 1.25,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// Manzillar (geo-zonalar) wizard qadami.
class AddressesSetupScreen extends ConsumerWidget {
  /// `AddressesSetupScreen` konstruktor.
  const AddressesSetupScreen({
    required this.childId,
    this.initialChild,
    super.key,
  });

  /// Bola id'si (marshrut path parametri).
  final String childId;

  /// `state.extra` orqali kelgan Child — provider race'ni chetlash uchun.
  final Child? initialChild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones =
        ref.watch(geoZonesProvider(childId)).valueOrNull ?? const <GeoZone>[];

    final scaffold = Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned(
            top: -70,
            left: 0,
            right: 0,
            child: IgnorePointer(child: Center(child: _Glow())),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        const _StepIndicator(),
                        const SizedBox(height: 32),
                        Text(
                          'addressesSetup.title'.tr(),
                          maxLines: 2,
                          style: _unb(28),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'addressesSetup.subtitle'.tr(),
                          style: _pop(14, c: _dim),
                        ),
                        const SizedBox(height: 28),
                        _AddAddressButton(
                          onTap: () =>
                              context.push(AppRoutes.geoZonesAddPath(childId)),
                        ),
                        const SizedBox(height: 16),
                        for (final z in zones) ...[
                          _ZoneCard(
                            zone: z,
                            onTap: () => context.push(
                              AppRoutes.geoZonesEditPath(childId, z.id),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: _TayyorButton(
                    // Eski "oila kodi" sahifasi olib tashlandi — kod bola
                    // qo'shilganda Parvoz "ulash" oynasida ko'rsatiladi.
                    onTap: () => context.go(AppRoutes.dashboard),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Wizard qadami — orqaga tugmasi yo'q; apparat "orqa" ilovadan
    // chiqarmasligi uchun dashboard'ga qaytaramiz (go() stack'ni bo'shatadi).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.dashboard);
      },
      child: scaffold,
    );
  }
}

// ════════════ Fon yog'dusi ════════════

class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      height: 280,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [_blue.withValues(alpha: 0.22), const Color(0x00216BFF)],
          stops: const [0, 0.7],
        ),
      ),
    );
  }
}

// ════════════ Qadam indikatori (3-qadam faol) ════════════

class _StepIndicator extends StatelessWidget {
  const _StepIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _StepCircle(icon: SolarIconsBold.peopleNearby),
        _StepLine(),
        _StepCircle(icon: SolarIconsBold.clipboardCheck),
        _StepLine(),
        _StepCircle(icon: SolarIconsBold.map, active: true),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({required this.icon, this.active = false});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? _blue : _stepInactive,
        border: active ? null : Border.all(color: _fieldBorder),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _blue.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        size: 24,
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.75),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine();

  @override
  Widget build(BuildContext context) {
    return const Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: SizedBox(height: 2, child: ColoredBox(color: _line)),
      ),
    );
  }
}

// ════════════ "+ Manzil qo'shish" tugmasi ════════════

class _AddAddressButton extends StatelessWidget {
  const _AddAddressButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ParvozGlass(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 20, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              'addressesSetup.addAddress'.tr(),
              style: _pop(16, w: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════ Zona kartasi ════════════

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zone, required this.onTap});

  final GeoZone zone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconKey = zone.icon ?? zone.type.defaultIconName;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _fieldBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _chipBg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                GeoZone.iconFromString(iconKey),
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                zone.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _unb(16, ls: -0.3),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(SolarIconsOutline.altArrowRight, size: 20, color: _dim),
          ],
        ),
      ),
    );
  }
}

// ════════════ Tayyor tugmasi ════════════

class _TayyorButton extends StatelessWidget {
  const _TayyorButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ParvozGlass(
        blue: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'addressesSetup.done'.tr(),
              style: _pop(16, w: FontWeight.w500),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.check_rounded, size: 20, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
