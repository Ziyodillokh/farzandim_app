// RestrictionPlan: Toshkent vaqti, kechadan ertalabga o'tuvchi oyna (kun
// kechagi kunga tegishli), keyingi chegara, barqaror (kanonik) kesh JSON'i.

import 'package:farzandim_child/features/app_restrictions/data/services/restriction_plan.dart';
import 'package:farzandim_child/features/schedules/data/models/schedule.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Toshkent devor vaqti → lahza (mashina vaqt mintaqasidan qat'i nazar).
DateTime _tkt(int y, int m, int d, int h, [int min = 0]) =>
    DateTime.utc(y, m, d, h, min).subtract(const Duration(hours: 5));

AppSchedulePolicy _policy(
  String start,
  String end,
  List<int> days, {
  String id = 'p1',
}) => AppSchedulePolicy.fromBackendJson({
  'id': id,
  'name': 'Uyqu',
  'startTime': start,
  'endTime': end,
  'daysOfWeek': days,
  'action': 'BLOCK',
  'isActive': true,
});

Schedule _routine({
  required int startHour,
  required int endHour,
  required List<int> weekdays,
  String id = 'r1',
  List<String> apps = const ['com.tiktok'],
  bool school = false,
}) => Schedule.fromBackendJson({
  'id': id,
  'title': 'Jadval',
  'type': school ? 'SCHOOL' : 'SLEEP',
  'startHour': startHour,
  'startMinute': 0,
  'endHour': endHour,
  'endMinute': 0,
  'weekdays': weekdays,
  'isActive': true,
  'blockedApps': apps,
  if (school) 'source': 'SCHOOL_MODE',
});

RestrictionPlan _plan({
  List<AppSchedulePolicy> policies = const [],
  List<Schedule> routines = const [],
  List<String> fullBlocks = const [],
  bool blockAll = false,
  String planDay = '2026-11-13',
}) => RestrictionPlan(
  fullBlocks: fullBlocks,
  limitEntries: const [],
  policies: policies,
  routines: routines,
  blockAll: blockAll,
  planDay: planDay,
);

