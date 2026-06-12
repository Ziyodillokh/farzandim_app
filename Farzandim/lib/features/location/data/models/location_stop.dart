// ─────────────────────────────────────────────────────────────────────
// LocationStop — backend stop-detection topgan to'xtagan joy (Sprint 7)
// ─────────────────────────────────────────────────────────────────────
//
// Backend GET /api/children/:childId/location/stops qaytaradi. Bola bir
// joyda ≥2.5 daqiqa turganda bitta yozuv. Xaritada marker sifatida
// ko'rsatiladi (harakat esa alohida `locations` polyline — yupqa chiziq).

import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationStop {
  const LocationStop({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.arrivedAt,
    required this.durationSec,
    required this.pointCount,
    this.leftAt,
  });

  factory LocationStop.fromBackendJson(Map<String, dynamic> json) {
    return LocationStop(
      id: json['id'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      // Backend UTC ("Z") — .toLocal()'siz to'xtash vaqtlari 5 soat orqada
      // ko'rinardi (P0-5).
      arrivedAt:
          (DateTime.tryParse(json['arrivedAt'] as String? ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0))
              .toLocal(),
      leftAt: json['leftAt'] != null
          ? DateTime.tryParse(json['leftAt'] as String)?.toLocal()
          : null,
      durationSec: (json['durationSec'] as num?)?.toInt() ?? 0,
      pointCount: (json['pointCount'] as num?)?.toInt() ?? 1,
    );
  }

  final String id;
  final double latitude;
  final double longitude;
  final DateTime arrivedAt;
  final DateTime? leftAt;
  final int durationSec;
  final int pointCount;

  LatLng get latLng => LatLng(latitude, longitude);

  /// Hali shu yerdami (leftAt yo'q yoki juda yaqin).
  bool get isOngoing => leftAt == null;

  static String _hhmm(DateTime d) {
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  /// "08:00 – 13:00".
  String get timeRange {
    final start = _hhmm(arrivedAt);
    final end = leftAt != null ? _hhmm(leftAt!) : null;
    return end != null ? '$start – $end' : start;
  }

  /// "2 s 30 daq" / "45 daq" / "3 s".
  String get durationLabel {
    final h = durationSec ~/ 3600;
    final m = (durationSec % 3600) ~/ 60;
    if (h == 0) return '$m daq';
    if (m == 0) return '$h s';
    return '$h s $m daq';
  }
}
