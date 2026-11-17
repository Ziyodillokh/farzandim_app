// School Mode qurilmada: hudud qarori (gisterezis, fail-closed), reja
// qo'llanishi (maktab bloki, toifalar, ruxsat etilganlar), oflayn kesh va
// server jadvalidagi `schoolMode` tahlili.

import 'package:farzandim_child/features/app_restrictions/data/services/restriction_plan.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/school_zone.dart';
import 'package:farzandim_child/features/schedules/data/models/schedule.dart';
import 'package:farzandim_child/features/schedules/data/models/school_mode_meta.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _zone = SchoolZone(
  latitude: 41.311081,
  longitude: 69.240562,
  radiusM: 100,
);

/// Maktab markazidan shimolga [meters] metr (1° kenglik ≈ 111 320 m).
ZoneFix _fixAt(double meters, {double accuracy = 15, required DateTime at}) =>
    ZoneFix(
      latitude: _zone.latitude + meters / 111320,
      longitude: _zone.longitude,
      accuracyM: accuracy,
      at: at,
    );

Schedule _schoolRoutine({
  SchoolZone? zone,
  List<String> apps = const ['com.game'],
}) => Schedule.fromBackendJson({
  'id': 'school-mode-2026-11-12-1',
  'title': 'Maktab (School Mode)',
  'type': 'SCHOOL',
  'startHour': 8,
  'startMinute': 0,
  'endHour': 12,
  'endMinute': 30,
  'weekdays': [4],
  'isActive': true,
  'blockedApps': apps,
  'source': 'SCHOOL_MODE',
  'schoolMode': {
    'blockedCategories': ['GAME', 'SOCIAL'],
    'allowedApps': ['  Kundalik  UZ '],
    'zone': zone?.toJson(),
  },
});

RestrictionPlan _plan(
  List<Schedule> routines, {
  List<String> fullBlocks = const [],
  String planDay = '2026-11-12',
}) => RestrictionPlan(
  fullBlocks: fullBlocks,
  limitEntries: const ['com.youtube:30'],
  policies: const [],
  routines: routines,
  blockAll: false,
  planDay: planDay,
);

/// Toshkent devor vaqti → lahza (test mashinasi vaqt mintaqasidan qat'i nazar).
DateTime _tkt(int y, int m, int d, int h, [int min = 0]) =>
    DateTime.utc(y, m, d, h, min).subtract(const Duration(hours: 5));

