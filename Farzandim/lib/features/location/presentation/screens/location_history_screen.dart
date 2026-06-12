import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_shadows.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:farzandim/features/location/data/models/location_stop.dart';
import 'package:farzandim/features/location/data/services/dwell_detector.dart';
import 'package:farzandim/features/location/data/services/geocoding_service.dart';
import 'package:farzandim/features/location/presentation/providers/location_history_provider.dart';
import 'package:farzandim/features/location/presentation/utils/avatar_marker_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart'
    show keepAliveFor;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// To'xtagan joy manzili (reverse geocoding) — "lat,lng" kalit, keshli.
final _placeAddressProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, latLng) async {
  // SCR-09: autoDispose + qisqa kesh — har koordinata abadiy keshda
  // qolib xotira cheksiz o'sardi; ekran ochiq ekan kesh yetarli.
  keepAliveFor(ref, const Duration(minutes: 2));
  final parts = latLng.split(',');
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0]);
  final lng = double.tryParse(parts[1]);
  if (lat == null || lng == null) return null;
  return ref.watch(geocodingServiceProvider).reverse(lat, lng);
});

/// Bola harakat tarixini xaritada polyline sifatida ko'rsatuvchi ekran.
///
/// Stream Firestore `users/{parentUid}/children/{childId}/location_history`
/// subcollection'idan keladi. Range chips (24h / 7d / 30d) bilan filtrlash.
///
/// **UX:**
/// - Yuqori: header (Back, sarlavha + bola ismi)
/// - O'rta: GoogleMap with Polyline + start/end markers (camera auto-fit)
/// - Past: range chips va statistika karta (nuqtalar, masofa)
class LocationHistoryScreen extends ConsumerStatefulWidget {
  /// `LocationHistoryScreen` konstruktor.
  const LocationHistoryScreen({required this.childId, super.key});

  /// Qaysi bolaning tarixi ko'rsatiladi.
  final String childId;

  @override
  ConsumerState<LocationHistoryScreen> createState() =>
      _LocationHistoryScreenState();
}

