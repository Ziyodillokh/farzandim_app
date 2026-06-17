import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_shadows.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/polling.dart' show keepAliveFor;
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
import 'package:google_maps_flutter/google_maps_flutter.dart';

part 'location_history_map.dart';
part 'location_history_widgets.dart';

/// To'xtagan joy manzili (reverse geocoding) — "lat,lng" kalit, keshli.
final _placeAddressProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, latLng) async {
      // autoDispose + qisqa kesh — har koordinata abadiy keshda qolib
      // xotira o'sib ketmasin; ekran ochiq turganda kesh yetarli.
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
/// Tarix backend'dan tanlangan sana oralig'i bo'yicha yuklanadi.
/// Yuqorida header, o'rtada xarita (polyline + start/end markerlar,
/// kamera avtomatik moslanadi), pastda sana tanlash va statistika.
class LocationHistoryScreen extends ConsumerStatefulWidget {
  const LocationHistoryScreen({required this.childId, super.key});

  /// Qaysi bolaning tarixi ko'rsatiladi.
  final String childId;

  @override
  ConsumerState<LocationHistoryScreen> createState() =>
      _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends ConsumerState<LocationHistoryScreen> {
  /// Tanlangan vaqt oralig'i — default bugungi kun.
  late DateTime _fromDt;
  late DateTime _toDt;

  GoogleMapController? _mapController;
  BitmapDescriptor? _avatarMarker;
  int? _openDwellIndex; // tap-to-toggle: null = barchasi yopiq

  // _cleanTrack va masofa hisobini memoize qilamiz — aks holda har
  // setState'da (dwell tap, avatar, sana) qayta hisoblanardi. Provider
  // qiymati o'zgarmasa List identity bir xil; barqaror identity
  // _MapLayer'dagi dwell keshiga ham asos bo'ladi.
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
          colorScheme:
              (AppColors.isDark
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
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(childByIdProvider(widget.childId));
    final childName = child?.name ?? 'locationHistory.fallbackChildName'.tr();

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
    // Trek bo'ylab kirilgan ko'cha nomlari — sheet builder ichida emas,
    // shu yerda (build) o'qiymiz (ref.watch faqat build'da chaqirilsin).
    final streets =
        ref.watch(traversedStreetsProvider(query)).valueOrNull ??
        const <String>[];

    // Tarix nuqtalarini tozalash — yomon-aniqlik fix va statsionar jitter
    // klasterlari olib tashlanadi (zigzag/soxta "borib-kelish" + shishgan
    // masofa yo'qoladi). Backend yangi data'ni filtrlaydi; bu eski data'ni
    // ham toza ko'rsatadi.
    final track = _memoizedTrack(
      historyAsync.valueOrNull ?? const <ChildLocation>[],
    );

    // Oxirgi nuqta pin'i uchun avatar marker.
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
            // Xarita qatlami (to'liq ekran).
            historyAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: AppColors.accent),
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
                      _openDwellIndex = _openDwellIndex == idx ? null : idx;
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

            // Bottom sheet: TORTILADIGAN — pastga tortib xaritani ko'rsa
            // bo'ladi, tepaga tortib + scroll bilan ko'chalar o'qiladi.
            // (Avval Positioned panel cheksiz o'sib xaritani to'sib qo'yardi.)
            DraggableScrollableSheet(
              initialChildSize: 0.40,
              minChildSize: 0.13,
              maxChildSize: 0.92,
              snap: true,
              snapSizes: const [0.40],
              builder: (context, scrollController) => _BottomPanel(
                scrollController: scrollController,
                fromDt: _fromDt,
                toDt: _toDt,
                onCustomDateTap: _pickDateRange,
                stops: stops,
                streets: streets,
                onPlaceTap: _goToStop,
                distanceKm: _distanceKmMemo,
              ),
            ),

            // Yuqori panel (orqaga + sarlavha) — sheet USTIDA, doim bosiladi.
            Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: _TopBar(childName: childName),
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
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  /// Tarix nuqtalarini tozalaydi: aniqligi yomon (>100m) fix'lar
  /// tashlanadi, oxirgi nuqtadan <25m masofadagilar yutiladi (statsionar
  /// GPS jitter — soxta zigzag va shishgan masofa oldini oladi). Backend
  /// yangi data'ni o'zi filtrlaydi; bu eski data'ni ham toza ko'rsatadi.
  List<ChildLocation> _cleanTrack(List<ChildLocation> points) {
    // Trek chizig'i uchun aniqlik talabi qattiqroq (60m) — past aniqlikdagi
    // nuqtalar chiziqni yon-veriga "sochib" yuboradi.
    const maxAccuracyM = 60.0;
    const minGapM = 8.0;
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
    // GPS "spike" (A→B→A sakrash) chiziqlarni ko'paytirib ko'rsatadi:
    // o'rtadagi nuqta chetga otilib qaytgan bo'lsa olib tashlaymiz.
    if (cleaned.length < 3) return cleaned;
    final smoothed = <ChildLocation>[cleaned.first];
    for (var i = 1; i < cleaned.length - 1; i++) {
      final outM = _haversineKm(smoothed.last, cleaned[i]) * 1000;
      final backM = _haversineKm(smoothed.last, cleaned[i + 1]) * 1000;
      final isSpike = outM > 40 && backM < 15;
      if (!isSpike) smoothed.add(cleaned[i]);
    }
    smoothed.add(cleaned.last);
    return smoothed;
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

    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) *
            math.sin(dLng / 2) *
            math.cos(lat1) *
            math.cos(lat2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthKm * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}