void main() {
  // Payshanba (ISO 4), 10:00 Toshkent.
  final lesson = _tkt(2026, 11, 12, 10);

  group('decideZone', () {
    test('hududda: radius + aniqlik ichida', () {
      final d = decideZone(
        zone: _zone,
        fix: _fixAt(110, at: lesson),
        memory: const ZoneMemory(),
        now: lesson,
        locationOn: true,
      );

      expect(d.inside, isTrue);
      expect(d.memory.inside, isTrue);
    });

    test(
      'hech qachon hududda bo\'lmagan (uydagi) telefon — darhol tashqarida',
      () {
        final d = decideZone(
          zone: _zone,
          fix: _fixAt(900, at: lesson),
          memory: const ZoneMemory(),
          now: lesson,
          locationOn: true,
        );

        expect(d.inside, isFalse);
      },
    );

    test(
      'maktabdan chiqish: 3 daqiqa davomida tashqarida bo\'lsagina blok yechiladi',
      () {
        var memory = const ZoneMemory(inside: true);
        ZoneDecision step(DateTime now) {
          final d = decideZone(
            zone: _zone,
            fix: _fixAt(400, at: now),
            memory: memory,
            now: now,
            locationOn: true,
          );
          memory = d.memory;
          return d;
        }

        expect(step(lesson).inside, isTrue);
        expect(step(lesson.add(const Duration(minutes: 2))).inside, isTrue);
        expect(step(lesson.add(const Duration(minutes: 3))).inside, isFalse);
      },
    );

    test('chegaradagi GPS sakrashi blokni o\'chirmaydi (gisterezis)', () {
      final d = decideZone(
        zone: _zone,
        fix: _fixAt(150, at: lesson),
        memory: const ZoneMemory(inside: true),
        now: lesson,
        locationOn: true,
      );

      expect(d.inside, isTrue);
    });

    test('fail-closed: GPS o\'chiq, nuqta yo\'q yoki eski — hududda deb', () {
      final far = _fixAt(5000, at: lesson);
      expect(
        decideZone(
          zone: _zone,
          fix: far,
          memory: const ZoneMemory(inside: false),
          now: lesson,
          locationOn: false,
        ).inside,
        isTrue,
      );
      expect(
        decideZone(
          zone: _zone,
          fix: null,
          memory: const ZoneMemory(),
          now: lesson,
          locationOn: true,
        ).inside,
        isTrue,
      );
      expect(
        decideZone(
          zone: _zone,
          fix: _fixAt(5000, at: lesson.subtract(const Duration(minutes: 30))),
          memory: const ZoneMemory(inside: false),
          now: lesson,
          locationOn: true,
        ).inside,
        isTrue,
      );
    });

    test('noaniq nuqta (aniqlik 300 m) — oldingi qaror saqlanadi', () {
      final d = decideZone(
        zone: _zone,
        fix: _fixAt(2000, accuracy: 300, at: lesson),
        memory: const ZoneMemory(inside: false),
        now: lesson,
        locationOn: true,
      );

      expect(d.inside, isFalse);
    });
  });

  group('applyPlan', () {
    test(
      'dars vaqti: maktab bloki — paketlar, toifalar, ruxsat etilganlar, tugash vaqti',
      () {
        final outcome = applyPlan(_plan([_schoolRoutine()]), lesson);

        expect(outcome.blocked, containsAll(['com.game']));
        expect(outcome.limits, ['com.youtube:30']);
        expect(outcome.school?.packages, {'com.game'});
        expect(outcome.school?.categories, {'GAME', 'SOCIAL'});
        expect(outcome.school?.allowedApps, {'kundalik uz'});
        expect(outcome.school?.until, '12:30');
      },
    );

    test(
      'server ro\'yxati bo\'sh bo\'lsa ham maktab bloki bor — qurilma toifa bo\'yicha bloklaydi',
      () {
        final outcome = applyPlan(
          _plan([_schoolRoutine(apps: const [])]),
          lesson,
        );

        expect(outcome.school?.categories, {'GAME', 'SOCIAL'});
        expect(outcome.blocked, isEmpty);
      },
    );

    test(
      '«faqat hududda»: tashqarida — maktab bloki yo\'q, ota-ona bloki qoladi',
      () {
        final plan = _plan(
          [_schoolRoutine(zone: _zone)],
          fullBlocks: const ['com.parent.blocked'],
        );

        final outside = applyPlan(plan, lesson, insideZone: false);
        final inside = applyPlan(plan, lesson);

        expect(outside.school, isNull);
        expect(outside.blocked, {'com.parent.blocked'});
        expect(inside.school, isNotNull);
        expect(activeSchoolZone(plan, lesson)?.radiusM, 100);
      },
    );

    test('dars tugagach yoki boshqa kuni — maktab bloki yo\'q', () {
      final plan = _plan([_schoolRoutine()]);

      expect(applyPlan(plan, _tkt(2026, 11, 12, 13)).school, isNull);
      expect(applyPlan(plan, _tkt(2026, 11, 13, 10)).school, isNull);
    });

    test('ota-ona vaqt oynasi BLOCK — wildcard', () {
      final plan = RestrictionPlan(
        fullBlocks: const [],
        limitEntries: const [],
        policies: [
          AppSchedulePolicy.fromBackendJson({
            'id': 'p1',
            'name': 'Uyqu',
            'startTime': '21:00',
            'endTime': '07:00',
            'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
            'action': 'BLOCK',
            'isActive': true,
          }),
        ],
        routines: const [],
        blockAll: false,
        planDay: '2026-11-12',
      );

      expect(applyPlan(plan, _tkt(2026, 11, 12, 22)).blocked, {kWildcardAll});
      expect(applyPlan(plan, _tkt(2026, 11, 12, 10)).blocked, isEmpty);
    });
  });

  test(
    'oflayn kesh: reja saqlanib qayta o\'qiladi va dars vaqtida bloklaydi',
    () {
      final plan = _plan(
        [_schoolRoutine(zone: _zone)],
        fullBlocks: const ['com.x'],
      );

      final restored = RestrictionPlan.tryFromJson(plan.toJsonString())!;
      final outcome = applyPlan(restored, lesson);

      expect(restored.routines.single.isSchoolMode, isTrue);
      expect(restored.routines.single.schoolMode?.zone?.radiusM, 100);
      expect(outcome.blocked, {'com.x', 'com.game'});
      expect(outcome.school?.until, '12:30');
      expect(RestrictionPlan.tryFromJson('buzilgan'), isNull);
    },
  );

  test(
    'eski kesh: o\'tgan hafta olingan maktab jadvali shu hafta kunida qo\'llanmaydi',
    () {
      // Telefon 7 kun oflayn: payshanba jadvali keyingi payshanbada qayta
      // yoqilmasin (bayram, istisno, jadval o'zgargan bo'lishi mumkin).
      final plan = _plan(
        [_schoolRoutine(zone: _zone)],
        fullBlocks: const ['com.parent.blocked'],
        planDay: '2026-11-05',
      );

      final outcome = applyPlan(plan, lesson);

      expect(outcome.school, isNull);
      expect(outcome.blocked, {'com.parent.blocked'});
      expect(activeSchoolZone(plan, lesson), isNull);
    },
  );

  test('eski server (schoolMode yo\'q) — jadval avvalgidek, meta null', () {
    final routine = Schedule.fromBackendJson({
      'id': 'r1',
      'title': 'Maktab (School Mode)',
      'type': 'SCHOOL',
      'startHour': 8,
      'endHour': 12,
      'weekdays': [4],
      'blockedApps': ['com.game'],
      'source': 'SCHOOL_MODE',
    });

    expect(routine.schoolMode, isNull);
    expect(applyPlan(_plan([routine]), lesson).school?.packages, {'com.game'});
  });
}
