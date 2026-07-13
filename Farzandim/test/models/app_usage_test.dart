// AppUsageDay — aggregatsiya, filteredApps (10s threshold + system filtr).
// Ekran-vaqti ko'rinmaslik bug'lari (Parvoz filtri, Chrome <1min) shu
// mantiqda edi — regressiyadan himoya.

import 'package:farzandim/features/app_restrictions/data/models/app_usage.dart';
import 'package:flutter_test/flutter_test.dart';

AppUsageEntry _entry(String pkg, int ms, {String? name}) => AppUsageEntry(
      packageName: pkg,
      appName: name ?? pkg,
      totalTimeMs: ms,
      lastTimeUsed: DateTime(2026, 6, 12, 10),
    );

AppUsageDay _day(List<AppUsageEntry> apps) => AppUsageDay(
      date: '2026-06-12',
      updatedAt: DateTime(2026, 6, 12, 10),
      apps: apps,
    );

void main() {
  group('aggregatedApps', () {
    test('bir paketning 2 yozuvi YIG`ILADI', () {
      final day = _day([
        _entry('com.android.chrome', 30000),
        _entry('com.android.chrome', 45000),
      ]);
      final agg = day.aggregatedApps;
      expect(agg.single.totalTimeMs, 75000);
    });

    test('vaqt bo`yicha kamayish tartibida', () {
      final day = _day([
        _entry('a', 10000),
        _entry('b', 99000),
        _entry('c', 50000),
      ]);
      expect(
        day.aggregatedApps.map((e) => e.packageName),
        ['b', 'c', 'a'],
      );
    });
  });

  group('filteredApps (ko`rinish qoidalari)', () {
    test('40 soniya (haqiqiy foydalanish) — KO`RINADI (10s chegara)', () {
      // Avval chegara 60s edi va Chrome'ning 40s sessiyasi umuman ko`rinmasdi
      // (ekran vaqti bug`i). 10s chegarasida haqiqiy foydalanish ko`rinadi.
      final day = _day([_entry('com.android.chrome', 40000)]);
      expect(day.filteredApps, hasLength(1));
    });

    test('roppa-rosa 10 soniya — KO`RINADI (chegara inclusive)', () {
      final day = _day([_entry('com.android.chrome', 10000)]);
      expect(day.filteredApps, hasLength(1));
    });

    test('Parvoz (com.farzandim.*) — KO`RINADI (eski filtr bug`i)', () {
      final day = _day([
        _entry('com.farzandim.farzandim_child', 120000, name: 'Parvoz'),
      ]);
      expect(day.filteredApps, hasLength(1));
    });

    test('10 soniyadan KAM (tasodifiy ochilish) — ko`rinmaydi', () {
      final day = _day([_entry('com.example.app', 5000)]);
      expect(day.filteredApps, isEmpty);
    });

    test('launcher/systemUI/klaviatura — ko`rinmaydi', () {
      final day = _day([
        _entry('com.miui.home', 500000),
        _entry('com.android.systemui', 500000),
        _entry('com.samsung.android.honeyboard', 500000),
        _entry('com.instagram.android', 90000),
      ]);
      expect(
        day.filteredApps.map((e) => e.packageName),
        ['com.instagram.android'],
      );
    });
  });

  group('AppUsageEntry.fromMap', () {
    test('epoch millis lastTimeUsed', () {
      final e = AppUsageEntry.fromMap(const {
        'packageName': 'p',
        'appName': 'P',
        'totalTimeMs': 1000,
        'lastTimeUsed': 1760000000000,
      });
      expect(e.lastTimeUsed.millisecondsSinceEpoch, 1760000000000);
    });

    test('ISO string lastTimeUsed', () {
      final e = AppUsageEntry.fromMap(const {
        'packageName': 'p',
        'appName': 'P',
        'totalTimeMs': 1000,
        'lastTimeUsed': '2026-06-12T10:00:00.000Z',
      });
      expect(e.lastTimeUsed.toUtc().hour, 10);
    });

    test('null/buzuq maydonlar default bilan parse bo`ladi', () {
      final e = AppUsageEntry.fromMap(const {});
      expect(e.packageName, '');
      expect(e.totalTimeMs, 0);
    });
  });
}
