// Backend stop-detection topgan to'xtagan joy: bola bir joyda bir necha
// daqiqa turganda bitta yozuv. Xaritada marker sifatida ko'rsatiladi,
// harakat esa alohida polyline bilan chiziladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:latlong2/latlong.dart' show LatLng;

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
      // Backend UTC ("Z") qaytaradi — .toLocal() qilmasak to'xtash
      // vaqtlari 5 soat orqada ko'rinadi.
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

  /// Hali shu yerda (leftAt hali kelmagan).
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