class _LocationHistoryScreenState
    extends ConsumerState<LocationHistoryScreen> {
  /// Tanlangan vaqt oralig'i — default bugungi kun.
  late DateTime _fromDt;
  late DateTime _toDt;

  GoogleMapController? _mapController;
  BitmapDescriptor? _avatarMarker;
  int? _openDwellIndex; // tap-to-toggle: -1 = barchasi yopiq

  // PERF-06: _cleanTrack (O(n) haversine) va masofa HAR setState'da (dwell
  // tap, avatar, sana) qayta hisoblanardi. Provider qiymati o'zgarmasa List
  // identity bir xil — memoize. Barqaror identity _MapLayer'dagi dwell
  // keshiga ham asos bo'ladi.
  List<ChildLocation>? _trackMemoInput;
  List<ChildLocation> _trackMemo = const <ChildLocation>[];
  double _distanceKmMemo = 0;

  List<ChildLocation> _memoizedTrack(List<ChildLocation> raw) {
    if (!identical(raw, _trackMemoInput)) {
      _trackMemoInput = raw;
      _trackMemo = _cleanTrack(raw);
      _distanceKmMemo = _calculateDistanceKm(_trackMemo);
    }
    return _trackMemo;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    _fromDt = start;
    _toDt = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: DateTime(_fromDt.year, _fromDt.month, _fromDt.day),
        end: DateTime(_toDt.year, _toDt.month, _toDt.day),
      ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: (AppColors.isDark
                  ? const ColorScheme.dark()
                  : const ColorScheme.light())
              .copyWith(
            primary: AppColors.primary,
            onPrimary: AppColors.onPrimary,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _fromDt = picked.start;
      // Tanlangan kun oxirigacha (23:59:59)
      _toDt = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
      );
      _openDwellIndex = null; // sana o'zgarsa popup yopilsin
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  /// Joylar ro'yxatidan biror to'xtash bosilganda xaritani unga markazlash.
  void _goToStop(LatLng target) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(childByIdProvider(widget.childId));
    final childName =
        child?.name ?? 'locationHistory.fallbackChildName'.tr();

    final query = (
      childId: widget.childId,
      fromMs: _fromDt.millisecondsSinceEpoch,
      toMs: _toDt.millisecondsSinceEpoch,
    );
    final historyAsync = ref.watch(locationHistoryProvider(query));
    // Backend stop-detection topgan to'xtagan joylar (markerlar manbasi).
    final stops =
        ref.watch(locationStopsProvider(query)).valueOrNull ??
            const <LocationStop>[];

    // Tarix nuqtalarini tozalash — yomon-aniqlik fix va statsionar jitter
    // klasterlari olib tashlanadi (zigzag/soxta "borib-kelish" + shishgan
    // masofa yo'qoladi). Backend yangi data'ni filtrlaydi; bu eski data'ni
    // ham toza ko'rsatadi.
    final track = _memoizedTrack(
      historyAsync.valueOrNull ?? const <ChildLocation>[],
    );

    // Avatar marker for end pin
    if (child != null && _avatarMarker == null) {
      final avatarUrl = ref.watch(childAvatarUrlProvider(child.id)).valueOrNull;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final m = await AvatarMarkerBuilder.build(
          avatarUrl: avatarUrl,
          fallbackKey: child.name,
        );
        if (mounted) setState(() => _avatarMarker = m);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Map layer (full screen).
            historyAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.lg),
                  child: Text(
                    'locationHistory.errorPrefix'.tr(
                      namedArgs: {'error': '$e'},
                    ),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              data: (points) {
                if (points.isEmpty) return const _EmptyState();
                // Tozalangan track (bo'sh bo'lib qolmasligi uchun fallback).
                final shown = track.isNotEmpty ? track : points;
                return _MapLayer(
                  points: shown,
                  stops: stops,
                  avatarMarker: _avatarMarker,
                  openDwellIndex: _openDwellIndex,
                  onDwellTap: (idx) {
                    setState(() {
                      _openDwellIndex =
                          _openDwellIndex == idx ? null : idx;
                    });
                  },
                  onMapTap: () {
                    if (_openDwellIndex != null) {
                      setState(() => _openDwellIndex = null);
                    }
                  },
                  onMapCreated: (c) {
                    _mapController = c;
                    _fitToBounds(shown);
                  },
                );
              },
            ),

            // Top bar (back + title).
            Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: _TopBar(childName: childName),
            ),

            // Bottom panel: faqat sana picker + stats.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomPanel(
                fromDt: _fromDt,
                toDt: _toDt,
                onCustomDateTap: _pickDateRange,
                stops: stops,
                onPlaceTap: _goToStop,
                distanceKm: _distanceKmMemo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Camera'ni barcha nuqtalarni o'z ichiga oladigan bounds'ga moslab
  /// joylashtirish.
  void _fitToBounds(List<ChildLocation> points) {
    if (points.isEmpty || _mapController == null) return;
    if (points.length == 1) {
      // Bitta nuqta — atrofida zoom 15.
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: points.first.latLng, zoom: 15),
        ),
      );
      return;
    }

    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    final bounds = LatLngBounds(
      southwest: LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
      northeast: LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
    );
    // Padding 80px — bottom panel ostida nuqtalar yashirib qolmasligi
    // uchun.
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  /// Tarix nuqtalarini tozalaydi (professional joylashuv mantig'i):
  ///  - aniqligi yomon (>100m) fix'lar tashlanadi (cell-tower/garbage);
  ///  - oxirgi saqlangan nuqtadan <25m masofadagi nuqtalar yutiladi
  ///    (statsionar GPS jitter — soxta "borib-kelish" zigzag va shishgan
  ///    masofani oldini oladi).
  /// Backend ham yangi data'ni filtrlaydi; bu eski data'ni ham toza ko'rsatadi.
  List<ChildLocation> _cleanTrack(List<ChildLocation> points) {
    const maxAccuracyM = 100.0;
    const minGapM = 25.0;
    final cleaned = <ChildLocation>[];
    for (final p in points) {
      // accuracy == 0 → noma'lum (backend bermagan) → o'tkazamiz.
      if (p.accuracy > maxAccuracyM) continue;
      if (cleaned.isEmpty) {
        cleaned.add(p);
        continue;
      }
      if (_haversineKm(cleaned.last, p) * 1000 >= minGapM) {
        cleaned.add(p);
      }
    }
    return cleaned;
  }

  /// Polyline bo'ylab jami masofani km'da hisoblash (haversine).
  double _calculateDistanceKm(List<ChildLocation>? points) {
    if (points == null || points.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += _haversineKm(points[i - 1], points[i]);
    }
    return total;
  }

  /// Ikki nuqta orasidagi masofa (km) — Haversine formula.
  double _haversineKm(ChildLocation a, ChildLocation b) {
    const earthKm = 6371.0;
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLng = _toRadians(b.longitude - a.longitude);
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) *
            math.sin(dLng / 2) *
            math.cos(lat1) *
            math.cos(lat2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthKm * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}

// ════════════════════════ MAP LAYER ════════════════════════

