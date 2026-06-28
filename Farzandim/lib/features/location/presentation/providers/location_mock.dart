// ─────────────────────────────────────────────────────────────────────
// location_mock.dart — FAQAT UI KO'RSATISH UCHUN soxta (mock) joylashuv data
// ─────────────────────────────────────────────────────────────────────
//
// ⚠️ DIQQAT: bu HAQIQIY ma'lumot EMAS. `kLocationMock = true` bo'lganda
// joylashuv ekrani (xarita + marker + manzil + "Harakatlar tarixi") to'liq
// to'ldirilgan holda ko'rinishi uchun soxta data qaytariladi — bola hali
// joylashuv yubormaganida ham UI'ni ko'rish/ko'rsatish mumkin.
//
// Ishlatib bo'lgach `kLocationMock = false` qiling (yoki bu faylni o'chiring +
// provayderlardagi short-circuit'larni olib tashlang). Prod'da HAR DOIM false.

import 'package:farzandim/features/geo_zones/data/models/geo_zone.dart';
import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:farzandim/features/location/data/models/location_stop.dart';

/// Mock rejim yoqilganmi. UI'ni ko'rish uchun `true`, prod uchun `false`.
const bool kLocationMock = false;

// Toshkent — Mirzo Ulug'bek atrofi (namuna koordinatalar). Uy → Maktab →
// Hozir BIR yo'nalishda (shimol-sharqqa) joylashgan — yo'l orqaga qaytmasin,
// mantiqiy ko'rinsin va avatar (hozir) yo'lning oxirida tursin.
const double _homeLat = 41.3280; // Uy (pastda)
const double _homeLng = 69.2785;
const double _schoolLat = 41.3322; // Maktab (o'rtada)
const double _schoolLng = 69.2840;
const double _nowLat = 41.3362; // hozir (yuqorida, ko'chada — avatar shu yerda)
const double _nowLng = 69.2888;

/// Bugungi sana uchun `soat:daqiqa` vaqt yaratadi.
DateTime _todayAt(int h, int m) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

/// Bola joriy joylashuvi (ko'chada, turibdi, yangi fix).
ChildLocation mockChildLocation() => ChildLocation(
  latitude: _nowLat,
  longitude: _nowLng,
  accuracy: 12,
  updatedAt: DateTime.now().subtract(const Duration(seconds: 40)),
  speed: 0,
);

/// Bugungi yo'l tayanch nuqtalari (Uy → Maktab → hozir). Oraliqni OSRM
/// ko'chalar bo'ylab to'ldiradi — shuning uchun faqat 3 ta tayanch yetarli.
List<ChildLocation> mockTrack() {
  ChildLocation p(double lat, double lng, int h, int m) => ChildLocation(
    latitude: lat,
    longitude: lng,
    accuracy: 12,
    updatedAt: _todayAt(h, m),
    speed: 1.2,
  );
  return [
    p(_homeLat, _homeLng, 8, 30),
    p(_schoolLat, _schoolLng, 9, 30),
    p(_nowLat, _nowLng, 10, 30),
  ];
}

/// Bugungi to'xtashlar — "Harakatlar tarixi" timeline.
/// Uyda (08:30→09:00), Maktabda (09:30→10:00), hozir ko'chada (10:30—).
List<LocationStop> mockStops() => [
  LocationStop(
    id: 'mock-home',
    latitude: _homeLat,
    longitude: _homeLng,
    arrivedAt: _todayAt(8, 30),
    leftAt: _todayAt(9, 0),
    durationSec: 30 * 60,
    pointCount: 24,
  ),
  LocationStop(
    id: 'mock-school',
    latitude: _schoolLat,
    longitude: _schoolLng,
    arrivedAt: _todayAt(9, 30),
    leftAt: _todayAt(10, 0),
    durationSec: 30 * 60,
    pointCount: 18,
  ),
  LocationStop(
    id: 'mock-now',
    latitude: _nowLat,
    longitude: _nowLng,
    arrivedAt: _todayAt(10, 30),
    durationSec: DateTime.now().difference(_todayAt(10, 30)).inSeconds.abs(),
    pointCount: 6,
  ),
];

/// Mock geo-zonalar — Uy + Maktab (to'xtashlar shu zonalarga moslanadi →
/// "Uy"/"Maktab" nomi + "Bordi" belgisi chiqadi).
List<GeoZone> mockZones(String childId) {
  final now = DateTime.now();
  GeoZone z(String id, String name, GeoZoneType type, double lat, double lng) =>
      GeoZone(
        id: id,
        parentUid: 'mock',
        childId: childId,
        name: name,
        type: type,
        latitude: lat,
        longitude: lng,
        radiusMeters: 160,
        notifyOnEnter: true,
        notifyOnExit: true,
        createdAt: now,
        updatedAt: now,
      );
  return [
    z('mock-zone-home', 'Uy', GeoZoneType.home, _homeLat, _homeLng),
    z('mock-zone-school', 'Maktab', GeoZoneType.school, _schoolLat, _schoolLng),
  ];
}

/// Mock manzil — pastki "qayerda" kartasi (rasmga mos).
const String mockAddress = 'Mirzo ulugbek, 12 uy';

/// Mock timeline ko'rinishi (rasmga 1:1): joy nomi + ko'cha + "Kechikdi"mi.
/// `now`(10:30)=Noma'lum/Bordi, `school`(09:30)=Maktabda/Kechikdi,
/// `home`(08:30)=Uyda/Bordi.
({String place, String subtitle, bool late}) mockStopDisplay(String id) {
  switch (id) {
    case 'mock-school':
      return (place: 'Maktabda', subtitle: 'Alisher Navoiy, 45 uy', late: true);
    case 'mock-now':
      return (
        place: "Noma'lum",
        subtitle: 'Alisher Navoiy, 45 uy',
        late: false,
      );
    case 'mock-home':
    default:
      return (place: 'Uyda', subtitle: 'Alisher Navoiy, 45 uy', late: false);
  }
}
