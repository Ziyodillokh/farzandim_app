import { SchoolTimetableLesson } from '@prisma/client';
import { dayOffOf, lessonsForDay } from './timetable-view';

const periods = [
  { no: 1, start: '08:00', end: '08:45', kind: 'LESSON' as const },
  { no: 1, start: '08:45', end: '08:55', kind: 'BREAK' as const },
  { no: 2, start: '08:55', end: '09:40', kind: 'LESSON' as const },
];
const row = (over: Partial<SchoolTimetableLesson>): SchoolTimetableLesson => ({
  id: 'l', schoolId: 's', classId: 'c', weekday: 2, periodNo: 1, subject: 'math', room: null, teacherName: null,
  createdAt: new Date(0), updatedAt: new Date(0), ...over,
});

describe('dayOffOf', () => {
  const shift = { weekdays: [1, 2, 3, 4, 5, 6] };

  it('flags weekdays outside the shift as WEEKEND', () => {
    expect(dayOffOf('2026-10-25', shift, new Map())).toEqual({ reason: 'WEEKEND' }); // yakshanba
  });

  it('flags holidays with their name and lets normal days through', () => {
    const holidays = new Map([['2026-10-21', 'Mustaqillik arafasi']]);

    expect(dayOffOf('2026-10-21', shift, holidays)).toEqual({ reason: 'HOLIDAY', name: 'Mustaqillik arafasi' });
    expect(dayOffOf('2026-10-20', shift, holidays)).toBeNull();
  });

  it('a holiday on a non-school weekday is still WEEKEND', () => {
    expect(dayOffOf('2026-10-25', shift, new Map([['2026-10-25', 'x']]))).toEqual({ reason: 'WEEKEND' });
  });
});

describe('lessonsForDay', () => {
  it('joins lessons with LESSON period times, ordered by period, for the weekday only', () => {
    const lessons = [row({ id: 'b', periodNo: 2, subject: 'english', room: '12', teacherName: 'Aliyeva' }), row({ id: 'a' }), row({ id: 'c', weekday: 3 })];

    expect(lessonsForDay(lessons, periods, 2)).toEqual([
      { periodNo: 1, start: '08:00', end: '08:45', subject: 'math', room: null, teacherName: null },
      { periodNo: 2, start: '08:55', end: '09:40', subject: 'english', room: '12', teacherName: 'Aliyeva' },
    ]);
  });

  it('skips lessons whose period no longer exists in the bell schedule', () => {
    expect(lessonsForDay([row({ periodNo: 9 })], periods, 2)).toEqual([]);
  });
});