class _MapLayer extends StatefulWidget {
  const _MapLayer({
    required this.points,
    required this.stops,
    required this.onMapCreated,
    required this.openDwellIndex,
    required this.onDwellTap,
    required this.onMapTap,
    this.avatarMarker,
  });

  final List<ChildLocation> points;
  final List<LocationStop> stops;
  final BitmapDescriptor? avatarMarker;
  final int? openDwellIndex;
  final void Function(int idx) onDwellTap;
  final VoidCallback onMapTap;
  final void Function(GoogleMapController) onMapCreated;

  @override
  State<_MapLayer> createState() => _MapLayerState();
}

class _MapLayerState extends State<_MapLayer> {
  final Map<String, BitmapDescriptor> _dwellLabels = {};

  // PERF-06: fallback dwell-detection (O(n²) klasterlash) har rebuild'da
  // (dwell tap, label kelishi) qayta ishlardi. points identity barqaror
  // (parent memoize qiladi) — natijani keshlaymiz.
  List<ChildLocation>? _dwellMemoInput;
  List<AggregatedDwell> _dwellMemo = const <AggregatedDwell>[];

  List<AggregatedDwell> _memoizedDwells(List<ChildLocation> points) {
    if (!identical(points, _dwellMemoInput)) {
      _dwellMemoInput = points;
      _dwellMemo = DwellDetector.aggregateByLocation(
        DwellDetector.detect(points, minDwellMinutes: 20),
        mergeRadiusMeters: 100,
      );
    }
    return _dwellMemo;
  }
  String? _lastDwellSignature; // cache invalidation key

  Future<void> _ensureDwellLabels(List<AggregatedDwell> dwells) async {
    // Cache invalidation: dwells o'zgargandagina ishlaymiz (infinite
    // rebuild loop'dan saqlanish).
    final signature = dwells
        .map(
          (d) =>
              '${d.center.latitude.toStringAsFixed(4)},'
              '${d.center.longitude.toStringAsFixed(4)},'
              '${d.totalDuration.inMinutes}',
        )
        .join('|');
    if (signature == _lastDwellSignature) return;
    _lastDwellSignature = signature;

    for (var i = 0; i < dwells.length; i++) {
      final d = dwells[i];
      final key = 'dwell_$i';
      final desc = await DwellLabelMarker.build(
        label: d.label,
        subtitle: d.dateLabel,
      );
      _dwellLabels[key] = desc;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Provider allaqachon ASC tartibga keltirgan (eski → yangi).
    // start = eng eski (yashil pin), end = eng yangi/hozir (avatar pin).
    final chronological = widget.points;
    final start = chronological.first;
    final end = chronological.last;
    // Harakat yo'li — yupqa chiziq (to'xtashlar alohida marker).
    final polyline = Polyline(
      polylineId: const PolylineId('history'),
      points: chronological.map((p) => p.latLng).toList(),
      color: AppColors.primary,
      width: 3,
    );

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('start'),
        position: start.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
        infoWindow: InfoWindow(
          title: 'Boshlandi',
          snippet: _hhmmDate(start.updatedAt),
        ),
      ),
      Marker(
        markerId: const MarkerId('end'),
        position: end.latLng,
        // Avatar pin — live map bilan bir xil
        icon: widget.avatarMarker ??
            BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
        anchor: const Offset(0.5, 1.0),
        infoWindow: InfoWindow(
          title: 'Hozir',
          snippet: _hhmmDate(end.updatedAt),
        ),
      ),
    };
    final circles = <Circle>{};

    if (widget.stops.isNotEmpty) {
      // ── Backend stop-detection markerlari (asosiy manba) ──
      // Har to'xtash — raqamlangan moviy pin, info'da davomiylik + vaqt.
      for (var i = 0; i < widget.stops.length; i++) {
        final s = widget.stops[i];
        markers.add(
          Marker(
            markerId: MarkerId('stop_${s.id}'),
            position: s.latLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(
              title: '${i + 1}. ${s.durationLabel}',
              snippet: s.timeRange,
            ),
          ),
        );
        circles.add(
          Circle(
            circleId: CircleId('stop_circle_${s.id}'),
            center: s.latLng,
            radius: 40,
            fillColor: AppColors.info.withValues(alpha: 0.15),
            strokeColor: AppColors.info,
            strokeWidth: 2,
          ),
        );
      }
    } else {
      // ── Fallback: client-side dwell detection (memoized, PERF-06) ──
      // Backend stop hali yo'q (yangi feature) yoki eski data uchun.
      final dwells = _memoizedDwells(chronological);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureDwellLabels(dwells);
      });
      for (var i = 0; i < dwells.length; i++) {
        final d = dwells[i];
        final isOpen = widget.openDwellIndex == i;
        final icon = isOpen
            ? _dwellLabels['dwell_$i']
            : BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              );
        markers.add(
          Marker(
            markerId: MarkerId('dwell_$i'),
            position: d.center,
            icon: icon ?? BitmapDescriptor.defaultMarker,
            anchor:
                isOpen ? const Offset(0.5, 1.0) : const Offset(0.5, 0.5),
            consumeTapEvents: true,
            onTap: () => widget.onDwellTap(i),
          ),
        );
        circles.add(
          Circle(
            circleId: CircleId('dwell_circle_$i'),
            center: d.center,
            radius: 50,
            fillColor: AppColors.info.withValues(alpha: 0.15),
            strokeColor: AppColors.info,
            strokeWidth: 2,
          ),
        );
      }
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: end.latLng,
        zoom: 14,
      ),
      polylines: {polyline},
      markers: markers,
      circles: circles,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: widget.onMapCreated,
      onTap: (_) => widget.onMapTap(),
      padding: const EdgeInsets.only(bottom: 180),
    );
  }

  String _hhmmDate(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}, '
      '${dt.day.toString().padLeft(2, '0')}.'
      '${dt.month.toString().padLeft(2, '0')}';
}

