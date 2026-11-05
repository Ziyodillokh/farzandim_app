import type { ClassTimetable, TimetableInput, TimetableWeekday } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { timetableInputSchema } from '@/data/schemas/timetable';
import { parseOrThrow } from '@/data/schemas/validate';
import { assertCan, assertClassInScope, currentActor, latency, writeAudit } from '../context';
import { getTables, transact } from '../db';
import type { Tables } from '../tables';

/**
 * Sinf dars jadvali. Ko'rish — `classes.view` (sinf rahbari/o'qituvchi: faqat o'z sinfi),
 * tahrirlash — `timetable.manage` (direktor/admin: butun maktab, sinf rahbari: o'z sinfi).
 * `PUT` haftani to'liq almashtiradi; kun/davr noto'g'ri yoki takror bo'lsa — VALIDATION.
 */

function snapshot(t: Tables, classId: string): ClassTimetable {
  const cls = t.classes.find((c) => c.id === classId);
  const shift = cls ? t.shifts.find((s) => s.id === cls.shiftId) : undefined;
  if (!cls || !shift) throw new ServiceError('NOT_FOUND', classId);
  const record = t.timetables.find((r) => r.classId === classId);
  return {
    classId,
    shift: { id: shift.id, name: shift.name, periods: shift.periods.map((p) => ({ ...p })) },
    lessons: (record?.lessons ?? []).map((l) => ({ ...l })),
  };
}

export const timetableService = {
  async get(classId: string): Promise<ClassTimetable> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'classes.view');
    const t = getTables();
    if (!t.classes.some((c) => c.id === classId)) throw new ServiceError('NOT_FOUND', classId);
    assertClassInScope(actor, classId);
    return snapshot(t, classId);
  },

  async save(classId: string, input: TimetableInput): Promise<ClassTimetable> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'timetable.manage');
    if (!getTables().classes.some((c) => c.id === classId)) throw new ServiceError('NOT_FOUND', classId);
    assertClassInScope(actor, classId);
    const data = parseOrThrow(timetableInputSchema, input);
    return transact((t) => {
      const before = snapshot(t, classId);
      const lessonNos = new Set(before.shift.periods.filter((p) => p.kind === 'LESSON').map((p) => p.no));
      data.lessons.forEach((lesson, index) => {
        if (!lessonNos.has(lesson.periodNo)) throw new ServiceError('VALIDATION', `lessons.${index}.periodNo: invalid period`);
      });
      const lessons = data.lessons.map((l) => ({
        weekday: l.weekday as TimetableWeekday,
        periodNo: l.periodNo,
        subject: l.subject,
        ...(l.room && { room: l.room }),
        ...(l.teacherName && { teacherName: l.teacherName }),
      }));
      t.timetables = [...t.timetables.filter((r) => r.classId !== classId), { classId, lessons }];
      const className = t.classes.find((c) => c.id === classId)?.name ?? classId;
      writeAudit(t, actor, 'CLASSES', 'timetable.save', `${className} dars jadvali yangilandi (${lessons.length} dars)`, classId, before.lessons, lessons, {
        class: className,
        count: lessons.length,
      });
      return snapshot(t, classId);
    });
  },
};
