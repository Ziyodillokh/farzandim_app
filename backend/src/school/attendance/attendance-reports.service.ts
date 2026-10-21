// Davomat tarixi va hisobotlari (panel `notifications`, `monthReport`, `trend`,
// `studentMonth`) — faqat haqiqiy yozuvlardan; yozuvsiz kun — "belgilanmagan".

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { addDays, tashkentDay } from '../../common/time/tashkent';
import {
  actorCan,
  allowedClassIds,
  assertCan,
  assertClassInScope,
  SchoolActor,
} from '../auth/school-actor';
import { compareUz } from '../common/list-query';
import { notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { classNames, loadHolidays } from './attendance-lookups';
import { AttendanceClock, dateRange, isSchoolDay, monthBounds } from './attendance-time';
import {
  addCount,
  attendedRate,
  EMPTY_COUNTS,
  recordInclude,
  studentName,
  toNoticeView,
  toRecordView,
} from './attendance-view';
import {
  limitQuerySchema,
  monthReportQuerySchema,
  studentMonthQuerySchema,
  trendQuerySchema,
} from './attendance.schemas';

@Injectable()
export class AttendanceReportsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: AttendanceClock,
  ) {}

  /** Ota-onaga xabarlar jurnali (eng yangisi birinchi; navbatchi — faqat bugun). */
  async notifications(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'attendance.view');
    const { limit } = parseOrThrow(limitQuerySchema, query ?? {});
    const allowed = allowedClassIds(actor);
    const scoped = allowed
      ? await this.prisma.schoolStudent.findMany({
          where: { schoolId: actor.schoolId, classId: { in: allowed } },
          select: { id: true },
        })
      : null;
    const onlyToday = !actorCan(actor, 'attendance.history');
    const rows = await this.prisma.schoolParentNotice.findMany({
      where: {
        schoolId: actor.schoolId,
        ...(scoped && { studentId: { in: scoped.map((s) => s.id) } }),
        // "Bugun" — xabarning davomat kuni (`date`), yozilgan lahza emas.
        ...(onlyToday && { date: tashkentDay(this.clock.now()) }),
      },
      orderBy: { at: 'desc' },
      take: limit,
    });
    const [students, guardians] = await Promise.all([
      this.prisma.schoolStudent.findMany({
        where: { schoolId: actor.schoolId, id: { in: [...new Set(rows.map((n) => n.studentId))] } },
        select: { id: true, firstName: true, lastName: true, classId: true },
      }),
      this.prisma.schoolGuardian.findMany({
        where: { schoolId: actor.schoolId, id: { in: [...new Set(rows.map((n) => n.guardianId))] } },
        select: { id: true, fullName: true },
      }),
    ]);
    const studentOf = new Map(students.map((s) => [s.id, s]));
    const guardianOf = new Map(guardians.map((g) => [g.id, g.fullName]));
    const classes = await classNames(this.prisma, actor.schoolId, students.map((s) => s.classId));
    return rows.map((n) => {
      const s = studentOf.get(n.studentId);
      return {
        ...toNoticeView(n),
        studentName: s ? studentName(s) : '—',
        className: (s?.classId && classes.get(s.classId)) || '',
        guardianName: guardianOf.get(n.guardianId) ?? '—',
      };
    });
  }

  /** Oylik hisobot: har o'quvchi uchun o'quv kunlari bo'yicha holat + jami. */
  async monthReport(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'attendance.history');
    const { month, classId } = parseOrThrow(monthReportQuerySchema, query ?? {});
    const cls = await this.prisma.schoolClass.findFirst({
      where: { id: classId, schoolId: actor.schoolId },
      include: { shift: true },
    });
    if (!cls) throw notFound(classId);
    assertClassInScope(actor, classId);
    const today = tashkentDay(this.clock.now());
    const { first, last } = monthBounds(month);
    const end = last < today ? last : today;
    const holidays = await loadHolidays(this.prisma, actor.schoolId);
    const days = first <= end ? dateRange(first, end).filter((d) => isSchoolDay(d, cls.shift, holidays)) : [];
    const students = await this.prisma.schoolStudent.findMany({
      where: { schoolId: actor.schoolId, classId, archived: false },
      select: { id: true, firstName: true, lastName: true },
    });
    const records = await this.prisma.schoolAttendance.findMany({
      where: { schoolId: actor.schoolId, studentId: { in: students.map((s) => s.id) }, date: { gte: first, lte: end } },
      select: { studentId: true, date: true, status: true },
    });
    const statusOf = new Map(records.map((r) => [`${r.date}:${r.studentId}`, r.status]));
    const rows = students
      .map((s) => ({ s, name: studentName(s) }))
      .sort((a, b) => compareUz(a.name, b.name))
      .map(({ s, name }) => {
        const cells = days.map((d) => statusOf.get(`${d}:${s.id}`) ?? null);
        const summary = cells.reduce(addCount, EMPTY_COUNTS);
        return { studentId: s.id, name, cells, summary, rate: attendedRate(summary) };
      });
    return { month, className: cls.name, days, rows };
  }

  /** Oxirgi N kun bo'yicha davomat (bosh sahifa grafigi) — belgilangan kunlar. */
  async trend(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'attendance.view');
    assertCan(actor, 'attendance.history');
    const { daysBack } = parseOrThrow(trendQuerySchema, query ?? {});
    const today = tashkentDay(this.clock.now());
    const allowed = allowedClassIds(actor);
    const [students, classes, holidays] = await Promise.all([
      this.prisma.schoolStudent.findMany({
        where: { schoolId: actor.schoolId, archived: false, ...(allowed && { classId: { in: allowed } }) },
        select: { id: true, classId: true },
      }),
      this.prisma.schoolClass.findMany({ where: { schoolId: actor.schoolId }, include: { shift: true } }),
      loadHolidays(this.prisma, actor.schoolId),
    ]);
    const records = await this.prisma.schoolAttendance.findMany({
      where: { schoolId: actor.schoolId, date: { gte: addDays(today, -daysBack), lte: today } },
      select: { studentId: true, date: true, status: true },
    });
    const statusOf = new Map(records.map((r) => [`${r.date}:${r.studentId}`, r.status]));
    const activeToday = new Set(classes.filter((c) => isSchoolDay(today, c.shift, holidays)).map((c) => c.id));
    const out: Array<{ date: string; rate: number; late: number }> = [];
    for (let i = daysBack; i >= 0; i--) {
      const d = addDays(today, -i);
      const counts = students.reduce((acc, s) => {
        const status = statusOf.get(`${d}:${s.id}`);
        if (status) return addCount(acc, status);
        return d === today && s.classId && activeToday.has(s.classId) ? addCount(acc, null) : acc;
      }, EMPTY_COUNTS);
      if (counts.total > 0 && counts.total > counts.pending) out.push({ date: d, rate: attendedRate(counts), late: counts.late });
    }
    return out;
  }

  /** O'quvchi oyi (kalendar): o'quv kuni bo'lmagan kunlar — null. */
  async studentMonth(actor: SchoolActor, studentId: string, query: unknown) {
    assertCan(actor, 'attendance.view');
    assertCan(actor, 'attendance.history');
    const { month } = parseOrThrow(studentMonthQuerySchema, query ?? {});
    const student = await this.prisma.schoolStudent.findFirst({
      where: { id: studentId, schoolId: actor.schoolId },
      include: { class: { include: { shift: true } } },
    });
    if (!student) throw notFound(studentId);
    assertClassInScope(actor, student.classId);
    const { first, last } = monthBounds(month);
    const [records, holidays] = await Promise.all([
      this.prisma.schoolAttendance.findMany({
        where: { schoolId: actor.schoolId, studentId, date: { gte: first, lte: last } },
        include: recordInclude,
      }),
      loadHolidays(this.prisma, actor.schoolId),
    ]);
    const recordOf = new Map(records.map((r) => [r.date, r]));
    return dateRange(first, last).map((date) => {
      const record = recordOf.get(date);
      const visible = record && isSchoolDay(date, student.class?.shift, holidays);
      return { date, record: visible ? toRecordView(record) : null };
    });
  }
}
