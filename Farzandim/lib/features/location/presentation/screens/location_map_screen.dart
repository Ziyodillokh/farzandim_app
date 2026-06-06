import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/core/utils/formatters.dart';
import 'package:farzandim/features/child_management/data/models/child_device_info.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/geo_zones/data/models/geo_zone.dart';
import 'package:farzandim/features/geo_zones/presentation/providers/geo_zones_provider.dart';
import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:farzandim/features/location/presentation/providers/child_location_provider.dart';
import 'package:farzandim/features/location/presentation/utils/avatar_marker_builder.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:farzandim/shared/widgets/secondary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Bola joylashuvini xaritada ko'rsatuvchi ekran.
///
/// Child App `users/{parentUid}/children/{childId}` doc'iga `location`
/// field yozadi (10m harakat filter). `childLocationProvider.family`
/// shu field'ga snapshot stream qo'yadi va real-vaqt marker chiqaradi.
///
/// `childId` — qaysi bola ko'rsatiladi. `null` bo'lsa birinchi bola.
class LocationMapScreen extends ConsumerStatefulWidget {
  /// `LocationMapScreen` konstruktor.
  const LocationMapScreen({super.key, this.childId});

  /// Ko'rsatiladigan bola identifikatori. `null` bo'lsa ro'yxatdagi
  /// birinchi bola tanlanadi.
  final String? childId;

  @override
  ConsumerState<LocationMapScreen> createState() =>
      _LocationMapScreenState();
}

class _LocationMapScreenState extends ConsumerState<LocationMapScreen> {
  GoogleMapController? _mapController;
  LatLng? _lastAnimatedTo;
  BitmapDescriptor? _avatarMarker;
  String? _avatarCacheKey;
  bool _userMovedCamera = false;
  Timer? _recenterDebounce;
  String? _premiumMapStyle;

  @override
  void initState() {
    super.initState();
    // Premium dark style olib tashlandi — foydalanuvchi default xohladi.
  }

