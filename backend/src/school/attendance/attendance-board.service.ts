// Davomat o'qishlari (panel `attendanceService`): sinflar taxtasi, sinf kuni,
// jonli oqim, sinf variantlari. Yozuvi yo'q kun — "belgilanmagan" (pending):
// mock'dagi xeshdan hisoblangan tarix o'rniga faqat haqiqiy yozuvlar.

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import {
  allowedClassIds,
  assertCan,
  assertClassInScope,
  classScopeWhere,
  SchoolActor,
} from '../auth/school-actor';
import { compareClasses, compareUz } from '../common/list-query';
import { notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { loadHolidays, toFeedItems } from './attendance-lookups';
import { AttendanceClock, isSchoolDay, shiftNowRank, tashkentMinute } from './attendance-time';
import {
  addCount,
  attendedRate,
  EMPTY_COUNTS,
  recordInclude,
  studentName,
  sumCounts,
  toRecordView,
} from './attendance-view';
import { dayQuerySchema, feedQuerySchema } from './attendance.schemas';

@Injectable()
export class AttendanceBoardService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: AttendanceClock,
  ) {}

  /** Bugun yoki (tarix ruxsati bilan) o'tgan kun. */
  private resolveDay(actor: SchoolActor, query: unknown): { day: string; today: string; now: Date } {
    const { date } = parseOrThrow(dayQuerySchema, query ?? {});
    const now = this.clock.now();
    const today = tashkentDay(now);
    const day = date ?? today;
    if (day !== today) assertCan(actor, 'attendance.history');
    return { day, today, now };
  }

  /** Sinflar bo'yicha kun taxtasi. */
  async board(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'attendance.view');
    const { day, today, now } = this.resolveDay(actor, query);
    const allowed = allowedClassIds(actor);
    const [classes, holidays, students, records] = await Promise.all([
      this.prisma.schoolClass.findMany({
        where: { schoolId: actor.schoolId, ...(allowed && { id: { in: allowed } }) },
        include: { shift: true, homeroom: { select: { fullName: true } } },
      }),
      loadHolidays(this.prisma, actor.schoolId),
      this.prisma.schoolStudent.findMany({
        where: { schoolId: actor.schoolId, archived: false, ...(allowed && { classId: { in: allowed } }) },
        select: { id: true, classId: true },
      }),
      this.prisma.schoolAttendance.findMany({
        where: { schoolId: actor.schoolId, date: day },
        select: { studentId: true, status: true },
      }),
    ]);
    const statusOf = new Map(records.map((r) => [r.studentId, r.status]));
    const minute = tashkentMinute(now);
    const rank = (shift: (typeof classes)[number]['shift']) =>
      day === today ? shiftNowRank(shift, day, minute, holidays) : 0;
    const sorted = [...classes].sort((a, b) => rank(a.shift) - rank(b.shift) || compareClasses(a, b));
    const rows = sorted.map((cls) => {
      const schoolDay = isSchoolDay(day, cls.shift, holidays);
      const counts = schoolDay
        ? students
            .filter((s) => s.classId === cls.id)
            .reduce((acc, s) => addCount(acc, statusOf.get(s.id) ?? null), EMPTY_COUNTS)
        : EMPTY_COUNTS;
      return {
        classId: cls.id,
        className: cls.name,
        grade: cls.grade,
        shiftId: cls.shiftId,
        shiftName: cls.shift.name,
        homeroomName: cls.homeroom?.fullName ?? null,
        counts,
        rate: attendedRate(counts),
        schoolDay,
      };
    });
    const totals = rows.reduce((acc, r) => sumCounts(acc, r.counts), EMPTY_COUNTS);
    return { date: day, rows, totals };
  }

  /** Bitta sinfning kun ro'yxati (dam olish kuni — yozuvlarsiz). */
  async classDay(actor: SchoolActor, classId: string, query: unknown) {
    assertCan(actor, 'attendance.view');
    const { day } = this.resolveDay(actor, query);
    const cls = await this.prisma.schoolClass.findFirst({
      where: { id: classId, schoolId: actor.schoolId },
      include: { shift: true },
    });
    if (!cls) throw notFound(classId);
    assertClassInScope(actor, classId);
    const [holidays, students] = await Promise.all([
      loadHolidays(this.prisma, actor.schoolId),
      this.prisma.schoolStudent.findMany({ where: { schoolId: actor.schoolId, classId, archived: false } }),
    ]);
    const schoolDay = isSchoolDay(day, cls.shift, holidays);
    const records = schoolDay
      ? await this.prisma.schoolAttendance.findMany({
          where: { schoolId: actor.schoolId, date: day, studentId: { in: students.map((s) => s.id) } },
          include: recordInclude,
        })
      : [];
    const recordOf = new Map(records.map((r) => [r.studentId, r]));
    const rows = students
      .map((s) => ({ s, name: studentName(s) }))
      .sort((a, b) => compareUz(a.name, b.name))
      .map(({ s, name }) => {
        const record = recordOf.get(s.id);
        return {
          studentId: s.id,
          name,
          studentCode: s.studentCode,
          classId: s.classId ?? '',
          className: cls.name,
          device: s.device,
          record: record ? toRecordView(record) : null,
        };
      });
    return { date: day, className: cls.name, shiftName: cls.shift.name, schoolDay, rows };
  }

  /** Bugungi jonli oqim (eng yangisi birinchi). */
  async feed(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'attendance.view');
    const { classId, kind, limit } = parseOrThrow(feedQuerySchema, query ?? {});
    if (classId) assertClassInScope(actor, classId);
    const events = await this.prisma.schoolAttendanceEvent.findMany({
      where: {
        schoolId: actor.schoolId,
        date: tashkentDay(this.clock.now()),
        ...classScopeWhere(actor),
        ...(classId && { classId }),
        ...(kind && { kind }),
      },
      orderBy: { at: 'desc' },
      take: limit,
    });
    return toFeedItems(this.prisma, actor.schoolId, events);
  }

  /** Doiradagi sinflar (filtr va tanlovlar uchun) — davomat ruxsati yetarli. */
  async classOptions(actor: SchoolActor) {
    assertCan(actor, 'attendance.view');
    const allowed = allowedClassIds(actor);
    const classes = await this.prisma.schoolClass.findMany({
      where: { schoolId: actor.schoolId, ...(allowed && { id: { in: allowed } }) },
      include: { shift: { select: { name: true } } },
    });
    return [...classes]
      .sort(compareClasses)
      .map((c) => ({ id: c.id, name: c.name, grade: c.grade, shiftId: c.shiftId, shiftName: c.shift.name }));
  }
}
