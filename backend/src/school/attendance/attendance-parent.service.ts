// Parvoz Parents: erta ketish so'rovi va farzandning oylik davomati. Ota-ona
// faqat O'Z guardian yozuvi (`SchoolGuardian.userId`) orqali bog'langan
// o'quvchiga tegadi — boshqasi 404 (mavjudligi oshkor qilinmaydi).

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { conflict, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { loadHolidays } from './attendance-lookups';
import { AttendanceClock, dateRange, isSchoolDay, monthBounds } from './attendance-time';
import { addCount, attendedRate, EMPTY_COUNTS, studentName, toEarlyExitView } from './attendance-view';
import { earlyExitInputSchema, parentAttendanceQuerySchema } from './attendance.schemas';

/** Ota-ona ro'yxatidagi so'rovlar chegarasi. */
const PARENT_LIST_LIMIT = 50;

const linkInclude = {
  guardian: { select: { id: true, fullName: true } },
  student: { include: { class: { include: { shift: true } }, school: { select: { name: true } } } },
} satisfies Prisma.SchoolStudentGuardianInclude;

@Injectable()
export class AttendanceParentService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: AttendanceClock,
  ) {}

  /** Ota-onaning o'z guardian yozuvi orqali bog'langan (arxivlanmagan) o'quvchisi. */
  private async linked(userId: string, studentId: string) {
    const link = await this.prisma.schoolStudentGuardian.findFirst({
      where: { studentId, guardian: { userId }, student: { archived: false } },
      include: linkInclude,
      orderBy: { guardian: { createdAt: 'asc' } },
    });
    if (!link) throw notFound(studentId);
    return link;
  }

  /** Erta ketish so'rovi (bugun) — xodim panelda tasdiqlaydi / rad etadi. */
  async requestEarlyExit(userId: string, body: unknown) {
    const data = parseOrThrow(earlyExitInputSchema, body ?? {});
    const now = this.clock.now();
    const today = tashkentDay(now);
    const { guardian, student } = await this.linked(userId, data.studentId);
    const name = studentName(student);
    return this.prisma.$transaction(async (tx) => {
      const pending = await tx.schoolEarlyExit.findFirst({
        where: { studentId: student.id, date: today, status: 'PENDING' },
        select: { id: true },
      });
      if (pending) throw conflict('pending');
      const request = await tx.schoolEarlyExit.create({
        data: {
          schoolId: student.schoolId,
          studentId: student.id,
          classId: student.classId,
          date: today,
          time: data.time,
          reason: data.reason,
          pickupBy: data.pickupBy,
          requestedAt: now,
          requestedByUserId: userId,
        },
      });
      // Ota-ona amali — xodim emas: actorId bo'sh, ism — guardian yozuvidan.
      await tx.schoolAuditLog.create({
        data: {
          schoolId: student.schoolId,
          actorId: null,
          actorName: guardian.fullName,
          module: 'ATTENDANCE',
          action: 'earlyExit.create',
          entityId: request.id,
          summary: `${name} — ${data.time}`,
          params: { name, time: data.time },
        },
      });
      return { ...toEarlyExitView(request), studentName: name, className: student.class?.name ?? '', requestedByMe: true };
    });
  }

  /** Ota-onaning bog'langan o'quvchilari bo'yicha so'rovlar (eng yangisi birinchi). */
  async listEarlyExits(userId: string) {
    const links = await this.prisma.schoolStudentGuardian.findMany({
      where: { guardian: { userId } },
      select: { student: { select: { id: true, firstName: true, lastName: true, class: { select: { name: true } } } } },
    });
    if (links.length === 0) return [];
    const studentOf = new Map(links.map(({ student }) => [student.id, student]));
    const rows = await this.prisma.schoolEarlyExit.findMany({
      where: { studentId: { in: [...studentOf.keys()] } },
      orderBy: { requestedAt: 'desc' },
      take: PARENT_LIST_LIMIT,
    });
    return rows.map((e) => {
      const s = studentOf.get(e.studentId);
      return {
        ...toEarlyExitView(e),
        studentName: s ? studentName(s) : '—',
        className: s?.class?.name ?? '',
        requestedByMe: e.requestedByUserId === userId,
      };
    });
  }

  /** Farzandning oylik davomati (kalendar + jami; o'quv kuni, bugungacha). */
  async monthAttendance(userId: string, query: unknown) {
    const { studentId, month } = parseOrThrow(parentAttendanceQuerySchema, query ?? {});
    const today = tashkentDay(this.clock.now());
    const target = month ?? today.slice(0, 7);
    const { student } = await this.linked(userId, studentId);
    const { first, last } = monthBounds(target);
    const [records, holidays] = await Promise.all([
      this.prisma.schoolAttendance.findMany({
        where: { studentId: student.id, date: { gte: first, lte: last } },
        select: { date: true, status: true, inAt: true, outAt: true },
      }),
      loadHolidays(this.prisma, student.schoolId),
    ]);
    const recordOf = new Map(records.map((r) => [r.date, r]));
    const days = dateRange(first, last).map((date) => {
      const record = recordOf.get(date);
      return {
        date,
        schoolDay: isSchoolDay(date, student.class?.shift, holidays),
        record: record ? { status: record.status, inAt: record.inAt, outAt: record.outAt } : null,
      };
    });
    const summary = days
      .filter((d) => d.schoolDay && d.date <= today)
      .reduce((acc, d) => addCount(acc, d.record?.status ?? null), EMPTY_COUNTS);
    return {
      student: {
        id: student.id,
        name: studentName(student),
        className: student.class?.name ?? '',
        schoolName: student.school.name,
      },
      month: target,
      days,
      summary,
      rate: attendedRate(summary),
    };
  }
}
