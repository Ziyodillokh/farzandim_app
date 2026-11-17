// Joylashuv strategiyasi (1.0.20 batareya): rejim almashuvi (statsionar ↔
// safar), tick (eskirgan nuqta, "tirikman"), tarix darvozalari, maktab hududi
// nuqtasini yozish cheklovi va loglarda koordinata yo'qligi.

import 'dart:math' as math;

import 'package:farzandim_child/features/app_restrictions/data/services/school_zone.dart';
import 'package:farzandim_child/features/location/data/services/location_strategy.dart';
import 'package:flutter_test/flutter_test.dart';

const _lat = 41.311081;
const _lng = 69.240562;

/// Haversine (R = 6 371 000 m) bo'yicha 1° kenglik.
const _mPerDegLat = 6371000 * math.pi / 180;

final _t0 = DateTime.utc(2026, 11, 14, 10);

DateTime _at(Duration d) => _t0.add(d);

/// Boshlang'ich nuqtadan shimolga [northM] metr.
LocationSample _s(
  double northM, {
  double acc = 10,
  Duration t = Duration.zero,
  double speed = 0,
  double speedAcc = 0,
}) => LocationSample(
  latitude: _lat + northM / _mPerDegLat,
  longitude: _lng,
  accuracyM: acc,
  at: _at(t),
  speedMps: speed,
  speedAccuracyMps: speedAcc,
);

const _sec = Duration(seconds: 1);
const _min = Duration(minutes: 1);

