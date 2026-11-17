// ─────────────────────────────────────────────────────────────────────
// KelajakDashboardCard — dashboard'dagi Kelajak kartasi (maktabdan keyin)
// ─────────────────────────────────────────────────────────────────────
//
//   - yuklanmoqda / xato / bo'lim mavjud emas / yosh 7–18 dan tashqari
//     va javob yo'q → ko'rinmaydi;
//   - yosh kiritilmagan → "yoshini kiriting";
//   - hali javob yo'q → savollar "Bugungi testlar"da ekani;
//   - ishonchli profil → qiziqish yuqori bo'lgan top yo'nalishlar;
//   - aks holda → testlar soni, profil shakllanmoqda.
// Bosilsa — Kelajak sahifasi. Uslub maktab kartasi bilan bir xil (oq 7%
// fon, oq 10% chegara, r24); ko'rinsagina tepasida 4px oraliq. Ilovaga
// qaytilganda (resume) xulosa qayta so'raladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/utils/app_lifecycle.dart';
import 'package:farzandim/features/kelajak/presentation/kelajak_view_models.dart';
import 'package:farzandim/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ─── Dashboard tokenlari (dashboard_screen.dart bilan bir xil) ───
const Color _cardBg = Color(0x12FFFFFF); // oq ~7%
const Color _cardBorder = Color(0x1AFFFFFF); // oq ~10%
const Color _dim = Color(0x8CFFFFFF); // oq 55%
const double _radius = 24;

TextStyle _unb(double size) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  letterSpacing: -0.5,
  height: 1.4,
);

TextStyle _pop(double size) =>
    GoogleFonts.poppins(fontSize: size, color: _dim, height: 1.5);

/// Dashboard pull-to-refresh: [childId] xulosasini qayta so'raydi.
void refreshKelajakCard(WidgetRef ref, String childId) =>
    ref.invalidate(kelajakSummaryProvider(childId));

/// Dashboard Kelajak kartasi ([childId] — tanlangan farzand).
class KelajakDashboardCard extends ConsumerWidget {
  const KelajakDashboardCard({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(appLifecycleProvider, (previous, next) {
      if (next == AppLifecycleState.resumed && previous != next) {
        refreshKelajakCard(ref, childId);
      }
    });
    final summary = ref.watch(kelajakSummaryProvider(childId)).valueOrNull;
    final subtitle = switch (KelajakCardMode.of(summary)) {
      KelajakCardHidden() => null,
      KelajakCardAgeRequired() => 'kelajak.card.ageRequired'.tr(),
      KelajakCardEmpty() => 'kelajak.card.empty'.tr(),
      KelajakCardForming(:final sessions) => 'kelajak.card.forming'.tr(
        namedArgs: {'count': '$sessions'},
      ),
      KelajakCardInterests(:final names) => 'kelajak.card.interests'.tr(
        namedArgs: {
          'names': [for (final n in names) kelajakText(context, n)].join(', '),
        },
      ),
    };
    if (subtitle == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: _CardShell(
        onTap: () => context.push(AppRoutes.kelajakPath(childId)),
        child: Row(
          children: [
            const Icon(SolarIconsBold.compass, size: 26, color: _dim),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'kelajak.card.title'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _unb(16),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _pop(14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              SolarIconsBold.altArrowRight,
              size: 22,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashboard `_Card` nusxasi: flat shisha + ripple.
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(_radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: br,
        border: Border.all(color: _cardBorder),
      ),
      child: ClipRRect(
        borderRadius: br,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: br,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