  @override
  void dispose() {
    _recenterDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadAvatarMarker(Child child, String? avatarUrl) async {
    final key = '${child.id}_${avatarUrl ?? "null"}';
    if (_avatarCacheKey == key && _avatarMarker != null) return;
    final marker = await AvatarMarkerBuilder.build(
      avatarUrl: avatarUrl,
      fallbackKey: child.name,
    );
    if (mounted) {
      setState(() {
        _avatarMarker = marker;
        _avatarCacheKey = key;
      });
    }
  }

  /// Yangi joylashuv kelganda kamerani avtomatik markerga olib boradi —
  /// faqat user qo'lda surganida emas.
  void _maybeAnimateCamera(LatLng target, {bool force = false}) {
    final ctrl = _mapController;
    if (ctrl == null) return;
    if (!force && _userMovedCamera) return;
    final prev = _lastAnimatedTo;
    if (!force &&
        prev != null &&
        (prev.latitude - target.latitude).abs() < 0.00001 &&
        (prev.longitude - target.longitude).abs() < 0.00001) {
      return;
    }
    _lastAnimatedTo = target;
    ctrl.animateCamera(CameraUpdate.newLatLng(target));
  }

  void _onCameraMoveStarted() {
    _recenterDebounce?.cancel();
    if (!_userMovedCamera) {
      setState(() => _userMovedCamera = true);
    }
  }

  void _recenter() {
    final loc = _lastAnimatedTo;
    if (loc == null) return;
    setState(() => _userMovedCamera = false);
    final ctrl = _mapController;
    if (ctrl == null) return;
    ctrl.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: loc, zoom: 16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenListProvider);

    if (children.isEmpty) {
      return const _NoChildrenScreen();
    }

    final child = widget.childId == null
        ? children.first
        : children.firstWhereOrNull((c) => c.id == widget.childId) ??
            children.first;

    final zones =
        ref.watch(geoZonesProvider(child.id)).valueOrNull ??
            const <GeoZone>[];

    final locationAsync = ref.watch(childLocationProvider(child.id));
    final avatarAsync = ref.watch(childAvatarUrlProvider(child.id));
    final avatarUrl = avatarAsync.valueOrNull;

    // Avatar marker'ni asinxron tayyorlash (bola yoki avatar o'zgarsa).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvatarMarker(child, avatarUrl);
    });

    // Yangi location kelganda kamera markerga harakatlanadi
    // (user qo'lda harakatlantirmagan bo'lsa).
    ref.listen<AsyncValue<ChildLocation?>>(
      childLocationProvider(child.id),
      (_, next) {
        final loc = next.valueOrNull;
        if (loc != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybeAnimateCamera(loc.latLng);
          });
        }
      },
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: locationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(child: child, error: e),
        data: (location) {
          if (location == null) {
            return _NoLocationState(child: child);
          }
          return Stack(
            children: [
              _MapLayer(
                location: location,
                child: child,
                zones: zones,
                avatarMarker: _avatarMarker,
                mapStyle: _premiumMapStyle,
                onCameraMoveStarted: _onCameraMoveStarted,
                onMapCreated: (controller) {
                  _mapController = controller;
                  _lastAnimatedTo = location.latLng;
                },
              ),
              if (_userMovedCamera)
                Positioned(
                  right: AppDimensions.md,
                  bottom: 240,
                  child: _RecenterFab(
                    childName: child.name,
                    onTap: _recenter,
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  child: _TopBar(child: child),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomCard(child: child, location: location),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ════════════════════════ MAP LAYER ════════════════════════

class _MapLayer extends StatelessWidget {
  const _MapLayer({
    required this.location,
    required this.child,
    required this.zones,
    required this.avatarMarker,
    required this.mapStyle,
    required this.onMapCreated,
    required this.onCameraMoveStarted,
  });

  final ChildLocation location;
  final Child child;
  final List<GeoZone> zones;
  final BitmapDescriptor? avatarMarker;
  final String? mapStyle;
  final void Function(GoogleMapController) onMapCreated;
  final VoidCallback onCameraMoveStarted;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: location.latLng,
        zoom: 16,
      ),
      // Default Google Maps style (user dark premium juda qorong'i dedi).
      markers: {
        Marker(
          markerId: MarkerId(child.id),
          position: location.latLng,
          icon: avatarMarker ?? BitmapDescriptor.defaultMarker,
          // Pin uchburchak quyruq aniq joyga to'g'rilanadi.
          anchor: const Offset(0.5, 1.0),
          infoWindow: InfoWindow(
            title: child.name,
            snippet: 'location.updatedSuffix'.tr(
              namedArgs: {'time': formatRelativeTime(location.updatedAt)},
            ),
          ),
        ),
      },
      circles: {
        for (final zone in zones)
          Circle(
            circleId: CircleId(zone.id),
            center: zone.center,
            radius: zone.radiusMeters,
            fillColor: AppColors.primary.withValues(alpha: 0.15),
            strokeColor: AppColors.primary,
            strokeWidth: 2,
          ),
      },
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: true,
      onMapCreated: onMapCreated,
      onCameraMoveStarted: onCameraMoveStarted,
      padding: const EdgeInsets.only(bottom: 220),
    );
  }
}

// ════════════════════════ RECENTER FAB ════════════════════════

class _RecenterFab extends StatelessWidget {
  const _RecenterFab({required this.childName, required this.onTap});
  final String childName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.gps_fixed_rounded,
                color: Colors.black,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                childName,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ TOP BAR ════════════════════════

class _TopBar extends StatelessWidget {
  const _TopBar({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleIconButton(
          icon: Icons.arrow_back,
          onTap: () => context.pop(),
        ),
        const Spacer(),
        _ChildSelectorChip(child: child),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(
              icon,
              size: 24,
              color: AppColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChildSelectorChip extends ConsumerWidget {
  const _ChildSelectorChip({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenListProvider);
    final hasMultiple = children.length > 1;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      elevation: 4,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasMultiple ? () => _openPicker(context, children) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChildAvatar(child: child, size: 32, showBorder: false),
              const SizedBox(width: 8),
              Text(
                child.name,
                style: AppTextStyles.bodyM.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasMultiple) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.onPrimary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(
    BuildContext context,
    List<Child> children,
  ) async {
    final selected = await showModalBottomSheet<Child>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Text(
                'location.picker.title'.tr(),
                style: AppTextStyles.headlineL.copyWith(fontSize: 18),
              ),
            ),
            for (final c in children)
              ListTile(
                leading: ChildAvatar(child: c, size: 40),
                title: Text(c.name, style: AppTextStyles.bodyM),
                trailing: c.id == child.id
                    ? Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(c),
              ),
            const SizedBox(height: AppDimensions.sm),
          ],
        ),
      ),
    );

    if (selected != null && selected.id != child.id && context.mounted) {
      context.pushReplacement(AppRoutes.locationPath(selected.id));
    }
  }
}

// ════════════════════════ BOTTOM CARD ════════════════════════

class _BottomCard extends ConsumerWidget {
  const _BottomCard({required this.child, required this.location});

  final Child child;
  final ChildLocation location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(childAddressProvider(child.id)).valueOrNull;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.lg,
        AppDimensions.lg,
        MediaQuery.of(context).padding.bottom + AppDimensions.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ChildAvatar(child: child, size: 56),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      child.name,
                      style: AppTextStyles.headlineL.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'location.updatedSuffix'.tr(
                        namedArgs: {
                          'time': formatRelativeTime(location.updatedAt),
                        },
                      ),
                      style: AppTextStyles.bodyS.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (child.deviceInfo?.batteryLevel != null)
                _BatteryPill(info: child.deviceInfo!),
            ],
          ),

          // Manzil (reverse geocoding) — eng muhim ma'lumot.
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_rounded,
                    size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: AppTextStyles.bodyM.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppDimensions.md),

          // Status row: harakat + aniqlik.
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                location.isMoving
                    ? 'location.moving'.tr()
                    : 'location.stationary'.tr(),
                style: AppTextStyles.bodyS.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                'location.accuracy'.tr(
                  namedArgs: {'meters': '${location.accuracy.round()}'},
                ),
                style: AppTextStyles.bodyS.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.lg - 4),

          // Action tugma.
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'location.geoZonesButton'.tr(),
                  icon: Icons.fence_outlined,
                  onPressed: () =>
                      context.push(AppRoutes.geoZonesPath(child.id)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SecondaryButton(
                  label: 'locationHistory.viewButton'.tr(),
                  icon: Icons.route_outlined,
                  onPressed: () => context.push(
                    AppRoutes.locationHistoryPath(child.id),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ NO LOCATION ════════════════════════

class _NoLocationState extends StatelessWidget {
  const _NoLocationState({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: _TopBar(child: child),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 80,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Text(
                    'location.noLocation.title'.tr(),
                    style: AppTextStyles.headlineL.copyWith(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'location.noLocation.subtitle'.tr(
                      namedArgs: {'name': child.name},
                    ),
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ ERROR STATE ════════════════════════

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.child, required this.error});

  final Child child;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: _TopBar(child: child),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Text(
                    'location.error.title'.tr(),
                    style: AppTextStyles.headlineL.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    '$error',
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ BATTERY PILL ════════════════════════

class _BatteryPill extends StatelessWidget {
  const _BatteryPill({required this.info});

  final ChildDeviceInfo info;

  Color _color(int level) {
    if (level >= 50) return AppColors.success;
    if (level >= 20) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final level = info.batteryLevel!;
    final isCharging = info.isCharging ?? false;
    final color = _color(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCharging ? Icons.battery_charging_full : Icons.battery_full,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$level%',
            style: AppTextStyles.bodyS.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ NO CHILDREN ════════════════════════

class _NoChildrenScreen extends StatelessWidget {
  const _NoChildrenScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Text(
            'location.noChildren'.tr(),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
