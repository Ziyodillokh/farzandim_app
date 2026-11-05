// Sinf dars jadvali: xodim (ko'rish / atomik almashtirish, ruxsat va doira, validatsiya, audit)
// va bola ilovasi (kunlik jadval, dam olish kuni, bayram, e'lon qilinmagan jadval, izolyatsiya).

import { resetDb } from './db';
import { createStaff } from './school-fixtures';
import { seedWorld, sessionFor, World } from './school-attendance-fixtures';
import { appReq, schoolReq, unlinkedChild } from './school-child-fixtures';
import { createTestApp, TestApp } from './test-app';

const lesson = (weekday: number, periodNo: number, subject: string, extra: Record<string, unknown> = {}) => ({ weekday, periodNo, subject, ...extra });

describe('School timetable', () => {
  let t: TestApp;
  let w: World;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    w = await seedWorld(t);
  });

  afterAll(() => t.close());

  const get = (s: World['admin'], classId = w.classA) => schoolReq(t, s, 'GET', `/timetable/classes/${classId}`);
  const put = (s: World['admin'], lessons: object[], classId = w.classA) => schoolReq(t, s, 'PUT', `/timetable/classes/${classId}`, { lessons });
  const day = (date?: string, token = w.child.token) => appReq(t, token, 'GET', `/child/school/timetable${date ? `?date=${date}` : ''}`);

  describe('staff', () => {
    it('returns the shift bell schedule with an empty timetable, then replaces the whole week atomically', async () => {
      const empty = (await get(w.admin)).json();
      expect(empty).toMatchObject({ classId: w.classA, lessons: [], shift: { id: w.shiftId, name: '1-smena', weekdays: [1, 2, 3, 4, 5, 6] } });
      expect(empty.shift.periods).toHaveLength(11);

      const saved = await put(w.admin, [
        lesson(2, 2, 'english', { room: '12', teacherName: 'Aliyeva N.' }),
        lesson(1, 1, 'MATH'),
        lesson(1, 2, 'Texnologiya', { room: '  ' }),
      ]);
      expect(saved.statusCode).toBe(200);
      expect(saved.json().lessons.map((l: { weekday: number; periodNo: number; subject: string; room: string | null }) => [l.weekday, l.periodNo, l.subject, l.room])).toEqual([
        [1, 1, 'math', null],
        [1, 2, 'Texnologiya', null],
        [2, 2, 'english', '12'],
      ]);
      expect((await get(w.admin)).json().lessons).toHaveLength(3);

      const second = await put(w.admin, [lesson(3, 1, 'history')]);
      expect(second.json().lessons).toHaveLength(1);
      expect(await t.prisma.schoolTimetableLesson.count({ where: { classId: w.classA } })).toBe(1);

      expect((await put(w.admin, [])).json().lessons).toEqual([]);
    });

    it('rejects an invalid payload without touching the saved timetable', async () => {
      await put(w.admin, [lesson(1, 1, 'math')]);
      const cases: [object[], string][] = [
        [[lesson(1, 7, 'math')], 'lessons.0.periodNo: errors.form.invalidPeriod'],
        [[lesson(1, 1, 'math'), lesson(1, 1, 'english')], 'lessons.1.periodNo: errors.form.duplicate'],
        [[lesson(7, 1, 'math')], 'lessons.0.weekday: errors.form.invalidWeekday'],
        [[lesson(0, 1, 'math')], 'lessons.0.weekday: errors.form.invalidWeekday'],
        [[lesson(1, 1, '')], 'lessons.0.subject: errors.form.required'],
        [[lesson(1, 1, 'x'.repeat(61))], 'lessons.0.subject: errors.form.tooLong'],
        [[lesson(1, 1, 'math', { room: 'r'.repeat(21) })], 'lessons.0.room: errors.form.tooLong'],
        [[lesson(1, 1, 'math', { teacherName: 't'.repeat(81) })], 'lessons.0.teacherName: errors.form.tooLong'],
      ];
      for (const [lessons, message] of cases) {
        const res = await put(w.admin, lessons);
        expect(res.statusCode).toBe(400);
        expect(res.json()).toMatchObject({ code: 'VALIDATION', message });
      }
      expect((await schoolReq(t, w.admin, 'PUT', `/timetable/classes/${w.classA}`, {})).statusCode).toBe(400);
      expect((await get(w.admin)).json().lessons.map((l: { subject: string }) => l.subject)).toEqual(['math']);
    });

    it("rejects weekdays the class's shift does not run and BREAK-only periods", async () => {
      const weekdayShift = await t.prisma.schoolShift.create({
        data: {
          schoolId: w.schoolId,
          name: '5 kunlik',
          start: '09:00',
          end: '10:00',
          weekdays: [1, 2, 3, 4, 5],
          periods: [
            { no: 1, start: '09:00', end: '09:45', kind: 'LESSON' },
            { no: 1, start: '09:45', end: '10:00', kind: 'BREAK' },
          ],
        },
      });
      const cls = await t.prisma.schoolClass.create({ data: { schoolId: w.schoolId, grade: 9, letter: 'A', name: '9-A', shiftId: weekdayShift.id } });

      expect((await put(w.admin, [lesson(6, 1, 'math')], cls.id)).json().message).toBe('lessons.0.weekday: errors.form.invalidWeekday');
      expect((await put(w.admin, [lesson(5, 2, 'math')], cls.id)).json().message).toBe('lessons.0.periodNo: errors.form.invalidPeriod');
      expect((await put(w.admin, [lesson(5, 1, 'math')], cls.id)).statusCode).toBe(200);
    });

    it('permissions: DIRECTOR and ADMIN manage any class, HOMEROOM only own, others read-only or denied', async () => {
      expect((await put(w.director, [lesson(1, 1, 'math')], w.classB)).statusCode).toBe(200);
      expect((await put(w.admin, [lesson(1, 1, 'math')], w.classA)).statusCode).toBe(200);

      expect((await put(w.homeroom, [lesson(2, 1, 'history')], w.classA)).statusCode).toBe(200);
      expect((await put(w.homeroom, [lesson(2, 1, 'history')], w.classB)).statusCode).toBe(403);
      expect((await get(w.homeroom, w.classA)).statusCode).toBe(200);
      expect((await get(w.homeroom, w.classB)).statusCode).toBe(403);

      // TEACHER (7-sinf emas, 8-B): o'z sinfini ko'radi, o'zgartira olmaydi
      expect((await get(w.teacher, w.classB)).statusCode).toBe(200);
      expect((await get(w.teacher, w.classA)).statusCode).toBe(403);
      expect((await put(w.teacher, [lesson(1, 1, 'math')], w.classB)).statusCode).toBe(403);

      for (const denied of [w.duty, w.psych]) {
        expect((await get(denied)).statusCode).toBe(403);
        expect((await put(denied, [lesson(1, 1, 'math')])).statusCode).toBe(403);
      }
      expect((await t.app.inject({ method: 'GET', url: `/api/school/timetable/classes/${w.classA}` })).statusCode).toBe(401);
    });

    it("isolates schools: another school's admin gets 404", async () => {
      const other = await seedWorld(t, 'other-school');
      await put(w.admin, [lesson(1, 1, 'math')]);

      expect((await get(other.admin, w.classA)).statusCode).toBe(404);
      expect((await put(other.admin, [lesson(1, 1, 'english')], w.classA)).statusCode).toBe(404);
      expect((await get(w.admin, 'no-such-class')).statusCode).toBe(404);
      expect((await get(w.admin)).json().lessons[0].subject).toBe('math');
    });

    it('writes an audit entry per replacement', async () => {
      await put(w.admin, [lesson(1, 1, 'math'), lesson(1, 2, 'english')]);

      const log = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'timetable.replace' } });
      expect(log).toMatchObject({ module: 'CLASSES', entityId: w.classA, actorId: w.admin.staffId, params: { name: '7-A', count: 2 } });
      expect((log.after as unknown[]).length).toBe(2);
      expect((log.before as unknown[]).length).toBe(0);
    });

    it('a homeroom teacher added later can manage once assigned', async () => {
      const staff = await createStaff(t.prisma, w.schoolId, 'HOMEROOM', 'rahbar-b', [w.classB]);
      const session = await sessionFor(t, staff.id);

      expect((await put(session, [lesson(4, 1, 'math')], w.classB)).statusCode).toBe(200);
      expect((await put(session, [lesson(4, 1, 'math')], w.classA)).statusCode).toBe(403);
    });
  });

  describe('child app', () => {
    // 2026-10-20 seshanba, 2026-10-25 yakshanba
    beforeEach(async () => {
      await put(w.admin, [lesson(2, 2, 'english', { room: '12', teacherName: 'Aliyeva N.' }), lesson(2, 1, 'math'), lesson(3, 1, 'history'), lesson(6, 1, 'informatics')]);
      await put(w.admin, [lesson(2, 1, 'chemistry')], w.classB);
    });

    it("returns the day's lessons with bell times from the shift, ordered by period", async () => {
      const res = await day('2026-10-20');

      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual({
        date: '2026-10-20',
        weekday: 2,
        className: '7-A',
        shift: { name: '1-smena', start: '08:00', end: '13:25' },
        published: true,
        dayOff: null,
        lessons: [
          { periodNo: 1, start: '08:00', end: '08:45', subject: 'math', room: null, teacherName: null },
          { periodNo: 2, start: '08:55', end: '09:40', subject: 'english', room: '12', teacherName: 'Aliyeva N.' },
        ],
      });
    });

    it('defaults to today (Tashkent)', async () => {
      const res = await day();

      expect(res.statusCode).toBe(200);
      expect(res.json().date).toMatch(/^\d{4}-\d{2}-\d{2}$/);
      expect(res.json().weekday).toBeGreaterThanOrEqual(1);
    });

    it('marks weekends and holidays as day off without lessons, still published', async () => {
      await t.prisma.schoolHoliday.create({ data: { schoolId: w.schoolId, date: '2026-10-21', name: 'Bayram arafasi' } });

      expect((await day('2026-10-25')).json()).toMatchObject({ weekday: 7, published: true, dayOff: { reason: 'WEEKEND' }, lessons: [] });
      expect((await day('2026-10-21')).json()).toMatchObject({ dayOff: { reason: 'HOLIDAY', name: 'Bayram arafasi' }, lessons: [] });
      expect((await day('2026-10-22')).json()).toMatchObject({ dayOff: null, lessons: [] }); // payshanba: darssiz kun
    });

    it('reports published=false for a class with no timetable (not "no lessons")', async () => {
      await put(w.admin, []);

      expect((await day('2026-10-20')).json()).toMatchObject({ published: false, dayOff: null, lessons: [] });
    });

    it("never leaks another class's lessons", async () => {
      const res = await day('2026-10-20');

      expect(JSON.stringify(res.json())).not.toContain('chemistry');
    });

    it('skips lessons whose period was removed from the bell schedule', async () => {
      const shift = await t.prisma.schoolShift.findUniqueOrThrow({ where: { id: w.shiftId } });
      const periods = (shift.periods as { no: number; kind: string }[]).filter((p) => p.no !== 2);
      await t.prisma.schoolShift.update({ where: { id: w.shiftId }, data: { periods } });

      expect((await day('2026-10-20')).json().lessons.map((l: { periodNo: number }) => l.periodNo)).toEqual([1]);
    });

    it('validates the date', async () => {
      for (const bad of ['2026-02-30', '2026-13-01', 'yesterday', '20-10-2026']) {
        expect((await day(bad)).statusCode).toBe(400);
      }
    });

    it('rejects parent tokens and anonymous callers; unlinked or archived children get 404', async () => {
      expect((await day('2026-10-20', w.parent.token)).statusCode).toBe(403);
      expect((await t.app.inject({ method: 'GET', url: '/api/child/school/timetable' })).statusCode).toBe(401);

      const lonely = await unlinkedChild(t);
      const res = await day('2026-10-20', lonely.token);
      expect(res.statusCode).toBe(404);
      expect(res.json()).toMatchObject({ code: 'NOT_ENROLLED' });

      await t.prisma.schoolStudent.update({ where: { id: w.vali }, data: { archived: true } });
      expect((await day('2026-10-20')).statusCode).toBe(404);
    });
  });
});
