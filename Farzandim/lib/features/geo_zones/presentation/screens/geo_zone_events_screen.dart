import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/geo_zones/data/models/geo_zone_event.dart';
import 'package:farzandim/features/geo_zones/presentation/providers/geo_zone_event_providers.dart';
import 'package:farzandim/features/geo_zones/presentation/widgets/geo_zone_event_tile.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bola uchun barcha geo-zona event'lari (kirdi/chiqdi) tarixi.
///
/// Stream Firestore'dan keladi — yangi event kelishi bilan ro'yxat
/// avtomatik yangilanadi. Pull-to-refresh stream'ni qayta ulash
/// (kechikish bo'lsa).
///
/// Empty state: bola hali zonaga kirib chiqmagan bo'lsa katta lime
/// green doira + bola ismi bilan personalized xabar.
class GeoZoneEventsScreen extends ConsumerWidget {
  /// `GeoZoneEventsScreen` konstruktor.
  const GeoZoneEventsScreen({
    required this.childId,
    required this.childName,
    super.key,
  });

  /// Qaysi bola event'lari ko'rsatiladi.
  final String childId;

  /// Bola ismi — header subtitle va empty state matnida ishlatiladi.
  final String childName;

  Future<void> _onRefresh(WidgetRef ref) async {
    ref
      ..invalidate(geoZoneEventsProvider(childId))
      ..invalidate(geoZoneEventsCountProvider(childId));
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(geoZoneEventsProvider(childId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(childName: childName),
              Expanded(
                child: eventsAsync.when(
                  data: (events) {
                    if (events.isEmpty) {
                      return _EmptyEvents(
                        childName: childName,
                        onRefresh: () => _onRefresh(ref),
                      );
                    }
                    return RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      onRefresh: () => _onRefresh(ref),
                      child: _EventsList(events: events),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.lg),
                      child: Text(
                        'geoZoneEvents.errorPrefix'.tr(
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.childName});

  final String childName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.lg,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
              ),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'geoZoneEvents.headerTitle'.tr(),
                    style: AppTextStyles.headlineL.copyWith(
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    childName,
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Back tugmaning kompensatsiyasi — sarlavha aniq markazda.
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _EventsList extends StatelessWidget {
  const _EventsList({required this.events});

  final List<GeoZoneEvent> events;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: events.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 72),
        child: Divider(
          height: 1,
          thickness: 0.5,
          color: AppColors.textSecondary.withValues(alpha: 0.1),
        ),
      ),
      itemBuilder: (_, i) => GeoZoneEventTile(event: events[i]),
    );
  }
}

class _EmptyEvents extends StatelessWidget {
  const _EmptyEvents({
    required this.childName,
    required this.onRefresh,
  });

  final String childName;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    // Empty state ham pull-to-refresh qabul qiladi — RefreshIndicator
    // scrollable child kutadi.
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (_, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history,
                      size: 50,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  Text(
                    'geoZoneEvents.empty.title'.tr(),
                    style: AppTextStyles.headlineL.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'geoZoneEvents.empty.subtitle'.tr(
                      namedArgs: {'name': childName},
                    ),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
