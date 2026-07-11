// Tarix xarita qatlami — flutter_map (kalitsiz, boy plitka). Google Maps'дан
// ko'chirildi: markerlar endi oddiy widget (BitmapDescriptor/InfoWindow shart
// emas), avatar to'g'ridan-to'g'ri `ChildAvatar`. Plitka — `mapTileUrl` (jonli
// xarita bilan bir xil: Mapbox streets / CARTO Voyager).
part of 'location_history_screen.dart';

// ════════════════════════ MAP LAYER ════════════════════════

class _MapLayer extends StatefulWidget {
  const _MapLayer({
    required this.points,
    required this.stops,
    required this.child,
    required this.controller,
    required this.openDwellIndex,
    required this.onDwellTap,
    required this.onMapTap,
    required this.onMapReady,
  });

  final List<ChildLocation> points;
  final List<LocationStop> stops;

  /// Oxirgi nuqta pin'i uchun bola (avatar). `null` bo'lsa fallback pin.
  final Child? child;
  final MapController controller;
  final int? openDwellIndex;
  final void Function(int idx) onDwellTap;
  final VoidCallback onMapTap;
  final VoidCallback onMapReady;

  @override
  State<_MapLayer> createState() => _MapLayerState();
}

class _MapLayerState extends State<_MapLayer> {
  // PERF-06: dwell-klasterlash (O(n²)) natijasini keshlaymiz — points identity
  // barqaror (parent memoize qiladi), har rebuild'да qayta ishlamasin.
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

  ll.LatLng _ll(double lat, double lng) => ll.LatLng(lat, lng);

  @override
  Widget build(BuildContext context) {
    // Provider ASC tartibда (eski → yangi): start = eng eski, end = hozir.
    final chronological = widget.points;
    final start = chronological.first;
    final end = chronological.last;
    final linePoints = [
      for (final p in chronological) _ll(p.latitude, p.longitude),
    ];

    final circles = <CircleMarker>[];
    final markers = <Marker>[];

    if (widget.stops.isNotEmpty) {
      // ── Backend stop-detection markerlari (asosiy manba) ──
      for (var i = 0; i < widget.stops.length; i++) {
        final s = widget.stops[i];
        final at = _ll(s.latitude, s.longitude);
        circles.add(
          CircleMarker(
            point: at,
            radius: 40,
            useRadiusInMeter: true,
            color: AppColors.info.withValues(alpha: 0.15),
            borderColor: AppColors.info,
            borderStrokeWidth: 2,
          ),
        );
        markers.add(
          Marker(point: at, child: _StopPin(number: i + 1)),
        );
      }
    } else {
      // ── Fallback: client-side dwell detection (memoized) ──
      final dwells = _memoizedDwells(chronological);
      for (var i = 0; i < dwells.length; i++) {
        final d = dwells[i];
        final at = _ll(d.center.latitude, d.center.longitude);
        final isOpen = widget.openDwellIndex == i;
        circles.add(
          CircleMarker(
            point: at,
            radius: 50,
            useRadiusInMeter: true,
            color: AppColors.info.withValues(alpha: 0.15),
            borderColor: AppColors.info,
            borderStrokeWidth: 2,
          ),
        );
        markers.add(
          Marker(
            point: at,
            width: isOpen ? 190 : 30,
            height: isOpen ? 76 : 30,
            alignment: isOpen ? Alignment.bottomCenter : Alignment.center,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onDwellTap(i),
              child: isOpen
                  ? _DwellLabel(label: d.label, subtitle: d.dateLabel)
                  : const _DwellDot(),
            ),
          ),
        );
      }
    }

    // Start (yashil) + end (avatar) — oxirida qo'shiladi, ustida turadi.
    markers.addAll([
      Marker(
        point: _ll(start.latitude, start.longitude),
        width: 22,
        height: 22,
        child: const _StartDot(),
      ),
      Marker(
        point: _ll(end.latitude, end.longitude),
        width: 54,
        height: 66,
        alignment: Alignment.topCenter,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: _HistoryAvatarPin(child: widget.child),
        ),
      ),
    ]);

    return FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
        initialCenter: _ll(end.latitude, end.longitude),
        initialZoom: 14,
        minZoom: 3,
        maxZoom: 18,
        onMapReady: widget.onMapReady,
        onTap: (_, __) => widget.onMapTap(),
      ),
      children: [
        TileLayer(
          urlTemplate: mapTileUrl,
          userAgentPackageName: kMapUserAgent,
        ),
        if (linePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: linePoints,
                color: AppColors.primary,
                strokeWidth: 4,
              ),
            ],
          ),
        CircleLayer(circles: circles),
        MarkerLayer(markers: markers),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          showFlutterMapAttribution: false,
          attributions: [TextSourceAttribution(mapAttribution)],
        ),
      ],
    );
  }
}

// ════════════════════════ MARKER WIDGETLARI ════════════════════════

/// Yo'l boshi — yashil nuqta (oq halqa).
class _StartDot extends StatelessWidget {
  const _StartDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

/// Raqamlangan to'xtash pini (moviy doira + oq raqam).
class _StopPin extends StatelessWidget {
  const _StopPin({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.info,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Yopiq dwell — kichik moviy nuqta (bosilса ochiladi).
class _DwellDot extends StatelessWidget {
  const _DwellDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.info,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

/// Ochiq dwell — yorliq (davomiylik + sana) pufakchasi.
class _DwellLabel extends StatelessWidget {
  const _DwellLabel({required this.label, required this.subtitle});

  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyS.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        // Pastga ishora — moviy uchburchak dumcha.
        CustomPaint(size: const Size(14, 8), painter: _DwellTailPainter()),
      ],
    );
  }
}

/// Dwell yorlig'ining pastki uchburchagi.
class _DwellTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Oxirgi nuqta (hozir) — oq halqада bola avatari.
class _HistoryAvatarPin extends StatelessWidget {
  const _HistoryAvatarPin({required this.child});

  final Child? child;

  @override
  Widget build(BuildContext context) {
    final c = child;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: c != null
          ? ChildAvatar(child: c, size: 40, showBorder: false)
          : Icon(
              SolarIconsBold.mapPoint,
              size: 34,
              color: AppColors.accent,
            ),
    );
  }
}