// ════════════════════════ TOP BAR ════════════════════════

class _TopBar extends StatelessWidget {
  const _TopBar({required this.childName});

  final String childName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleIconButton(
          icon: Icons.arrow_back,
          onTap: () => context.pop(),
        ),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            elevation: 4,
            shadowColor: Colors.black26,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.lg,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'locationHistory.headerTitle'.tr(),
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    childName,
                    style: AppTextStyles.bodyM.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
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

// ════════════════════════ BOTTOM PANEL ════════════════════════

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.fromDt,
    required this.toDt,
    required this.onCustomDateTap,
    required this.stops,
    required this.onPlaceTap,
    required this.distanceKm,
  });

  final DateTime fromDt;
  final DateTime toDt;
  final VoidCallback onCustomDateTap;
  final List<LocationStop> stops;
  final void Function(LatLng target) onPlaceTap;
  final double distanceKm;

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.'
      '${dt.month.toString().padLeft(2, '0')}.'
      '${(dt.year % 100).toString().padLeft(2, '0')}';

  bool get _isSameDay =>
      fromDt.year == toDt.year &&
      fromDt.month == toDt.month &&
      fromDt.day == toDt.day;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x47000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        MediaQuery.of(context).padding.bottom + AppDimensions.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Premium drag handle.
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // ── Tashrif buyurilgan joylar (backend to'xtashlari) ──
          if (stops.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'locationHistory.places.title'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: stops.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _PlaceCard(
                  index: i,
                  stop: stops[i],
                  onTap: () => onPlaceTap(stops[i].latLng),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.md),
          ],

          // Faqat sana filtri — premium lime pill (3 ta preset chip
          // olib tashlandi, foydalanuvchi so'rovi 4.4.32).
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onCustomDateTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 18,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.date_range_rounded,
                      size: 20,
                      color: AppColors.onPrimary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isSameDay
                          ? _formatDate(fromDt)
                          : '${_formatDate(fromDt)}  —  ${_formatDate(toDt)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          // Stats row — premium pill kartalar.
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.place_rounded,
                  value: 'locationHistory.stats.places'.tr(
                    namedArgs: {'count': '${stops.length}'},
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatItem(
                  icon: Icons.straighten_rounded,
                  value: 'locationHistory.stats.distance'.tr(
                    namedArgs: {'km': distanceKm.toStringAsFixed(1)},
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

class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: AppColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ PLACE CARD ════════════════════════

class _PlaceCard extends ConsumerWidget {
  const _PlaceCard({
    required this.index,
    required this.stop,
    required this.onTap,
  });

  final int index;
  final LocationStop stop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = '${stop.latitude.toStringAsFixed(5)},'
        '${stop.longitude.toStringAsFixed(5)}';
    final address = ref.watch(_placeAddressProvider(key)).valueOrNull;

    final radius = BorderRadius.circular(AppDimensions.radiusM);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 220,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.info,
                        AppColors.info.withValues(alpha: 0.75),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: AppTextStyles.bodyS.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        address ?? 'locationHistory.places.unknown'.tr(),
                        style: AppTextStyles.bodyS.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        stop.durationLabel,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stop.timeRange,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ EMPTY STATE ════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.20),
                    AppColors.primary.withValues(alpha: 0.06),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.route_rounded,
                size: 52,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              'locationHistory.empty.title'.tr(),
              style: AppTextStyles.headlineL.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'locationHistory.empty.subtitle'.tr(),
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
