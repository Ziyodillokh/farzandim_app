// RestrictionSnapshot: base_blocked / valid_until / school_until_ms / grants,
// faqat o'zgargan kalit yoziladi, snapshot_version ENG OXIRIDA va faqat
// o'zgarishda; unpair tozalashi.

import 'package:farzandim_child/features/app_restrictions/data/services/restriction_plan.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restriction_snapshot.dart';
import 'package:farzandim_child/features/schedules/data/models/schedule.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime _tkt(int y, int m, int d, int h, [int min = 0]) =>
    DateTime.utc(y, m, d, h, min).subtract(const Duration(hours: 5));

RestrictionPlan _plan({
  bool blockAll = false,
  List<PlanGrant> grants = const [],
  List<Schedule> routines = const [],
  bool? blockUnknown,
}) => RestrictionPlan(
  fullBlocks: const ['com.full'],
  limitEntries: const ['com.youtube:30'],
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
  routines: routines,
  blockAll: blockAll,
  planDay: '2026-11-13',
  grants: grants,
  blockUnknown: blockUnknown,
);

Schedule _lesson() => Schedule.fromBackendJson({
  'id': 'school-1',
  'title': 'Maktab',
  'type': 'SCHOOL',
  'startHour': 8,
  'startMinute': 0,
  'endHour': 12,
  'endMinute': 30,
  'weekdays': [5],
  'blockedApps': ['com.game'],
  'source': 'SCHOOL_MODE',
  'schoolMode': {
    'blockedCategories': ['GAME'],
    'allowedApps': ['Kundalik'],
  },
});

