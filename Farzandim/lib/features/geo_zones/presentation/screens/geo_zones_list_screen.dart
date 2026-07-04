import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/geo_zones/data/models/geo_zone.dart';
import 'package:farzandim/features/geo_zones/presentation/providers/geo_zone_event_providers.dart';
import 'package:farzandim/features/geo_zones/presentation/providers/geo_zones_provider.dart';
import 'package:farzandim/features/geo_zones/presentation/screens/geo_zone_events_screen.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:farzandim/shared/widgets/skeleton_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

// ─── "Manzillar" dizayn tokenlari (Figma 3-rasm) ───
const Color _bg = Color(0xFF0B0B10); // qora fon
const Color _cardBg = Color(0xFF1A1B22); // qoramtir karta (1-rasmga mos)
const Color _cardBorder = Color(0x14FFFFFF); // oq ~8% chegara
const Color _iconSquare = Color(0xFF2A2C36); // to'q ikon kvadrati (chip)
const Color _dim = Color(0x99FFFFFF); // oq 60% ikkilamchi matn
const Color _glassBtn = Color(0xE6121C2E); // top-bar tugma foni

/// Bola uchun barcha geo-zonalari real-time ro'yxati ("Manzillar" dizayn).
///
/// - **Empty state**: markazda hint + qo'shish tugmasi.
/// - **List state**: qora fon, oq-kvadrat ikonli kartalar, top-bar'da ➕.
///
/// Karta bossa edit ekraniga ko'chadi (`/geo-zones/:childId/edit/:id`).
class GeoZonesListScreen extends ConsumerWidget {
  /// `GeoZonesListScreen` konstruktor.
  const GeoZonesListScreen({required this.childId, super.key});

  /// Qaysi bola uchun zonalar ko'rsatiladi.
  final String childId;

  void _openEvents(BuildContext context, String childName) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            GeoZoneEventsScreen(childId: childId, childName: childName),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(geoZonesProvider(childId));
    final child = ref.watch(childByIdProvider(childId));
    final childName = child?.name ?? 'geoZones.fallbackChildName'.tr();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              childId: childId,
              onHistoryTap: () => _openEvents(context, childName),
            ),
            _Last24HoursCard(
              childId: childId,
              onTap: () => _openEvents(context, childName),
            ),
            Expanded(
              child: zonesAsync.when(
                data: (zones) => zones.isEmpty
                    ? _EmptyState(childId: childId)
                    : _ZonesList(zones: zones, childId: childId),
                loading: () => const SkeletonList(
                  itemCount: 4,
                  itemHeight: 76,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.lg),
                    child: Text(
                      'geoZones.errorPrefix'.tr(namedArgs: {'error': '$e'}),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyS.copyWith(color: _dim),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════ HEADER ════════════════════════

class _Header extends StatelessWidget {
  const _Header({required this.childId, required this.onHistoryTap});

  final String childId;
  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Tepadan ancha pastroq (yuqori chetga yopishmasin — Figma "Manzillar").
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.md + 44,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      child: Row(
        children: [
          _GlassButton(
            icon: SolarIconsOutline.arrowLeft,
            onTap: () => context.pop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Manzillar',
                style: AppTextStyles.headlineL.copyWith(
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // ➕ — yangi manzil qo'shish (Figma: top-bar o'ngda).
          _GlassButton(
            icon: SolarIconsBold.addCircle,
            onTap: () => context.push(AppRoutes.geoZonesAddPath(childId)),
          ),
        ],
      ),
    );
  }
}

/// Top-bar yumaloq-kvadrat shisha tugmasi (Figma uslubi).
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _glassBtn,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(child: Icon(icon, size: 22, color: Colors.white)),
        ),
      ),
    );
  }
}

/// "Oxirgi 24 soatda X event" karta — faqat event'lar mavjud bo'lganda.
class _Last24HoursCard extends ConsumerWidget {
  const _Last24HoursCard({required this.childId, required this.onTap});

  final String childId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(geoZoneEventsCountProvider(childId));

    return countAsync.when(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.md,
            AppDimensions.sm,
            AppDimensions.md,
            0,
          ),
          child: Material(
            color: _cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _cardBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        SolarIconsBold.history,
                        size: 19,
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'geoZones.last24h.eventCount'.tr(
                          namedArgs: {'count': '$count'},
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyS.copyWith(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'geoZones.last24h.viewLink'.tr(),
                      style: AppTextStyles.bodyS.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Icon(
                      SolarIconsOutline.altArrowRight,
                      size: 18,
                      color: _dim,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ════════════════════════ EMPTY STATE ════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: _cardBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                SolarIconsBold.mapPointAdd,
                size: 52,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              'geoZones.empty.title'.tr(),
              style: AppTextStyles.headlineL.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'geoZones.empty.subtitle'.tr(),
              style: AppTextStyles.bodyS.copyWith(color: _dim),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.lg),
            PrimaryButton(
              label: 'geoZones.empty.addButton'.tr(),
              icon: SolarIconsBold.addCircle,
              expanded: false,
              onPressed: () => context.push(AppRoutes.geoZonesAddPath(childId)),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════ LIST ════════════════════════

class _ZonesList extends StatelessWidget {
  const _ZonesList({required this.zones, required this.childId});

  final List<GeoZone> zones;
  final String childId;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm + 2,
        AppDimensions.md,
        AppDimensions.lg,
      ),
      itemCount: zones.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final zone = zones[index];
        return _ZoneCard(zone: zone, childId: childId)
            .animate()
            .fadeIn(duration: 300.ms, delay: (50 * index).ms)
            .slideY(
              begin: 0.1,
              end: 0,
              duration: 300.ms,
              delay: (50 * index).ms,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }
}

/// Bitta manzil/zona kartasi (Figma 3-rasm): oq-kvadrat ikon + nom +
/// radius + qalam (edit).
class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zone, required this.childId});

  final GeoZone zone;
  final String childId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.geoZonesEditPath(childId, zone.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              // Oq kvadrat ichida to'q ikon (Figma uslubi).
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _iconSquare,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  GeoZone.iconFromString(
                    zone.icon ?? zone.type.defaultIconName,
                  ),
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      zone.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyM.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'geoZones.card.radius'.tr(
                        namedArgs: {'meters': '${zone.radiusMeters.round()}'},
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyS.copyWith(
                        color: _dim,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Qalam (edit) — Figma o'ng tomondagi belgisi.
              const Icon(SolarIconsOutline.pen, size: 19, color: _dim),
            ],
          ),
        ),
      ),
    );
  }
}