void main() {
  test(
    'oqim: statsionar — balanced 50 m / 3 daqiqa; safar — GPS 20 m / 20 s',
    () {
      expect(StreamSpec.stationary.highAccuracy, isFalse);
      expect(StreamSpec.stationary.distanceFilterM, 50);
      expect(StreamSpec.stationary.interval, const Duration(minutes: 3));
      expect(StreamSpec.trip.highAccuracy, isTrue);
      expect(StreamSpec.trip.distanceFilterM, 20);
      expect(StreamSpec.trip.interval, const Duration(seconds: 20));
      expect(StreamSpec.of(LocationMode.trip), same(StreamSpec.trip));
      expect(
        StreamSpec.of(LocationMode.stationary),
        same(StreamSpec.stationary),
      );
    },
  );

  test('test yordamchisi: siljish metrda to\'g\'ri', () {
    expect(_s(0).distanceTo(_s(150)), closeTo(150, 0.5));
  });

  group('statsionar → safar', () {
    const stationary = MotionState.stationary();

    test('birinchi aniq nuqta langar bo\'ladi, rejim o\'zgarmaydi', () {
      final m = stationary.onSample(_s(0), _t0);

      expect(m.mode, LocationMode.stationary);
      expect(m.anchor, isNotNull);
    });

    test('langardan ≥150 m siljish — safar', () {
      final m = stationary
          .onSample(_s(0), _t0)
          .onSample(_s(160, t: _min), _at(_min));

      expect(m.mode, LocationMode.trip);
      expect(m.lastMoveAt, _at(_min));
    });

    test('150 m dan kam siljish — statsionar qoladi', () {
      final m = stationary
          .onSample(_s(0), _t0)
          .onSample(_s(140, t: _min), _at(_min));

      expect(m.mode, LocationMode.stationary);
    });

    test('tezlik ≥2.5 m/s — darhol safar', () {
      final m = stationary.onSample(_s(0, speed: 3), _t0);

      expect(m.mode, LocationMode.trip);
    });

    test('tezlik aniqligi tezlikdan katta — safar emas', () {
      final m = stationary.onSample(_s(0, speed: 3, speedAcc: 4), _t0);

      expect(m.mode, LocationMode.stationary);
    });

    test('100 m dan yomon (uyali) nuqta uzoqda bo\'lsa ham rejim va langar '
        'o\'zgarmaydi', () {
      final anchored = stationary.onSample(_s(0), _t0);
      final m = anchored.onSample(_s(2000, acc: 800, t: _min), _at(_min));

      expect(m.mode, LocationMode.stationary);
      expect(m.anchor, same(anchored.anchor));
    });

    test(
      'shovqin himoyasi: noaniq ikki nuqta orasidagi 180 m — safar emas',
      () {
        // 2 × (40 + 60) = 200 m dan kam.
        final m = stationary
            .onSample(_s(0, acc: 40), _t0)
            .onSample(_s(180, acc: 60, t: _min), _at(_min));

        expect(m.mode, LocationMode.stationary);
      },
    );

    test('aniqroq yaqin nuqta langarni aniqlashtiradi', () {
      final better = _s(30, acc: 8, t: _min);
      final m = stationary
          .onSample(_s(0, acc: 60), _t0)
          .onSample(better, _at(_min));

      expect(m.anchor, same(better));
      expect(m.mode, LocationMode.stationary);
    });
  });

  group('safar → statsionar', () {
    MotionState trip() => const MotionState.stationary()
        .onSample(_s(0), _t0)
        .onSample(_s(200, t: _min), _at(_min));

    test('5 daqiqa harakatsiz — statsionarga qaytadi', () {
      final m = trip();

      expect(m.onClock(_at(_min * 5 + _sec * 59)).mode, LocationMode.trip);
      expect(m.onClock(_at(_min * 6)).mode, LocationMode.stationary);
    });

    test('≥25 m siljish kutishni yangilaydi', () {
      // 60 m ≥ max(25, 2 × (10 + 10)).
      final m = trip().onSample(_s(260, t: _min * 4), _at(_min * 4));

      expect(m.lastMoveAt, _at(_min * 4));
      expect(m.onClock(_at(_min * 8)).mode, LocationMode.trip);
      expect(m.onClock(_at(_min * 9)).mode, LocationMode.stationary);
    });

    test('GPS sakrashi (shovqin ichida) harakat sanalmaydi', () {
      // 2 × (10 + 20) = 60 m dan kam — harakat emas.
      final m = trip().onSample(_s(240, acc: 20, t: _min * 4), _at(_min * 4));

      expect(m.lastMoveAt, _at(_min));
      expect(m.onClock(_at(_min * 6)).mode, LocationMode.stationary);
    });

    test('statsionarga qaytganda langar — safarning oxirgi nuqtasi', () {
      final last = _s(210, t: _min * 2);
      final m = trip().onSample(last, _at(_min * 2)).onClock(_at(_min * 7));

      expect(m.mode, LocationMode.stationary);
      expect(m.anchor, same(last));
    });

    test('soat orqaga surilsa safar abadiy qolmaydi', () {
      final m = trip();
      final back = _t0.subtract(const Duration(days: 1));

      final normalized = m.onClock(back);
      expect(normalized.mode, LocationMode.trip);
      expect(normalized.exitAt, back.add(LocationTuning.tripIdleExit));
      expect(
        normalized.onClock(back.add(_min * 5)).mode,
        LocationMode.stationary,
      );
    });
  });

  group('wake (ota-ona xaritani ochdi)', () {
    final anchored = const MotionState.stationary().onSample(_s(0), _t0);

    test(
      'statsionar → 2 daqiqa safar; harakatsiz bo\'lsa 2 daqiqada tugaydi',
      () {
        final held = anchored.hold(_at(_min));

        expect(held.mode, LocationMode.trip);
        expect(held.exitAt, _at(_min * 3));
        // Birinchi nuqta — faqat langar, harakat emas.
        final fixed = held.onSample(_s(5, t: _min), _at(_min));
        expect(fixed.lastMoveAt, isNull);
        expect(fixed.onClock(_at(_min * 3)).mode, LocationMode.stationary);
      },
    );

    test('wake paytida harakat bo\'lsa safar 5 daqiqa davom etadi', () {
      final m = anchored
          .hold(_at(_min))
          .onSample(_s(0, t: _min), _at(_min))
          .onSample(_s(60, t: _min * 2), _at(_min * 2));

      expect(m.lastMoveAt, _at(_min * 2));
      expect(m.onClock(_at(_min * 4)).mode, LocationMode.trip);
      expect(m.onClock(_at(_min * 7)).mode, LocationMode.stationary);
    });

    test('safarda wake — ushlab turish uzayadi, harakat vaqti saqlanadi', () {
      final trip = anchored.onSample(_s(200, t: _min), _at(_min));
      final m = trip.hold(_at(_min * 5));

      expect(m.lastMoveAt, _at(_min));
      expect(m.exitAt, _at(_min * 7));
    });
  });

  group('tarix darvozalari (POST /location)', () {
    const gate = SendGate();

    test('aniqligi 50 m dan yomon nuqta yuborilmaydi', () {
      expect(gate.allows(_s(0, acc: 51), _t0), isFalse);
      expect(gate.allows(_s(0, acc: 0), _t0), isFalse);
      expect(gate.allows(_s(0, acc: 50), _t0), isTrue);
    });

    test('25 m dan kam siljish 15 daqiqa ichida yuborilmaydi', () {
      final sent = gate.sent(_s(0), _t0);

      expect(sent.allows(_s(20, t: _min * 5), _at(_min * 5)), isFalse);
      expect(sent.allows(_s(30, t: _min * 5), _at(_min * 5)), isTrue);
    });

    test('15 daqiqadan keyin siljishsiz ham — tirikman nuqtasi', () {
      final sent = gate.sent(_s(0), _t0);

      expect(sent.allows(_s(5, t: _min * 15), _at(_min * 15)), isTrue);
    });

    test(
      'wake (force) siljishsiz ham yuboriladi, aniqlik darvozasi saqlanadi',
      () {
        final sent = gate.sent(_s(0), _t0);

        expect(sent.allows(_s(3, t: _min), _at(_min), force: true), isTrue);
        expect(
          sent.allows(_s(3, acc: 80, t: _min), _at(_min), force: true),
          isFalse,
        );
      },
    );

    test('eski yoki takror nuqta qayta yuborilmaydi', () {
      final sent = gate.sent(_s(0, t: _min), _at(_min));

      expect(sent.allows(_s(0, t: _min), _at(_min * 20), force: true), isFalse);
      expect(sent.allows(_s(100), _at(_min * 20)), isFalse);
    });
  });

  group('maktab hududi nuqtasi (recordFix cheklovi)', () {
    final recorded = const ZoneThrottle().recorded(_s(0), _t0);

    test('birinchi nuqta yoziladi', () {
      expect(const ZoneThrottle().allows(_s(0), _t0), isTrue);
    });

    test('60 s ichida joyida — yozilmaydi, 60 s dan keyin — yoziladi', () {
      expect(recorded.allows(_s(5, t: _sec * 30), _at(_sec * 30)), isFalse);
      expect(recorded.allows(_s(5, t: _sec * 60), _at(_sec * 60)), isTrue);
    });

    test('max(aniqlik, 25 m) dan ko\'p siljish — darhol yoziladi', () {
      expect(recorded.allows(_s(30, t: _sec * 10), _at(_sec * 10)), isTrue);
      // Aniqlik 50 m: 30 m siljish shovqin ichida.
      expect(
        recorded.allows(_s(30, acc: 50, t: _sec * 10), _at(_sec * 10)),
        isFalse,
      );
    });

    test(
      'yaroqsiz (>150 m) nuqta o\'rniga yaroqli nuqta — darhol yoziladi',
      () {
        final bad = const ZoneThrottle().recorded(_s(0, acc: 900), _t0);

        expect(
          bad.allows(_s(0, acc: 30, t: _sec * 10), _at(_sec * 10)),
          isTrue,
        );
      },
    );

    test('eski nuqta yozilmaydi', () {
      final later = const ZoneThrottle().recorded(_s(0, t: _min), _at(_min));

      expect(later.allows(_s(500), _at(_min * 5)), isFalse);
    });

    test(
      'safarda (har 20 s nuqta, joyida) daqiqasiga ko\'pi bilan bitta commit',
      () {
        var tracker = const LocationTracker();
        var commits = 0;
        for (var i = 0; i < 30; i++) {
          final t = _sec * (20 * i);
          final out = tracker.onSample(_s((i % 2) * 8.0, t: t), now: _at(t));
          tracker = out.tracker;
          if (out.recordZone) commits++;
        }
        // 10 daqiqa → ≤ 10 ta (avval har nuqtada — 30 ta).
        expect(commits, lessThanOrEqualTo(10));
      },
    );
  });

  group('tick', () {
    test('nuqta yo\'q — bitta fix so\'raladi', () {
      expect(const LocationTracker().onTick(_t0).requestFix, isTrue);
    });

    test('nuqta yangi — fix so\'ralmaydi; 10 daqiqadan eski — so\'raladi', () {
      final tracker = const LocationTracker().onSample(_s(0), now: _t0).tracker;

      expect(tracker.onTick(_at(_min * 5)).requestFix, isFalse);
      expect(tracker.onTick(_at(_min * 10)).requestFix, isTrue);
    });

    test(
      'yomon aniqlikdagi nuqta ham yangilik sanaladi (hudud uchun yozilgan)',
      () {
        final out = const LocationTracker().onSample(_s(0, acc: 120), now: _t0);

        expect(out.recordZone, isTrue);
        expect(out.send, isFalse);
        expect(out.tracker.onTick(_at(_min * 5)).requestFix, isFalse);
      },
    );

    test('hudud nuqtasi 5 daqiqalik tick bilan 20 daqiqadan eskirmaydi', () {
      // Bola joyida: oqim nuqta bermaydi (distanceFilter), faqat tick fix'i.
      var tracker = const LocationTracker();
      DateTime? zoneAt;
      var maxAge = Duration.zero;
      for (var i = 0; i <= 36; i++) {
        final now = _at(_min * (5 * i) + _sec * 7 * i); // tick kechikishi
        if (zoneAt != null && now.difference(zoneAt) > maxAge) {
          maxAge = now.difference(zoneAt);
        }
        final tick = tracker.onTick(now);
        tracker = tick.tracker;
        if (!tick.requestFix) continue;
        final fixAt = now.add(_sec * 15); // fix 15 s'da keladi
        final out = tracker.onSample(
          _s(3, acc: 30, t: fixAt.difference(_t0)),
          now: fixAt,
        );
        tracker = out.tracker;
        if (out.recordZone) zoneAt = fixAt;
      }
      expect(maxAge, lessThan(kZoneFixMaxAge));
    });

    test(
      'tirikman: 15 daqiqa o\'tdi, yuborilmagan aniq nuqta bor — yuboriladi',
      () {
        var tracker = const LocationTracker().onSample(_s(0), now: _t0).tracker;
        final quiet = tracker.onSample(
          _s(10, t: _min * 12),
          now: _at(_min * 12),
        );
        expect(quiet.send, isFalse);
        tracker = quiet.tracker;

        final tick = tracker.onTick(_at(_min * 15));

        expect(tick.alive, isNotNull);
        expect(tick.alive!.at, _at(_min * 12));
        expect(tick.tracker.sendGate.lastSentAt, _at(_min * 15));
        // Ikkinchi marta yuborilmaydi.
        expect(tick.tracker.onTick(_at(_min * 31)).alive, isNull);
      },
    );

    test('tirikman: vaqti kelmagan — yo\'q', () {
      final tracker = const LocationTracker()
          .onSample(_s(0), now: _t0)
          .tracker
          .onSample(_s(10, t: _min * 5), now: _at(_min * 5))
          .tracker;

      expect(tracker.onTick(_at(_min * 10)).alive, isNull);
    });

    test('tick safardan chiqishni ham bajaradi (taymer zaxirasi)', () {
      final tracker = const LocationTracker()
          .onSample(_s(0), now: _t0)
          .tracker
          .onSample(_s(300, t: _min), now: _at(_min))
          .tracker;
      expect(tracker.mode, LocationMode.trip);

      expect(
        tracker.onTick(_at(_min * 7)).tracker.mode,
        LocationMode.stationary,
      );
    });

    test('OS keshidagi nuqta: yangi va eng so\'nggi bo\'lsa yaraydi', () {
      final tracker = const LocationTracker()
          .onSample(_s(0, t: _min), now: _at(_min))
          .tracker;

      expect(
        tracker.isFreshCandidate(_s(0, t: _min * 2), _at(_min * 3)),
        isTrue,
      );
      expect(tracker.isFreshCandidate(_s(0), _at(_min * 3)), isFalse);
      expect(
        tracker.isFreshCandidate(_s(0, t: _min * 2), _at(_min * 13)),
        isFalse,
      );
    });

    test('soat orqaga surilsa yangi nuqtalar tashlanmaydi (tarix va hudud '
        'davom etadi)', () {
      final before = const LocationTracker()
          .onSample(_s(0, t: _min * 10), now: _at(_min * 10))
          .tracker;
      const dayBack = Duration(days: -1);

      final out = before.onSample(_s(5, t: dayBack), now: _at(dayBack));

      expect(out.send, isTrue);
      expect(out.recordZone, isTrue);
      expect(out.tracker.lastSampleAt, _at(dayBack));
      expect(out.tracker.isStale(_at(dayBack + _min)), isFalse);
    });

    test('kichik soat tuzatishi (<2 daqiqa) tartibni buzmaydi', () {
      final before = const LocationTracker()
          .onSample(_s(0, t: _min * 10), now: _at(_min * 10))
          .tracker;
      final back = _min * 10 - _sec * 30;

      final out = before.onSample(_s(5, t: back), now: _at(back));

      expect(out.send, isFalse);
      expect(out.recordZone, isFalse);
      expect(out.tracker.lastSampleAt, _at(_min * 10));
    });

    test('eski nuqta rejimni buzmaydi', () {
      final tracker = const LocationTracker()
          .onSample(_s(0, t: _min * 5), now: _at(_min * 5))
          .tracker;

      final out = tracker.onSample(_s(900), now: _at(_min * 6));

      expect(out.tracker.mode, LocationMode.stationary);
      expect(out.tracker.lastSampleAt, _at(_min * 5));
    });
  });

  group('loglar — koordinatasiz', () {
    test('describe/toString koordinata o\'z ichiga olmaydi', () {
      final texts = <String>[];
      var tracker = const LocationTracker();
      final samples = [
        _s(0),
        _s(400, t: _min, speed: 4),
        _s(800, t: _min * 2),
        _s(810, acc: 300, t: _min * 3),
      ];
      for (final s in samples) {
        tracker = tracker.onSample(s, now: s.at).tracker;
        texts
          ..add(s.describe(s.at.add(_sec * 5)))
          ..add(s.toString())
          ..add(tracker.describe(s.at));
      }
      texts.add(
        tracker.onTick(_at(_min * 30)).tracker.describe(_at(_min * 30)),
      );

      final coordinate = RegExp(r'\d{2}\.\d{3,}');
      for (final text in texts) {
        expect(text, isNot(contains('41.3')));
        expect(text, isNot(contains('69.2')));
        expect(coordinate.hasMatch(text), isFalse, reason: text);
      }
    });
  });
}