void main() {
  group('buildSnapshot', () {
    test(
      'oyna tashqarisida: base = to\'liq bloklar, valid_until = oyna boshi',
      () {
        final s = buildSnapshot(_plan(), _tkt(2026, 11, 13, 20));

        expect(s.blocked, 'com.full');
        expect(s.baseBlocked, 'com.full');
        expect(s.limits, 'com.youtube:30');
        expect(s.validUntilMs, _tkt(2026, 11, 13, 21).millisecondsSinceEpoch);
        expect(s.schoolUntil, '');
        expect(s.schoolUntilMs, 0);
      },
    );

    test('oyna ichida: \'*\' faqat blocked\'da, base\'da EMAS', () {
      final s = buildSnapshot(_plan(), _tkt(2026, 11, 13, 22));

      expect(s.blocked, '*,com.full');
      expect(s.baseBlocked, 'com.full');
      expect(s.validUntilMs, _tkt(2026, 11, 14, 7).millisecondsSinceEpoch);
    });

    test('"barchasini blokla" siyosati base\'da ham', () {
      final s = buildSnapshot(_plan(blockAll: true), _tkt(2026, 11, 13, 10));

      expect(s.baseBlocked, '*,com.full');
    });

    test('maktab bloki: school_until "HH:MM" va epoch', () {
      final s = buildSnapshot(
        _plan(routines: [_lesson()]),
        _tkt(2026, 11, 13, 10),
      );

      expect(s.schoolUntil, '12:30');
      expect(
        s.schoolUntilMs,
        _tkt(2026, 11, 13, 12, 30).millisecondsSinceEpoch,
      );
      expect(s.schoolPackages, 'com.game');
      expect(s.schoolCategories, 'GAME');
      expect(s.schoolAllowed, 'kundalik');
      expect(s.validUntilMs, _tkt(2026, 11, 13, 12, 30).millisecondsSinceEpoch);
    });

    test('grant: tugaganlari tashlanadi, paket bo\'yicha eng kechi', () {
      final now = _tkt(2026, 11, 13, 10);
      final ms = now.millisecondsSinceEpoch;
      final s = buildSnapshot(
        _plan(
          grants: [
            PlanGrant(packageName: 'com.a', expiresAtMs: ms + 60000),
            PlanGrant(packageName: 'com.a', expiresAtMs: ms + 120000),
            PlanGrant(packageName: 'com.old', expiresAtMs: ms - 1),
          ],
        ),
        now,
      );

      expect(s.grants, 'com.a:${ms + 120000}');
    });
  });

  group('writeSnapshot', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('birinchi yozuv — kalitlar, snapshot_version eng oxirida', () async {
      final prefs = await SharedPreferences.getInstance();
      final s = buildSnapshot(
        _plan(blockUnknown: true),
        _tkt(2026, 11, 13, 22),
        clockOffsetMs: 0,
      );

      final written = await writeSnapshot(prefs, s);

      expect(written.last, RestrictionKeys.snapshotVersion);
      expect(written, contains(RestrictionKeys.blocked));
      expect(written, contains(RestrictionKeys.baseBlocked));
      expect(written, contains(RestrictionKeys.validUntilMs));
      expect(written, contains(RestrictionKeys.blockUnknown));
      expect(prefs.getInt(RestrictionKeys.snapshotVersion), 1);
      expect(prefs.getString(RestrictionKeys.blocked), '*,com.full');
      expect(prefs.getBool(RestrictionKeys.blockUnknown), isTrue);
    });

    test(
      'o\'zgarmagan holat — hech narsa yozilmaydi, versiya oshmaydi',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final s = buildSnapshot(
          _plan(),
          _tkt(2026, 11, 13, 22),
          clockOffsetMs: 0,
        );
        await writeSnapshot(prefs, s);

        final again = await writeSnapshot(prefs, s);

        expect(again, isEmpty);
        expect(prefs.getInt(RestrictionKeys.snapshotVersion), 1);
      },
    );

    test('bitta o\'zgarish — faqat o\'sha kalit va versiya', () async {
      final prefs = await SharedPreferences.getInstance();
      await writeSnapshot(
        prefs,
        buildSnapshot(_plan(), _tkt(2026, 11, 13, 22), clockOffsetMs: 0),
      );

      // 23:00 — natija bir xil (blocked, valid_until o'zgarmagan).
      expect(
        await writeSnapshot(
          prefs,
          buildSnapshot(_plan(), _tkt(2026, 11, 13, 23), clockOffsetMs: 0),
        ),
        isEmpty,
      );
      // 08:00 — oyna tugadi.
      final written = await writeSnapshot(
        prefs,
        buildSnapshot(_plan(), _tkt(2026, 11, 14, 8), clockOffsetMs: 0),
      );

      expect(written, [
        RestrictionKeys.blocked,
        RestrictionKeys.validUntilMs,
        RestrictionKeys.snapshotVersion,
      ]);
      expect(prefs.getInt(RestrictionKeys.snapshotVersion), 2);
    });

    test('soat siljishi faqat 30 s dan ko\'p o\'zgarsa yoziladi', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = _tkt(2026, 11, 13, 10);
      await writeSnapshot(
        prefs,
        buildSnapshot(_plan(), now, clockOffsetMs: 1000),
      );

      expect(
        await writeSnapshot(
          prefs,
          buildSnapshot(_plan(), now, clockOffsetMs: 20000),
        ),
        isEmpty,
      );
      expect(
        await writeSnapshot(
          prefs,
          buildSnapshot(_plan(), now, clockOffsetMs: 90000),
        ),
        [RestrictionKeys.clockOffsetMs, RestrictionKeys.snapshotVersion],
      );
    });
  });

  test(
    'clearRestrictionState: holat o\'chadi, til matnlari va pairing qoladi',
    () async {
      SharedPreferences.setMockInitialValues({'childId': 'c1'});
      final prefs = await SharedPreferences.getInstance();
      // Boshqa isolate / native yozgan kalitlar (bu nusxa keshida yo'q).
      SharedPreferences.setMockInitialValues({
        'childId': 'c1',
        'restriction.blocked_packages': '*',
        'restriction.snapshot_version': 7,
        'restriction.limit_warned.com.a.30.2026-11-13': true,
        'restriction.i18n.blocked': 'Ilova bloklangan',
        'school_zone.fix': '{}',
        'game.pending': '[]',
      });

      await clearRestrictionState(prefs);

      final fresh = await SharedPreferences.getInstance();
      await fresh.reload();
      expect(fresh.getKeys(), {'childId', 'restriction.i18n.blocked'});
    },
  );
}
