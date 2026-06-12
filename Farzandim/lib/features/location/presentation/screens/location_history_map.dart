// ARCH-13: monolit ekran fayli `part` fayllarga bo'lindi — private nomlar
// va vizual xulq o'zgarmagan, faqat fayl tashkiloti.
part of 'location_history_screen.dart';

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
        DwellDetector.detect(points),
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
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'locationHistory.markerStart'.tr(),
          snippet: _hhmmDate(start.updatedAt),
        ),
      ),
      Marker(
        markerId: const MarkerId('end'),
        position: end.latLng,
        // Avatar pin — live map bilan bir xil
        icon:
            widget.avatarMarker ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'location.command.now'.tr(),
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
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
        markers.add(
          Marker(
            markerId: MarkerId('dwell_$i'),
            position: d.center,
            icon: icon ?? BitmapDescriptor.defaultMarker,
            anchor: isOpen ? const Offset(0.5, 1) : const Offset(0.5, 0.5),
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
      initialCameraPosition: CameraPosition(target: end.latLng, zoom: 14),
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
