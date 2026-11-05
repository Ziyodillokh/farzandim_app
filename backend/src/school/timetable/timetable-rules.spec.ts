import { assertLessonsFitShift, lessonPeriods, normalizeSubject, parsePeriods } from './timetable-rules';
import { timetableInputSchema } from './timetable.schemas';

const periods = [
  { no: 1, start: '08:00', end: '08:45', kind: 'LESSON' as const },
  { no: 1, start: '08:45', end: '08:55', kind: 'BREAK' as const },
  { no: 2, start: '08:55', end: '09:40', kind: 'LESSON' as const },
];
const shift = { weekdays: [1, 2, 3, 4, 5], periods };
const lesson = (over: Record<string, unknown> = {}) => ({ weekday: 1, periodNo: 1, subject: 'math', room: null, teacherName: null, ...over });

describe('normalizeSubject', () => {
  it('lowercases LearningSubject keys and leaves free text alone', () => {
    expect(normalizeSubject(' MATH ')).toBe('math');
    expect(normalizeSubject('Informatics')).toBe('informatics');
    expect(normalizeSubject('Texnologiya')).toBe('Texnologiya');
  });
});

describe('periods', () => {
  it('parsePeriods drops malformed items, lessonPeriods keeps lessons only', () => {
    const parsed = parsePeriods([...periods, { no: 'x' }, null, { no: 3, start: '1', end: '2', kind: 'OTHER' }]);

    expect(parsed).toHaveLength(3);
    expect(lessonPeriods(parsed).map((p) => p.no)).toEqual([1, 2]);
    expect(parsePeriods('nope')).toEqual([]);
  });
});

describe('assertLessonsFitShift', () => {
  it('accepts lessons on shift weekdays and LESSON periods', () => {
    expect(() => assertLessonsFitShift([lesson(), lesson({ periodNo: 2 }), lesson({ weekday: 5 })], shift)).not.toThrow();
  });

  it.each([
    ['weekday outside the shift', lesson({ weekday: 6 }), 'lessons.0.weekday: errors.form.invalidWeekday'],
    ['unknown period', lesson({ periodNo: 3 }), 'lessons.0.periodNo: errors.form.invalidPeriod'],
  ])('rejects %s', (_label, bad, message) => {
    expect(() => assertLessonsFitShift([bad], shift)).toThrow(expect.objectContaining({ response: { code: 'VALIDATION', message } }));
  });

  it('rejects duplicates by (weekday, period) with the index of the second one', () => {
    expect(() => assertLessonsFitShift([lesson(), lesson({ periodNo: 2 }), lesson({ subject: 'english' })], shift)).toThrow(
      expect.objectContaining({ response: { code: 'VALIDATION', message: 'lessons.2.periodNo: errors.form.duplicate' } }),
    );
  });
});

describe('timetableInputSchema', () => {
  it('trims, nulls blanks and limits lengths', () => {
    const ok = timetableInputSchema.parse({ lessons: [{ weekday: 2, periodNo: 1, subject: '  Algebra ', room: '  ', teacherName: undefined }] });

    expect(ok.lessons[0]).toEqual({ weekday: 2, periodNo: 1, subject: 'Algebra', room: null, teacherName: null });
    expect(timetableInputSchema.safeParse({ lessons: [{ weekday: 1, periodNo: 1, subject: 'x'.repeat(61) }] }).success).toBe(false);
    expect(timetableInputSchema.safeParse({ lessons: [{ weekday: 1, periodNo: 1, subject: 'x', room: 'r'.repeat(21) }] }).success).toBe(false);
    expect(timetableInputSchema.safeParse({ lessons: [{ weekday: 1, periodNo: 1, subject: 'x', teacherName: 't'.repeat(81) }] }).success).toBe(false);
  });

  it.each([[0], [7], [1.5], ['1']])('rejects weekday %p', (weekday) => {
    expect(timetableInputSchema.safeParse({ lessons: [{ weekday, periodNo: 1, subject: 'x' }] }).success).toBe(false);
  });

  it('requires a lessons array', () => {
    expect(timetableInputSchema.safeParse({}).success).toBe(false);
    expect(timetableInputSchema.safeParse({ lessons: [] }).success).toBe(true);
  });
});
