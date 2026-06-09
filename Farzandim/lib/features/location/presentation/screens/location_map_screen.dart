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
          final screenH = MediaQuery.of(context).size.height;
          const sheetInitial = 0.5;
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
              DraggableScrollableSheet(
                initialChildSize: sheetInitial,
                minChildSize: 0.32,
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
      compassEnabled: true,
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
              Icon(
                Icons.gps_fixed_rounded,
                color: AppColors.onPrimary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                childName,
                style: TextStyle(
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
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: AppColors.surface,
        shape: CircleBorder(
          side: BorderSide(color: AppColors.border),
        ),
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
                color: AppColors.textPrimary,
              ),
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

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          side: BorderSide(color: AppColors.border),
        ),
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
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasMultiple) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.textSecondary,
                  ),
                ],
              ],
            ),
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

// ═══════════════ LOCATION SHEET (Command Deck) ═══════════════

/// Premium "boshqaruv paneli" pastki varaq (DraggableScrollableSheet ichida).
///
/// Tuzilma (ota-ona savollari tartibida): HERO (avatar + ism + JONLI puls) →
/// MANZIL kartasi ("qayerda") → 3 metrika (holat / batareya / aniqlik) →
/// 2 ta katta amal tugmasi (Geo-zonalar to'liq-rang CTA + Tarixni ko'rish).
/// Faqat origin/main'da mavjud tokenlar ishlatiladi (GlassCard/glass token YO'Q).
class _LocationSheet extends ConsumerWidget {
  const _LocationSheet({
    required this.child,
    required this.location,
    required this.scrollController,
  });

  final Child child;
  final ChildLocation location;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(childAddressProvider(child.id)).valueOrNull;
    final zoneCount =
        ref.watch(geoZonesProvider(child.id)).valueOrNull?.length ?? 0;
    final battery = child.deviceInfo?.batteryLevel;
    final isCharging = child.deviceInfo?.isCharging ?? false;
    final isMoving = location.isMoving;
    final topRadius = BorderRadius.vertical(
      top: Radius.circular(AppDimensions.radiusL),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: topRadius,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.elevated,
      ),
      child: ClipRRect(
        borderRadius: topRadius,
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.sm,
            AppDimensions.lg,
            MediaQuery.of(context).padding.bottom + AppDimensions.lg,
          ),
          children: [
            // Drag handle.
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── HERO: avatar (mint halqa) + ism + JONLI puls ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.55),
                      width: 2,
                    ),
                  ),
                  child:
                      ChildAvatar(child: child, size: 54, showBorder: false),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              child.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.headlineL.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const _LivePill(),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${'location.command.now'.tr()} · '
                        '${formatRelativeTime(location.updatedAt)}',
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimensions.md),

            // ── MANZIL kartasi ("qayerda" — eng muhim ma'lumot) ──
            _AddressCard(address: address),

            const SizedBox(height: AppDimensions.md),

            // ── 3 metrika: holat / batareya / aniqlik ──
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: isMoving
                        ? Icons.directions_walk_rounded
                        : Icons.check_circle_rounded,
                    tint: isMoving ? AppColors.accent : AppColors.success,
                    value: isMoving
                        ? 'location.command.statusMoving'.tr()
                        : 'location.command.statusStationary'.tr(),
                    label: 'location.command.statusLabel'.tr(),
                    valueColored: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: isCharging
                        ? Icons.bolt_rounded
                        : Icons.battery_full_rounded,
                    tint: battery == null
                        ? AppColors.textTertiary
                        : battery >= 50
                            ? AppColors.success
                            : battery >= 20
                                ? AppColors.warning
                                : AppColors.error,
                    value: battery == null ? '—' : '$battery%',
                    label: 'location.command.batteryLabel'.tr(),
                    valueColored: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.gps_fixed_rounded,
                    tint: AppColors.info,
                    value: 'location.command.accuracyValue'.tr(
                      namedArgs: {'meters': '${location.accuracy.round()}'},
                    ),
                    label: 'location.command.accuracyLabel'.tr(),
                    valueColored: false,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimensions.lg),

            // Amal tugmalari: 1-si to'liq-rang CTA, 2-si outline.
            _ActionButton(
              icon: Icons.fence_rounded,
              label: 'location.geoZonesButton'.tr(),
              trailing: zoneCount > 0
                  ? 'location.command.zonesCount'
                      .tr(namedArgs: {'count': '$zoneCount'})
                  : null,
              filled: true,
              onTap: () => context.push(AppRoutes.geoZonesPath(child.id)),
            ),
            const SizedBox(height: 12),
            _ActionButton(
              icon: Icons.route_rounded,
              label: 'location.command.historyButton'.tr(),
              filled: false,
              onTap: () =>
                  context.push(AppRoutes.locationHistoryPath(child.id)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Jonli puls indikatori (real-vaqt signali) ───

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(color: AppColors.accent, size: 7),
          const SizedBox(width: 6),
          Text(
            'location.command.live'.tr(),
            style: AppTextStyles.label.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yumshoq nafas oluvchi puls nuqtasi — o'z AnimationController'ini saqlaydi
/// (StatefulWidget, shunda stream qayta-build qilganda controller buzilmaydi).
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.20 + 0.35 * (1 - t)),
                blurRadius: 3 + 5 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Manzil kartasi ───

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});

  final String? address;

  @override
  Widget build(BuildContext context) {
    final hasAddress = address != null && address!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child:
                Icon(Icons.place_rounded, size: 19, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: hasAddress
                ? Text(
                    address!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyM.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  )
                : Text(
                    'location.command.addressLoading'.tr(),
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Metrika plitkasi (holat / batareya / aniqlik) ───

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.tint,
    required this.value,
    required this.label,
    required this.valueColored,
  });

  final IconData icon;
  final Color tint;
  final String value;
  final String label;
  final bool valueColored;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: tint),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTextStyles.headlineL.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: valueColored ? tint : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Katta amal tugmasi (to'liq-rang CTA yoki outline) ───

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimensions.radiusPill);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: filled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                )
              : null,
          color: filled ? null : AppColors.surfaceVariant,
          borderRadius: radius,
          border: filled
              ? null
              : Border.all(color: AppColors.border, width: 1.4),
          boxShadow: filled ? AppShadows.glow(AppColors.primary) : null,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: filled ? AppColors.onPrimary : AppColors.accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyM.copyWith(
                              color: filled
                                  ? AppColors.onPrimary
                                  : AppColors.textPrimary,
                              fontWeight:
                                  filled ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.onPrimary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              trailing!,
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: filled
                        ? AppColors.onPrimary.withValues(alpha: 0.75)
                        : AppColors.textTertiary,
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
