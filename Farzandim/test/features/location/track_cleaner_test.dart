// TrackCleaner — yurgan yo'l tozalash mantiqini pinlaydi.
//
// Foydalanuvchi shikoyatlari shu testlar bilan qoplangan:
//   • "Uyda yursam ham ko'chada yurgan qilib ko'rsatyapti" → uy blobi BITTA
//     turgan joyga yig'ilishi va 0 metr harakat berishi shart.
//   • "Keraksiz chiziqlar" → vaqt uzilishida trek IKKI segmentga bo'linishi
//     shart (chiziq ulanmasin).

import 'dart:math' as math;

import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:farzandim/features/location/data/services/track_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';

// Toshkent markazi — test uchun baza nuqta.
const _baseLat = 41.311081;
const _baseLng = 69.240562;

/// Bazadan [dxM] (sharq) va [dyM] (shimol) metr siljigan nuqta.
ChildLocation _pt({
  required double dxM,
  required double dyM,
  required DateTime at,
  double accuracy = 10,
}) {
  const mPerDegLat = 111320.0;
  final mPerDegLng = 111320.0 * math.cos(_baseLat * math.pi / 180);
  return ChildLocation(
    latitude: _baseLat + dyM / mPerDegLat,
    longitude: _baseLng + dxM / mPerDegLng,
    accuracy: accuracy,
    updatedAt: at,
  );
}

