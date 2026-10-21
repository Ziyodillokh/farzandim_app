// Maktab "Maktab rejimi" (server `source: SCHOOL_MODE` virtual jadvali)
// "Mening jadvalim" sahifasida: belgisi o'qiladi, bugungi ro'yxatga
// qo'shiladi (u `/routines/today`da yo'q), hozir davom etayotgani
// aniqlanadi.

import 'package:farzandim_child/features/schedules/data/models/schedule.dart';
import 'package:farzandim_child/features/schedules/presentation/providers/schedule_providers.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _routine(
  String id, {
  required int start,
  required int end,
  List<int> weekdays = const [1, 2, 3, 4, 5],
  String? source,
}) => {
  'id': id,
  'title': id,
  'type': 'SCHOOL',
  'startHour': start ~/ 100,
  'startMinute': start % 100,
  'endHour': end ~/ 100,
  'endMinute': end % 100,
  'weekdays': weekdays,
  'isActive': true,
  'blockedApps': ['com.game'],
  'source': ?source,
};

Schedule _schedule(
  String id, {
  required int start,
  required int end,
  List<int> weekdays = const [1, 2, 3, 4, 5],
  String? source,
}) => Schedule.fromBackendJson(
  _routine(id, start: start, end: end, weekdays: weekdays, source: source),
);

void main() {
  test('server belgisi: SCHOOL_MODE — "Maktab rejimi", qolgani — yo\'q', () {
    final school = _schedule(
      'school-mode-2026-10-20-0',
      start: 800,
      end: 1330,
      weekdays: const [2],
      source: kSchoolModeSource,
    );
    expect(school.isSchoolMode, isTrue);
    expect(school.type, ScheduleType.school);
    expect(school.blockedApps, ['com.game']);
    expect(school.timeRangeFormatted, '08:00 – 13:30');

    expect(_schedule('own', start: 800, end: 1300).isSchoolMode, isFalse);
    expect(
      _schedule('odd', start: 800, end: 1300, source: 'PARENT').isSchoolMode,
      isFalse,
    );
  });

  group('bugungi ro\'yxat', () {
    final sleep = _schedule('sleep', start: 2130, end: 700);
    final homework = _schedule('homework', start: 1500, end: 1700);
    final school = _schedule(
      'school-mode-2026-10-20-0',
      start: 800,
      end: 1330,
      weekdays: const [2],
      source: kSchoolModeSource,
    );

    test('"Maktab rejimi" boshlanish vaqti bo\'yicha qo\'shiladi', () {
      final list = withSchoolModeSchedules(
        [homework, sleep],
        [sleep, homework, school],
        DateTime.tuesday,
      );
      expect(list.map((s) => s.id), [
        'school-mode-2026-10-20-0',
        'homework',
        'sleep',
      ]);
    });

    test('boshqa kun (Toshkent) uchun — ro\'yxat o\'zgarmaydi', () {
      final today = [homework];
      expect(
        withSchoolModeSchedules(today, [school], DateTime.wednesday),
        same(today),
      );
      expect(withSchoolModeSchedules(today, [school], 0), same(today));
    });

    test('allaqachon ro\'yxatda bo\'lsa — takrorlanmaydi', () {
      final list = withSchoolModeSchedules(
        [school, homework],
        [school],
        DateTime.tuesday,
      );
      expect(list.map((s) => s.id), ['school-mode-2026-10-20-0', 'homework']);
    });

    test('faqat "Maktab rejimi" qo\'shiladi (ota-ona jadvali `/today`dan)', () {
      final list = withSchoolModeSchedules(const [], [
        homework,
        school,
      ], DateTime.tuesday);
      expect(list.map((s) => s.id), ['school-mode-2026-10-20-0']);
    });
  });

  group('hozir davom etyaptimi', () {
    DateTime at(int hour, int minute) => DateTime(2026, 10, 20, hour, minute);

    test('kunduzgi oyna: boshlanishi kiradi, tugashi kirmaydi', () {
      final school = _schedule('school', start: 800, end: 1330);
      expect(isScheduleActiveAt(school, at(7, 59)), isFalse);
      expect(isScheduleActiveAt(school, at(8, 0)), isTrue);
      expect(isScheduleActiveAt(school, at(13, 29)), isTrue);
      expect(isScheduleActiveAt(school, at(13, 30)), isFalse);
    });

    test('tun o\'tadigan oyna va bo\'sh oyna', () {
      final sleep = _schedule('sleep', start: 2130, end: 700);
      expect(isScheduleActiveAt(sleep, at(22, 0)), isTrue);
      expect(isScheduleActiveAt(sleep, at(6, 59)), isTrue);
      expect(isScheduleActiveAt(sleep, at(7, 0)), isFalse);
      expect(isScheduleActiveAt(sleep, at(12, 0)), isFalse);
      final empty = _schedule('empty', start: 900, end: 900);
      expect(isScheduleActiveAt(empty, at(9, 0)), isFalse);
    });
  });

  group('"Hozir" / "Keyingi" holati (ro\'yxat bilan bir xil)', () {
    DateTime at(int hour, int minute) => DateTime(2026, 10, 20, hour, minute);
    final school = _schedule(
      'school-mode-2026-10-20-0',
      start: 800,
      end: 1330,
      weekdays: const [2],
      source: kSchoolModeSource,
    );
    final homework = _schedule('homework', start: 1500, end: 1700);

    test('faqat "Maktab rejimi": darsdan oldin — keyingi, darsda — hozir', () {
      final today = [school];
      expect(currentScheduleAt(today, null, at(7, 30)), isNull);
      expect(nextScheduleAt(today, null, at(7, 30))?.id, school.id);

      expect(currentScheduleAt(today, null, at(9, 0))?.id, school.id);
      expect(nextScheduleAt(today, null, at(9, 0)), isNull);

      // Darsdan keyin — "bugungi tadbirlar tugadi".
      expect(currentScheduleAt(today, null, at(14, 0)), isNull);
      expect(nextScheduleAt(today, null, at(14, 0)), isNull);
    });

    test('server holati ustun; keyingisi — eng oldin boshlanadigani', () {
      final today = [school, homework];
      expect(currentScheduleAt(today, homework, at(9, 0))?.id, 'homework');
      // 07:00 da: maktab (08:00) server keyingisidan (15:00) oldin.
      expect(nextScheduleAt(today, homework, at(7, 0))?.id, school.id);
      // 10:00 da maktab boshlangan — server keyingisi qoladi.
      expect(nextScheduleAt(today, homework, at(10, 0))?.id, 'homework');
    });
  });
}
