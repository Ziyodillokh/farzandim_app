// Davomat ekranining sof mantig'i: oy kalitlari, Dushanbadan boshlanadigan
// kalendar to'ri, kunlar ro'yxati, kelish foizi va oy jami qatorlari.

import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/presentation/attendance_view_models.dart';
import 'package:farzandim/features/school/presentation/school_view_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _day(String date, {bool school = true, String? status}) =>
    {
      'date': date,
      'schoolDay': school,
      'record': status == null ? null : {'status': status, 'inAt': '08:00'},
    };

MonthAttendance _month(
  String month,
  List<Map<String, Object?>> days, {
  Map<String, Object?> summary = const {},
}) => MonthAttendance.fromJson({
  'student': const {'id': 'st-1', 'name': 'Karimov Aziz'},
  'month': month,
  'days': days,
  'summary': summary,
  'rate': 90,
});

void main() {
  group('oy kalitlari', () {
    test('parseSchoolMonth — to`g`ri va buzuq qiymatlar', () {
      expect(parseSchoolMonth('2026-10'), (year: 2026, month: 10));
      expect(parseSchoolMonth('2026-01'), (year: 2026, month: 1));
      for (final bad in [null, '', '2026-13', '2026-00', '2026-1', '26-10']) {
        expect(parseSchoolMonth(bad), isNull, reason: '$bad');
      }
    });

    test('shiftSchoolMonth — yil chegarasidan o`tadi', () {
      expect(shiftSchoolMonth('2026-12', 1), '2027-01');
      expect(shiftSchoolMonth('2026-01', -1), '2025-12');
      expect(shiftSchoolMonth('2026-10', -12), '2025-10');
      expect(shiftSchoolMonth('2026-10', 0), '2026-10');
      expect(shiftSchoolMonth('oktyabr', 1), isNull);
    });

    test('resolveSchoolMonth — buzuq yoki kelajak → joriy oy', () {
      const current = '2026-10';
      expect(resolveSchoolMonth(null, current: current), current);
      expect(resolveSchoolMonth('2026-13', current: current), current);
      expect(resolveSchoolMonth('2026-11', current: current), current);
      expect(resolveSchoolMonth('2027-01', current: current), current);
      expect(resolveSchoolMonth('2026-09', current: current), '2026-09');
      expect(resolveSchoolMonth('2026-10', current: current), current);
    });
  });

  group('attendanceCalendarCells', () {
    test('Dushanbadan boshlanadi: 2026-10-01 payshanba → 3 bo`sh katak', () {
      final cells = attendanceCalendarCells(
        _month('2026-10', [
          _day('2026-10-01', status: 'LATE'),
          _day('2026-10-02'),
          _day('2026-10-03', school: false),
          _day('2026-10-20', status: 'PRESENT'),
          _day('2026-10-21'),
        ]),
        today: '2026-10-20',
      );

      expect(cells, hasLength(3 + 31));
      expect(cells.take(3), everyElement(isNull));
      final first = cells[3]!;
      expect(first.day, 1);
      expect(first.date, '2026-10-01');
      expect(first.status, SchoolDayStatus.late);
      expect(cells[4]!.status, SchoolDayStatus.pending);
      expect(cells[5]!.status, SchoolDayStatus.holiday);

      final today = cells[3 + 19]!;
      expect(today.date, '2026-10-20');
      expect(today.isToday, isTrue);
      expect(today.isFuture, isFalse);
      expect(today.status, SchoolDayStatus.present);

      final tomorrow = cells[3 + 20]!;
      expect(tomorrow.isFuture, isTrue);
      expect(tomorrow.isToday, isFalse);
    });

    test('Dushanba bilan boshlangan oyda bo`sh katak yo`q', () {
      final cells = attendanceCalendarCells(
        _month('2026-06', const []),
        today: '2026-10-20',
      );
      expect(cells, hasLength(30));
      expect(cells.first?.day, 1);
    });

    test('yakshanbadan boshlangan fevral: 6 bo`sh + 28 kun', () {
      final cells = attendanceCalendarCells(
        _month('2026-02', const []),
        today: '2026-10-20',
      );
      expect(cells, hasLength(6 + 28));
      expect(cells.last?.date, '2026-02-28');
    });

    test('javobda kun yetishmasa ham to`r to`liq (holat noma`lum)', () {
      final cells = attendanceCalendarCells(
        _month('2026-10', [_day('2026-10-05', status: 'ABSENT')]),
        today: '2026-10-20',
      );
      expect(cells.whereType<AttendanceCalendarCell>(), hasLength(31));
      expect(cells[3 + 4]!.status, SchoolDayStatus.absent);
      expect(cells[3 + 5]!.status, SchoolDayStatus.unknown);
    });

    test('buzuq oy → bo`sh to`r', () {
      expect(
        attendanceCalendarCells(_month('', const []), today: '2026-10-20'),
        isEmpty,
      );
    });
  });

  test('attendanceListDays — bugungacha, yangisi oldin, dam olishsiz', () {
    final days = attendanceListDays(
      _month('2026-10', [
        _day('2026-10-17', status: 'PRESENT'),
        _day('2026-10-18', school: false),
        _day('2026-10-19', school: false, status: 'EXCUSED'),
        _day('2026-10-20'),
        _day('2026-10-21', status: 'PRESENT'),
      ]),
      today: '2026-10-20',
    );
    expect(days.map((d) => d.date), ['2026-10-20', '2026-10-19', '2026-10-17']);
    expect(() => days.add(days.first), throwsUnsupportedError);
  });

  group('oy jami', () {
    test('hasAttendanceRate — belgilangan kun bo`lsagina', () {
      expect(hasAttendanceRate(AttendanceSummary.empty), isFalse);
      expect(
        hasAttendanceRate(
          AttendanceSummary.fromJson(const {'pending': 3, 'total': 3}),
        ),
        isFalse,
      );
      expect(
        hasAttendanceRate(
          AttendanceSummary.fromJson(const {
            'present': 1,
            'pending': 2,
            'total': 3,
          }),
        ),
        isTrue,
      );
    });

    test('attendanceSummaryEntries — faqat noldan kattalari, tartib bilan', () {
      final entries = attendanceSummaryEntries(
        AttendanceSummary.fromJson(const {
          'present': 12,
          'late': 0,
          'absent': 1,
          'leftEarly': 0,
          'excused': 2,
          'pending': 1,
          'total': 16,
        }),
      );
      expect(entries.map((e) => e.status), [
        SchoolDayStatus.present,
        SchoolDayStatus.absent,
        SchoolDayStatus.excused,
        SchoolDayStatus.pending,
      ]);
      expect(entries.map((e) => e.count), [12, 1, 2, 1]);
      expect(attendanceSummaryEntries(AttendanceSummary.empty), isEmpty);
    });
  });
}
