// Sinf dars jadvali — xodim tomoni. Ko'rish: `classes.view` (sinf doirasida);
// o'zgartirish: `timetable.manage` — butun haftani atomik almashtiradi.

import { Injectable } from '@nestjs/common';
import { Prisma, SchoolClass, SchoolShift, SchoolTimetableLesson } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { assertCan, assertClassInScope, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { toShiftView } from '../structure/school-info.service';
import { assertLessonsFitShift, normalizeSubject, parsePeriods } from './timetable-rules';
import { LessonInput, timetableInputSchema } from './timetable.schemas';

type ClassWithShift = SchoolClass & { shift: SchoolShift };

const toLessonView = (l: SchoolTimetableLesson) => ({
  id: l.id,
  weekday: l.weekday,
  periodNo: l.periodNo,
  subject: l.subject,
  room: l.room,
  teacherName: l.teacherName,
});

const byDayAndPeriod = (a: SchoolTimetableLesson, b: SchoolTimetableLesson) =>
  a.weekday - b.weekday || a.periodNo - b.periodNo;

@Injectable()
export class TimetableService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  async get(actor: SchoolActor, classId: string) {
    assertCan(actor, 'classes.view');
    const cls = await this.findClass(actor, classId);
    assertClassInScope(actor, classId);
    return this.view(cls, await this.lessonsOf(this.prisma, classId));
  }

  /** Sinfning butun haftasini almashtirish (bo'sh ro'yxat — jadvalni tozalaydi). */
  async replace(actor: SchoolActor, classId: string, body: unknown) {
    assertCan(actor, 'timetable.manage');
    const { lessons } = parseOrThrow(timetableInputSchema, body ?? {});
    const cls = await this.findClass(actor, classId);
    assertClassInScope(actor, classId);
    const normalized = lessons.map((l) => ({ ...l, subject: normalizeSubject(l.subject) }));
    assertLessonsFitShift(normalized, { weekdays: cls.shift.weekdays, periods: parsePeriods(cls.shift.periods) });
    const saved = await this.prisma.$transaction(async (tx) => {
      // Ikki xodim bir vaqtda saqlasa — navbat bilan (unikal cheklov to'qnashuvisiz).
      await tx.$queryRaw`SELECT 1 AS locked FROM pg_advisory_xact_lock(hashtextextended(${`timetable:${classId}`}, 0))`;
      const before = await this.lessonsOf(tx, classId);
      await tx.schoolTimetableLesson.deleteMany({ where: { classId } });
      await tx.schoolTimetableLesson.createMany({ data: normalized.map((l) => this.row(actor.schoolId, classId, l)) });
      const after = await this.lessonsOf(tx, classId);
      await this.audit.write(
        actor,
        {
          module: 'CLASSES',
          action: 'timetable.replace',
          summary: `${cls.name}: dars jadvali yangilandi (${after.length} dars)`,
          entityId: classId,
          before: before.map(toLessonView),
          after: after.map(toLessonView),
          params: { name: cls.name, count: after.length },
        },
        tx,
      );
      return after;
    });
    return this.view(cls, saved);
  }

  private row(schoolId: string, classId: string, l: LessonInput): Prisma.SchoolTimetableLessonCreateManyInput {
    return { schoolId, classId, weekday: l.weekday, periodNo: l.periodNo, subject: l.subject, room: l.room, teacherName: l.teacherName };
  }

  private async findClass(actor: SchoolActor, classId: string): Promise<ClassWithShift> {
    const cls = await this.prisma.schoolClass.findFirst({
      where: { id: classId, schoolId: actor.schoolId },
      include: { shift: true },
    });
    if (!cls) throw notFound(classId);
    return cls;
  }

  private async lessonsOf(db: Prisma.TransactionClient | PrismaService, classId: string) {
    const rows = await db.schoolTimetableLesson.findMany({ where: { classId } });
    return [...rows].sort(byDayAndPeriod);
  }

  private view(cls: ClassWithShift, lessons: readonly SchoolTimetableLesson[]) {
    return { classId: cls.id, shift: toShiftView(cls.shift), lessons: lessons.map(toLessonView) };
  }
}