void main() {
  final t0 = DateTime(2026, 7, 20, 8);

  group('Uy blobi (indoor sochilishi)', () {
    test('8 soat uyda o`tirish → 1 ta turgan joy, 0 metr harakat', () {
      // Har 2 daqiqada bitta nuqta, ~25 m radiusda tarqoq (multipath).
      final pts = <ChildLocation>[];
      for (var k = 0; k < 240; k++) {
        final angle = k * 2.39996; // oltin burchak — tekis sochiladi
        final r = 25.0 * ((k % 7) / 7);
        pts.add(
          _pt(
            dxM: r * math.cos(angle),
            dyM: r * math.sin(angle),
            at: t0.add(Duration(minutes: 2 * k)),
            accuracy: 18, // binoda odatiy "ishonchli lekin noto`g`ri" fix
          ),
        );
      }

      final res = TrackCleaner.process(pts);

      expect(res.stays.length, 1, reason: 'butun blob bitta turgan joy');
      expect(res.movements, isEmpty, reason: 'uyda yurish chizilmasin');
      expect(res.movementMeters, 0, reason: 'arvoh masofa bo`lmasin');
      // Xaritada bitta nuqta ko'rinadi (240 emas).
      expect(res.displayPoints.length, 1);
    });
  });

  group('Haqiqiy safar', () {
    test('6 km to`g`ri yurish → 1 segment, masofa ~6 km', () {
      // Har 30 s da ~40 m (piyoda ~1.3 m/s) → 150 nuqta, 6 km.
      final pts = <ChildLocation>[
        for (var k = 0; k <= 150; k++)
          _pt(
            dxM: 40.0 * k,
            dyM: 0,
            at: t0.add(Duration(seconds: 30 * k)),
          ),
      ];

      final res = TrackCleaner.process(pts);

      expect(res.movements.length, 1, reason: 'uzluksiz safar = 1 segment');
      expect(res.stays, isEmpty);
      // 6000 m ± 5%
      expect(res.movementMeters, closeTo(6000, 300));
    });
  });

  group('Keraksiz chiziqlar (uzilish)', () {
    test('30 daqiqalik uzilish → 2 segment (chiziq ulanmaydi)', () {
      final pts = <ChildLocation>[
        // 1-bo'lak: 10 nuqta, har 30 s da 40 m
        for (var k = 0; k < 10; k++)
          _pt(
            dxM: 40.0 * k,
            dyM: 0,
            at: t0.add(Duration(seconds: 30 * k)),
          ),
        // 30 daqiqa uzilish (telefon o'chgan), keyin uzoqda davom etadi
        for (var k = 0; k < 10; k++)
          _pt(
            dxM: 3000.0 + 40.0 * k,
            dyM: 0,
            at: t0.add(Duration(minutes: 35, seconds: 30 * k)),
          ),
      ];

      final res = TrackCleaner.process(pts);

      expect(res.movements.length, 2, reason: 'uzilishda bo`linishi shart');
      // Ikki bo'lak orasidagi 3 km "sakrash" masofaga QO'SHILMAYDI.
      expect(res.movementMeters, lessThan(1000));
    });

    test('kun almashsa ham bo`linadi', () {
      final pts = <ChildLocation>[
        for (var k = 0; k < 6; k++)
          _pt(
            dxM: 40.0 * k,
            dyM: 0,
            at: t0.add(Duration(seconds: 30 * k)),
          ),
        for (var k = 0; k < 6; k++)
          _pt(
            dxM: 40.0 * k,
            dyM: 200,
            at: t0.add(Duration(days: 1, seconds: 30 * k)),
          ),
      ];
      final res = TrackCleaner.process(pts);
      expect(res.movements.length, 2);
    });
  });

  group('Teleport va buzuq nuqtalar', () {
    test('imkonsiz sakrash (5 km / 2 s) tashlanadi', () {
      final pts = <ChildLocation>[
        _pt(dxM: 0, dyM: 0, at: t0),
        _pt(dxM: 40, dyM: 0, at: t0.add(const Duration(seconds: 30))),
        // Teleport: 5 km narida, 2 soniyada — va keyin qaytadi
        _pt(dxM: 5000, dyM: 0, at: t0.add(const Duration(seconds: 32))),
        _pt(dxM: 80, dyM: 0, at: t0.add(const Duration(seconds: 60))),
        _pt(dxM: 120, dyM: 0, at: t0.add(const Duration(seconds: 90))),
      ];

      final res = TrackCleaner.process(pts);

      // 5 km nuqtasi olib tashlangan → masofa kichik qoladi.
      expect(res.movementMeters, lessThan(500));
    });

    test('qaytmagan tez sakrash — ULANMAYDI, segment kesiladi', () {
      // 3 km sakrash 30 s da (360 km/soat) va u yerdan DAVOM etadi.
      // Chiziq ulansa xaritada 3 km soxta to'g'ri chiziq chiqardi.
      final pts = <ChildLocation>[
        for (var k = 0; k < 6; k++)
          _pt(
            dxM: 40.0 * k,
            dyM: 0,
            at: t0.add(Duration(seconds: 30 * k)),
          ),
        for (var k = 0; k < 6; k++)
          _pt(
            dxM: 3000.0 + 40.0 * k,
            dyM: 0,
            at: t0.add(Duration(seconds: 180 + 30 * k)),
          ),
      ];
      final res = TrackCleaner.process(pts);
      expect(res.movements.length, 2, reason: 'sakrash joyida kesilsin');
      expect(res.movementMeters, lessThan(600));
    });

    test('buzuq nuqtalar (sana yo`q / 0,0) chiqarib tashlanadi', () {
      final pts = <ChildLocation>[
        ChildLocation(latitude: 0, longitude: 0, accuracy: 5, updatedAt: t0),
        ChildLocation(
          latitude: _baseLat,
          longitude: _baseLng,
          accuracy: 5,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        for (var k = 0; k < 6; k++)
          _pt(
            dxM: 40.0 * k,
            dyM: 0,
            at: t0.add(Duration(seconds: 30 * k)),
          ),
      ];
      final res = TrackCleaner.process(pts);
      // Faqat haqiqiy 6 nuqta qoladi (0,0 va 1970 tashlanadi).
      expect(res.movements.length, 1);
      expect(res.movementMeters, closeTo(200, 60));
    });
  });

  group('Aniqlik darvozasi', () {
    test('yomon aniqlikdagi (>25 m) nuqtalar chizilmaydi', () {
      final pts = <ChildLocation>[
        for (var k = 0; k < 8; k++)
          _pt(
            dxM: 40.0 * k,
            dyM: 0,
            at: t0.add(Duration(seconds: 30 * k)),
            accuracy: 5,
          ),
        // Yomon fix — ko'chaning narigi tomonida "sakrash"
        _pt(
          dxM: 150,
          dyM: 400,
          at: t0.add(const Duration(seconds: 255)),
          accuracy: 90,
        ),
      ];
      final res = TrackCleaner.process(pts);
      // 400 m shimolga sakrash chizilmaydi.
      expect(res.movementMeters, lessThan(400));
    });

    test('noma`lum aniqlik (0) ishonchsiz — asosiy o`tishda tashlanadi', () {
      final good = <ChildLocation>[
        for (var k = 0; k < 8; k++)
          _pt(
            dxM: 40.0 * k,
            dyM: 0,
            at: t0.add(Duration(seconds: 30 * k)),
            accuracy: 5,
          ),
      ];
      final withUnknown = <ChildLocation>[
        ...good,
        _pt(
          dxM: 200,
          dyM: 600,
          at: t0.add(const Duration(seconds: 255)),
          accuracy: 0, // noma'lum
        ),
      ];
      final a = TrackCleaner.process(good).movementMeters;
      final b = TrackCleaner.process(withUnknown).movementMeters;
      expect(b, closeTo(a, 1), reason: 'noma`lum aniqlik yo`lni buzmasin');
    });
  });

  group('Tartibsiz kelgan nuqtalar (offline flush)', () {
    test('vaqt bo`yicha saralanadi — chiziq oldinga-orqaga sakramaydi', () {
      final ordered = <ChildLocation>[
        for (var k = 0; k < 10; k++)
          _pt(
            dxM: 40.0 * k,
            dyM: 0,
            at: t0.add(Duration(seconds: 30 * k)),
          ),
      ];
      final shuffled = [...ordered.reversed];

      final a = TrackCleaner.process(ordered).movementMeters;
      final b = TrackCleaner.process(shuffled).movementMeters;
      expect(b, closeTo(a, 1), reason: 'tartib natijaga ta`sir qilmasin');
    });
  });
}
