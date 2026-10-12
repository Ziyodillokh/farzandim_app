import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/features/schedules/data/models/schedule.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';
import 'package:farzandim_child/features/screen_time/domain/ios_shield_policy.dart';
import 'package:flutter_test/flutter_test.dart';

AppSchedulePolicy _schedule({
  String start = '21:00',
  String end = '07:00',
  List<int> days = const [1, 2, 3, 4, 5],
  String action = 'BLOCK',
  bool isActive = true,
}) {
  return AppSchedulePolicy(
    id: 'id',
    name: 'name',
    startTime: start,
    endTime: end,
    daysOfWeek: days,
    action: action,
    isActive: isActive,
  );
}

void main() {
  group('IosShieldPolicy.fromBackend', () {
    test('faol BLOCK jadval oynaga aylanadi (yarim tundan o\'tuvchi ham)', () {
      final policy = IosShieldPolicy.fromBackend(
        schedules: [_schedule()],
        blockAll: false,
      );

      expect(policy.blockAll, isFalse);
      expect(policy.windows, const [
        ShieldWindow(
          startMinute: 21 * 60,
          endMinute: 7 * 60,
          weekdays: [1, 2, 3, 4, 5],
        ),
      ]);
    });

    test('ALLOW, nofaol, noto\'g\'ri vaqt va bo\'sh kunli jadvallar tashlanadi',
        () {
      final policy = IosShieldPolicy.fromBackend(
        schedules: [
          _schedule(action: 'ALLOW'),
          _schedule(isActive: false),
          _schedule(start: '25:00'),
          _schedule(end: 'xx'),
          _schedule(start: '08:00', end: '08:00'),
          _schedule(days: const []),
          _schedule(days: const [0, 8]),
        ],
        blockAll: true,
      );

      expect(policy.blockAll, isTrue);
      expect(policy.windows, isEmpty);
    });

    test('15 daqiqadan qisqa oynalar tashlanadi (iOS jadval chegarasi)', () {
      final policy = IosShieldPolicy.fromBackend(
        schedules: [
          _schedule(start: '10:00', end: '10:14'),
          _schedule(start: '23:50', end: '00:04'),
          _schedule(start: '10:00', end: '10:15'),
          _schedule(start: '23:50', end: '00:05'),
        ],
        blockAll: false,
      );

      expect(
        policy.windows.map((w) => w.durationMinutes),
        [15, 15],
      );
    });

    test('hafta kunlari tartiblanadi va takrorlar olib tashlanadi', () {
      final policy = IosShieldPolicy.fromBackend(
        schedules: [_schedule(days: const [7, 1, 7, 3])],
        blockAll: false,
      );

      expect(policy.windows.single.weekdays, [1, 3, 7]);
    });

    test('native kanal kutgan shakl (toMap)', () {
      final policy = IosShieldPolicy.fromBackend(
        schedules: [_schedule(start: '13:30', end: '15:00', days: const [6])],
        blockAll: false,
        denyAppRemoval: true,
      );

      expect(policy.toMap(), {
        'blockAll': false,
        'windows': [
          {'start': 810, 'end': 900, 'weekdays': [6]},
        ],
        'denyAppRemoval': true,
      });
    });
  });

  group('IosShieldPolicy.parseHhMm', () {
    test('to\'g\'ri qiymatlar', () {
      expect(IosShieldPolicy.parseHhMm('00:00'), 0);
      expect(IosShieldPolicy.parseHhMm('23:59'), 1439);
      expect(IosShieldPolicy.parseHhMm('7:05'), 425);
    });

    test('noto\'g\'ri qiymatlar null', () {
      for (final value in ['', '24:00', '12:60', '-1:00', '12', '1:2:3']) {
        expect(IosShieldPolicy.parseHhMm(value), isNull, reason: value);
      }
    });
  });

  group('virtual tanlov elementi limiti', () {
    AppLimit limit(int ms, {bool isActive = true}) => AppLimit(
          id: 'l',
          packageName: IosShieldPolicy.selectionPackage,
          dailyLimitMs: ms,
          isActive: isActive,
        );

    IosShieldPolicy policy(List<AppLimit> limits) => IosShieldPolicy.fromBackend(
          schedules: const [],
          blockAll: false,
          limits: limits,
        );

    test('limit daqiqaga yuqoriga yaxlitlanadi', () {
      expect(policy([limit(90001)]).dailyLimitMinutes, 2);
    });

    test('nofaol limit hisobga olinmaydi', () {
      final result = policy([limit(0, isActive: false)]);

      expect(result.blockAll, isFalse);
      expect(result.dailyLimitMinutes, isNull);
    });

    test('limit bir kundan oshmaydi', () {
      expect(policy([limit(25 * 3600000)]).dailyLimitMinutes, 1439);
    });

    test('limit yo\'q bo\'lsa toMap\'da kalit bo\'lmaydi', () {
      expect(policy(const []).toMap().containsKey('dailyLimitMinutes'), isFalse);
    });
  });

  test('yakshanba va yarim tundan o\'tuvchi rejim to\'g\'ri oynaga aylanadi', () {
    final routine = Schedule.fromBackendJson({
      'id': 'r',
      'title': 'Uxlash',
      'type': 'SLEEP',
      'startHour': 22,
      'startMinute': 0,
      'endHour': 7,
      'endMinute': 0,
      'weekdays': [6, 7],
      'isActive': true,
      'blockedApps': [IosShieldPolicy.selectionPackage],
    });

    final policy = IosShieldPolicy.fromBackend(
      schedules: const [],
      blockAll: false,
      routines: [routine],
    );

    expect(policy.windows, const [
      ShieldWindow(startMinute: 22 * 60, endMinute: 7 * 60, weekdays: [6, 7]),
    ]);
  });
}
