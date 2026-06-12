import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_shadows.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/core/utils/formatters.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/geo_zones/data/models/geo_zone.dart';
import 'package:farzandim/features/geo_zones/presentation/providers/geo_zones_provider.dart';
import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:farzandim/features/location/presentation/providers/child_location_provider.dart';
import 'package:farzandim/features/location/presentation/utils/avatar_marker_builder.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

part 'location_map_sheet.dart';
part 'location_map_widgets.dart';

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
  ConsumerState<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends ConsumerState<LocationMapScreen> {
  GoogleMapController? _mapController;
  LatLng? _lastAnimatedTo;
  BitmapDescriptor? _avatarMarker;
  String? _avatarCacheKey;
  // Hozir yuklanayotgan avatar key — parallel network fetch + canvas render
  // bo'lmasligi uchun (SCR-05: har build postFrameCallback chaqirardi).
  String? _avatarLoadingKey;
  bool _userMovedCamera = false;
  // Dasturiy kamera harakati — onCameraMoveStarted'da user harakati bilan
  // adashtirmaslik uchun (SCR-02: birinchi avtomatik kameradan keyin
  // auto-follow o'zini o'chirib qo'yardi).
  bool _programmaticMove = false;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadAvatarMarker(Child child, String? avatarUrl) async {
    final key = '${child.id}_${avatarUrl ?? "null"}';
    if (_avatarCacheKey == key && _avatarMarker != null) return;
    // In-flight guard (SCR-05) — shu key allaqachon yuklanmoqda bo'lsa
    // parallel fetch/render boshlamaymiz.
    if (_avatarLoadingKey == key) return;
    _avatarLoadingKey = key;
    try {
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
    } finally {
      _avatarLoadingKey = null;
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
    _programmaticMove = true;
    ctrl
        .animateCamera(CameraUpdate.newLatLng(target))
        .whenComplete(() => _programmaticMove = false);
  }

  void _onCameraMoveStarted() {
    // Dasturiy animatsiya ham bu callback'ni chaqiradi — uni user harakati
    // deb hisoblamaymiz (SCR-02), aks holda auto-follow birinchi avtomatik
    // kameradan keyin o'zini o'chirib qo'yardi.
    if (_programmaticMove) return;
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
    _programmaticMove = true;
    ctrl
        .animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: loc, zoom: 16)),
        )
        .whenComplete(() => _programmaticMove = false);
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
        ref.watch(geoZonesProvider(child.id)).valueOrNull ?? const <GeoZone>[];

    final locationAsync = ref.watch(childLocationProvider(child.id));
    final avatarAsync = ref.watch(childAvatarUrlProvider(child.id));
    final avatarUrl = avatarAsync.valueOrNull;

    // Avatar marker'ni asinxron tayyorlash (bola yoki avatar o'zgarsa).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvatarMarker(child, avatarUrl);
    });

    // Yangi location kelganda kamera markerga harakatlanadi
    // (user qo'lda harakatlantirmagan bo'lsa).
    ref.listen<AsyncValue<ChildLocation?>>(childLocationProvider(child.id), (
      _,
      next,
    ) {
      final loc = next.valueOrNull;
      if (loc != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeAnimateCamera(loc.latLng);
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: locationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(child: child, error: e),
        data: (location) {
          if (location == null) {
            return _NoLocationState(child: child);
          }
          final screenH = MediaQuery.of(context).size.height;
          // Ixcham sheet — xarita ko'proq ko'rinadi (avval 0.42 edi).
          const sheetInitial = 0.36;
          return Stack(
            children: [
              _MapLayer(
                location: location,
                child: child,
                zones: zones,
                avatarMarker: _avatarMarker,
                bottomPadding: screenH * (sheetInitial - 0.06),
                onCameraMoveStarted: _onCameraMoveStarted,
                onMapCreated: (controller) {
                  _mapController = controller;
                  _lastAnimatedTo = location.latLng;
                },
              ),
              if (_userMovedCamera)
                Positioned(
                  right: AppDimensions.md,
                  bottom: screenH * sheetInitial + AppDimensions.md,
                  child: _RecenterFab(childName: child.name, onTap: _recenter),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  child: _TopBar(child: child),
                ),
              ),
              DraggableScrollableSheet(
                initialChildSize: sheetInitial,
                minChildSize: 0.26,
                maxChildSize: 0.9,
                snap: true,
                snapSizes: const [sheetInitial, 0.9],
                builder: (context, scrollController) => _LocationSheet(
                  child: child,
                  location: location,
                  scrollController: scrollController,
                ),
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
    required this.bottomPadding,
    required this.onMapCreated,
    required this.onCameraMoveStarted,
  });

  final ChildLocation location;
  final Child child;
  final List<GeoZone> zones;
  final BitmapDescriptor? avatarMarker;
  final double bottomPadding;
  final void Function(GoogleMapController) onMapCreated;
  final VoidCallback onCameraMoveStarted;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: location.latLng, zoom: 16),
      // Default Google Maps style (user dark premium juda qorong'i dedi).
      markers: {
        Marker(
          markerId: MarkerId(child.id),
          position: location.latLng,
          icon: avatarMarker ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: child.name,
            snippet: 'location.updatedSuffix'.tr(
              namedArgs: {'time': formatRelativeTime(location.updatedAt)},
            ),
          ),
        ),
      },
      circles: {
        // Aniqlik halosi — "Joyida" holatiga mos yashil tus.
        Circle(
          circleId: const CircleId('accuracy'),
          center: location.latLng,
          radius: location.accuracy.clamp(20, 120).toDouble(),
          fillColor: AppColors.success.withValues(alpha: 0.10),
          strokeColor: AppColors.success.withValues(alpha: 0.45),
          strokeWidth: 1,
        ),
        for (final zone in zones)
          Circle(
            circleId: CircleId(zone.id),
            center: zone.center,
            radius: zone.radiusMeters,
            fillColor: AppColors.accent.withValues(alpha: 0.12),
            strokeColor: AppColors.accent,
            strokeWidth: 2,
          ),
      },
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      onMapCreated: onMapCreated,
      onCameraMoveStarted: onCameraMoveStarted,
      padding: EdgeInsets.only(bottom: bottomPadding),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.gps_fixed_rounded,
                color: AppColors.onPrimary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                childName,
                style: const TextStyle(
                  color: AppColors.onPrimary,
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
