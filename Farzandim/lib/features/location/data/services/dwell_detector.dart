// Bola uzoq to'xtagan joylarni topadi: `detect()` ketma-ket nuqtalarni
// klasterlab har tashrifni alohida beradi, `aggregateByLocation()` bir
// joyga bir necha tashrifni bitta yozuvga yig'adi (masalan maktab:
// 08-13 va 16-18).

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

@immutable
class DwellPoint {
  const DwellPoint({
    required this.center,
    required this.startTime,
    required this.endTime,
    required this.pointCount,
  });

  final LatLng center;
  final DateTime startTime;
  final DateTime endTime;
  final int pointCount;

  Duration get duration => endTime.difference(startTime);
}

/// Bir xil joyga bir necha marta tashrif tushgan dwell'lar yig'masi.
@immutable
class AggregatedDwell {
  const AggregatedDwell({required this.center, required this.visits});

  final LatLng center;
  final List<DwellPoint> visits; // xronologik tartibda

  Duration get totalDuration {
    var total = Duration.zero;
    for (final v in visits) {
      total += v.duration;
    }
    return total;
  }

  /// Ko'p qatorli label: har tashrif "08:00–13:00 (5 s)" ko'rinishida,
  /// bir nechta bo'lsa oxirida jami vaqt qatori.
  String get label {
    final lines = <String>[];
    for (final v in visits) {
      final s = _hhmm(v.startTime);
      final e = _hhmm(v.endTime);
      lines.add('$s–$e (${_formatHm(v.duration)})');
    }
    if (visits.length > 1) {
      lines.add(
        'locationHistory.dwell.total'.tr(
          namedArgs: {'duration': _formatHm(totalDuration)},
        ),
      );
    }
    return lines.join('\n');
  }

  /// Bitta sana — eng birinchi visit'dan.
  String get dateLabel {
    final dt = visits.first.startTime;
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${(dt.year % 100).toString().padLeft(2, '0')}';
  }

  static String _hhmm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  /// "5 s 30 daq" / "45 daq" / "2 s" formatlari.
  static String _formatHm(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) {
      return 'locationHistory.duration.minutes'.tr(namedArgs: {'m': '$m'});
    }
    if (m == 0) {
      return 'locationHistory.duration.hours'.tr(namedArgs: {'h': '$h'});
    }
    return 'locationHistory.duration.hoursMinutes'.tr(
      namedArgs: {'h': '$h', 'm': '$m'},
    );
  }
}

class DwellDetector {
  DwellDetector._();

  /// Tarixdagi dwell joylarni topish.
  ///
  /// `radiusMeters` — cluster radiusi (default 50m).
  /// `minDwellMinutes` — minimal to'xtagan vaqt (default 20 daq).
  /// `points` — chronological ASC tartibida bo'lishi shart.
  static List<DwellPoint> detect(
    List<ChildLocation> points, {
    double radiusMeters = 50,
    int minDwellMinutes = 20,
  }) {
    if (points.length < 2) return const [];

    final dwells = <DwellPoint>[];
    var clusterStart = 0;

    for (var i = 1; i < points.length; i++) {
      final dist = _haversineMeters(
        points[clusterStart].latitude,
        points[clusterStart].longitude,
        points[i].latitude,
        points[i].longitude,
      );
      if (dist > radiusMeters) {
        _addIfQualifies(dwells, points, clusterStart, i - 1, minDwellMinutes);
        clusterStart = i;
      }
    }
    _addIfQualifies(
      dwells,
      points,
      clusterStart,
      points.length - 1,
      minDwellMinutes,
    );
    return dwells;
  }

  /// Bir xil joydagi visit'larni yig'ish. `mergeRadiusMeters` ichida
  /// bo'lgan barcha dwell'lar bir `AggregatedDwell`'ga birlashtiriladi.
  ///
  /// Misol: bola maktabga 08:00–13:00 va 16:00–18:00 borgan bo'lsa,
  /// bitta marker chiqadi — "2 visits, 7 soat jami".
  static List<AggregatedDwell> aggregateByLocation(
    List<DwellPoint> dwells, {
    double mergeRadiusMeters = 100,
  }) {
    if (dwells.isEmpty) return const [];

    final groups = <List<DwellPoint>>[];

    for (final d in dwells) {
      var added = false;
      for (final g in groups) {
        final firstCenter = g.first.center;
        final dist = _haversineMeters(
          firstCenter.latitude,
          firstCenter.longitude,
          d.center.latitude,
          d.center.longitude,
        );
        if (dist <= mergeRadiusMeters) {
          g.add(d);
          added = true;
          break;
        }
      }
      if (!added) {
        groups.add([d]);
      }
    }

    return groups.map((visits) {
      // Markaz — barcha tashriflar markazlarining o'rtachasi.
      var sumLat = 0.0;
      var sumLng = 0.0;
      for (final v in visits) {
        sumLat += v.center.latitude;
        sumLng += v.center.longitude;
      }
      final n = visits.length;
      visits.sort((a, b) => a.startTime.compareTo(b.startTime));
      return AggregatedDwell(
        center: LatLng(sumLat / n, sumLng / n),
        visits: visits,
      );
    }).toList();
  }

  static void _addIfQualifies(
    List<DwellPoint> out,
    List<ChildLocation> points,
    int startIdx,
    int endIdx,
    int minMinutes,
  ) {
    if (endIdx <= startIdx) return;
    final start = points[startIdx].updatedAt;
    final end = points[endIdx].updatedAt;
    final dur = end.difference(start);
    if (dur.inMinutes < minMinutes) return;

    var sumLat = 0.0;
    var sumLng = 0.0;
    for (var i = startIdx; i <= endIdx; i++) {
      sumLat += points[i].latitude;
      sumLng += points[i].longitude;
    }
    final n = endIdx - startIdx + 1;
    out.add(
      DwellPoint(
        center: LatLng(sumLat / n, sumLng / n),
        startTime: start,
        endTime: end,
        pointCount: n,
      ),
    );
  }

  /// Haversine formula — ikki lat/lng orasidagi metrlardagi masofa.
  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthM = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthM * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}