void main() {
  // 2026-11-13 — juma (ISO 5), 2026-11-16 — dushanba (ISO 1).
  group('kechadan ertalabga o\'tuvchi oyna', () {
    test('juma 21:00–07:00: shanba tongi ham bloklanadi', () {
      final plan = _plan(
        policies: [
          _policy('21:00', '07:00', [5]),
        ],
      );

      expect(isWindowBlocked(plan.policies, _tkt(2026, 11, 13, 22)), isTrue);
      expect(isWindowBlocked(plan.policies, _tkt(2026, 11, 14, 2)), isTrue);
      expect(isWindowBlocked(plan.policies, _tkt(2026, 11, 14, 7)), isFalse);
    });

    test('dushanba tongi yakshanba tanlanmagan bo\'lsa — bloklanmaydi', () {
      final weekdays = _plan(
        policies: [
          _policy('21:00', '07:00', [1, 2, 3, 4, 5]),
        ],
      );

      expect(
        isWindowBlocked(weekdays.policies, _tkt(2026, 11, 16, 2)),
        isFalse,
      );
      expect(isWindowBlocked(weekdays.policies, _tkt(2026, 11, 17, 2)), isTrue);
    });

    test('jadval (routine) ham xuddi shunday — kechagi kun hisoblanadi', () {
      final r = _routine(startHour: 22, endHour: 6, weekdays: [5]);

      expect(isRoutineActive(r, _tkt(2026, 11, 14, 3)), isTrue);
      expect(isRoutineActive(r, _tkt(2026, 11, 13, 3)), isFalse);
    });

    test('kun ichidagi oyna o\'zgarmagan', () {
      final plan = _plan(
        policies: [
          _policy('14:00', '16:00', [5]),
        ],
      );

      expect(isWindowBlocked(plan.policies, _tkt(2026, 11, 13, 15)), isTrue);
      expect(isWindowBlocked(plan.policies, _tkt(2026, 11, 14, 15)), isFalse);
    });
  });

  group('nextBoundary', () {
    test('oyna boshlanishi va tugashi (kechadan o\'tuvchi)', () {
      final plan = _plan(
        policies: [
          _policy('21:00', '07:00', [1, 2, 3, 4, 5, 6, 7]),
        ],
      );

      expect(
        nextBoundary(plan, _tkt(2026, 11, 13, 20, 30)),
        _tkt(2026, 11, 13, 21),
      );
      expect(nextBoundary(plan, _tkt(2026, 11, 13, 23)), _tkt(2026, 11, 14, 7));
    });

    test('vaqtga bog\'liq qoida yo\'q — null (valid_until = 0)', () {
      final plan = _plan(fullBlocks: const ['com.a'], blockAll: true);

      expect(nextBoundary(plan, _tkt(2026, 11, 13, 10)), isNull);
    });

    test('natijani o\'zgartirmaydigan chegara o\'tkazib yuboriladi', () {
      // 20:00–23:00 ichida 21:00–22:00 — '*' 20:00 dan 23:00 gacha uzluksiz.
      final plan = _plan(
        policies: [
          _policy('20:00', '23:00', [5], id: 'a'),
          _policy('21:00', '22:00', [5], id: 'b'),
        ],
      );

      expect(
        nextBoundary(plan, _tkt(2026, 11, 13, 20, 30)),
        _tkt(2026, 11, 13, 23),
      );
    });

    test('faqat tanlangan kunlar: keyingi juma', () {
      final plan = _plan(
        policies: [
          _policy('09:00', '10:00', [5]),
        ],
      );

      expect(nextBoundary(plan, _tkt(2026, 11, 13, 11)), _tkt(2026, 11, 20, 9));
    });

    test('maktab jadvali faqat reja kunida', () {
      final plan = _plan(
        routines: [
          _routine(startHour: 8, endHour: 12, weekdays: [5], school: true),
        ],
      );

      expect(nextBoundary(plan, _tkt(2026, 11, 13, 7)), _tkt(2026, 11, 13, 8));
      expect(nextBoundary(plan, _tkt(2026, 11, 13, 9)), _tkt(2026, 11, 13, 12));
      // Ertasi (reja kuni emas) — maktab bloki keyin hech qachon yoqilmaydi.
      expect(nextBoundary(plan, _tkt(2026, 11, 13, 13)), isNull);
    });
  });

  group('kesh JSON', () {
    test(
      'kanonik: tartibi boshqa bir xil reja — bir xil satr, fetchedAt yo\'q',
      () {
        final a = RestrictionPlan(
          fullBlocks: const ['b', 'a'],
          limitEntries: const ['y:5', 'x:10'],
          policies: [
            _policy('1:00', '2:00', [1], id: 'q'),
            _policy('3:00', '4:00', [1]),
          ],
          routines: [
            _routine(startHour: 1, endHour: 2, weekdays: [1], id: 'z'),
            _routine(startHour: 3, endHour: 4, weekdays: [1], id: 'k'),
          ],
          blockAll: false,
          planDay: '2026-11-13',
          grants: const [PlanGrant(packageName: 'g', expiresAtMs: 5)],
          blockUnknown: true,
        );
        final b = RestrictionPlan(
          fullBlocks: const ['a', 'b'],
          limitEntries: const ['x:10', 'y:5'],
          policies: [a.policies[1], a.policies[0]],
          routines: [a.routines[1], a.routines[0]],
          blockAll: false,
          planDay: '2026-11-13',
          grants: const [PlanGrant(packageName: 'g', expiresAtMs: 5)],
          blockUnknown: true,
        );

        expect(a.toJsonString(), b.toJsonString());
        expect(a.toJsonString(), isNot(contains('fetchedAt')));
        final restored = RestrictionPlan.tryFromJson(a.toJsonString())!;
        expect(restored.toJsonString(), a.toJsonString());
        expect(restored.grants.single.packageName, 'g');
        expect(restored.blockUnknown, isTrue);
        expect(restored.blockUninstall, isNull);
      },
    );

    test('eski kesh (fetchedAt) — reja kuni Toshkent bo\'yicha olinadi', () {
      // 2026-11-12 20:30 UTC = 2026-11-13 01:30 Toshkent.
      final plan = RestrictionPlan.tryFromJson(
        '{"fullBlocks":["x"],"limitEntries":[],"policies":[],"routines":[],'
        '"blockAll":false,"fetchedAt":"2026-11-12T20:30:00.000Z"}',
      )!;

      expect(plan.planDay, '2026-11-13');
      expect(plan.fullBlocks, ['x']);
      expect(plan.grants, isEmpty);
    });
  });

  test('tashkentDayKey va nextTashkentTime', () {
    expect(tashkentDayKey(DateTime.utc(2026, 11, 12, 19, 30)), '2026-11-13');
    expect(
      nextTashkentTime(_tkt(2026, 11, 13, 10), '12:30'),
      _tkt(2026, 11, 13, 12, 30),
    );
    expect(
      nextTashkentTime(_tkt(2026, 11, 13, 23), '06:00'),
      _tkt(2026, 11, 14, 6),
    );
  });
}
