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
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:farzandim/shared/widgets/skeleton_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bola uchun barcha geo-zonalari real-time ro'yxati.
///
/// Stream Firestore'dan keladi (`users/{uid}/children/{childId}/geo_zones`).
/// Ikki holat:
/// - **Empty state** (`zones.isEmpty`): markazda hint + "Yangi geo-zona
///   qo'shish" tugmasi.
/// - **List state**: zonalar kartochkalari, pastida "+Yangi" FAB.
///
/// Karta bossa edit ekraniga ko'chadi
/// (`/geo-zones/:childId/edit/:id`).
class GeoZonesListScreen extends ConsumerWidget {
  /// `GeoZonesListScreen` konstruktor.
  const GeoZonesListScreen({required this.childId, super.key});

  /// Qaysi bola uchun zonalar ko'rsatiladi.
  final String childId;

  void _openEvents(BuildContext context, String childName) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GeoZoneEventsScreen(
          childId: childId,
          childName: childName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(geoZonesProvider(childId));
    final child = ref.watch(childByIdProvider(childId));
    final childName = child?.name ?? 'geoZones.fallbackChildName'.tr();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(onHistoryTap: () => _openEvents(context, childName)),
              _Last24HoursCard(
                childId: childId,
                onTap: () => _openEvents(context, childName),
              ),
              Expanded(
                child: zonesAsync.when(
                  data: (zones) => zones.isEmpty
                      ? _EmptyState(childId: childId)
                      : _ZonesList(zones: zones, childId: childId),
                  // Skeleton: zone card list
                  loading: () => const SkeletonList(
                    itemCount: 4,
                    itemHeight: 96,
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.lg),
                      child: Text(
                        'geoZones.errorPrefix'.tr(
                          namedArgs: {'error': '$e'},
                        ),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: zonesAsync.maybeWhen(
        data: (zones) => zones.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () =>
                    context.push(AppRoutes.geoZonesAddPath(childId)),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                icon: const Icon(Icons.add),
                label: Text(
                  'geoZones.newFab'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
        orElse: () => null,
      ),
    );
  }
}

// ════════════════════════ HEADER ════════════════════════

class _Header extends StatelessWidget {
  const _Header({required this.onHistoryTap});

  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.lg,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          // Back tugma — 48x48 IconButton.
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
              ),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'geoZones.headerTitle'.tr(),
                style: AppTextStyles.headlineL.copyWith(fontSize: 20),
              ),
            ),
          ),
          // Tarix tugma (kirish/chiqish event'lari).
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(
                Icons.history,
                color: AppColors.textPrimary,
              ),
              onPressed: onHistoryTap,
              tooltip: 'geoZones.historyTooltip'.tr(),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Oxirgi 24 soatda X event" karta. Faqat event'lar mavjud bo'lganda
/// ko'rinadi (count > 0). Tap → tarix ekran.
class _Last24HoursCard extends ConsumerWidget {
  const _Last24HoursCard({required this.childId, required this.onTap});

  final String childId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync =
        ref.watch(geoZoneEventsCountProvider(childId));

    return countAsync.when(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.lg,
            vertical: AppDimensions.sm,
          ),
          child: Material(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusM),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.md - 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: AppColors.accent,
                      size: 22,
                    ),
                    const SizedBox(width: AppDimensions.sm + 4),
                    Expanded(
                      child: Text(
                        'geoZones.last24h.eventCount'.tr(
                          namedArgs: {'count': '$count'},
                        ),
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      'geoZones.last24h.viewLink'.tr(),
                      style: AppTextStyles.bodyS.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.accent,
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
            Icon(
              Icons.fence_outlined,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              'geoZones.empty.title'.tr(),
              style: AppTextStyles.headlineL.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'geoZones.empty.subtitle'.tr(),
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.lg),
            PrimaryButton(
              label: 'geoZones.empty.addButton'.tr(),
              icon: Icons.add,
              expanded: false,
              onPressed: () =>
                  context.push(AppRoutes.geoZonesAddPath(childId)),
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
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        // FAB ostidan elementlar ko'rinishi uchun pastdan ko'p padding.
        96,
      ),
      itemCount: zones.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final zone = zones[index];
        return _ZoneCard(zone: zone, childId: childId)
            // Stagger: har zona kartochkasi 50ms kechikish bilan
            .animate()
            .fadeIn(
              duration: 300.ms,
              delay: (50 * index).ms,
            )
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

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zone, required this.childId});

  final GeoZone zone;
  final String childId;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppDimensions.radiusM);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context
            .push(AppRoutes.geoZonesEditPath(childId, zone.id)),
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Row(
            children: [
              // Lime green tinted circle + ikonka.
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  GeoZone.iconFromString(
                    zone.icon ?? zone.type.defaultIconName,
                  ),
                  size: 24,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      zone.name,
                      style: AppTextStyles.bodyM.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'geoZones.card.radius'.tr(
                        namedArgs: {
                          'meters': '${zone.radiusMeters.round()}',
                        },
                      ),
                      style: AppTextStyles.bodyS.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 24,
                color: AppColors.textPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
