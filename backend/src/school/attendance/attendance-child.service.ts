// Parvoz Growth (bola ilovasi): kiosk QR'ini skanerlab kirish va bugungi holat.
// Bola `Child` yozuvi `SchoolStudent.childId` orqali maktab o'quvchisiga bog'langan.
// Ikkinchi skanerlash — mavjud yozuv (push yo'q); smena tugagach — chiqish.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { parseOrThrow } from '../common/school-zod';
import { AttendanceArrivalService } from './attendance-arrival.service';
import { CheckInError, KioskTokenService } from './attendance-kiosk-token';
import { AttendanceClock, hhmmToMinutes, isSchoolDay, tashkentMinute } from './attendance-time';
import { SYSTEM_STAFF_ID } from './attendance-view';
import { childCheckInSchema } from './attendance.schemas';

const enrolledInclude = {
  class: { include: { shift: true } },
  school: { select: { name: true, lateAfterMinutes: true } },
} satisfies Prisma.SchoolStudentInclude;

type EnrolledStudent = Prisma.SchoolStudentGetPayload<{ include: typeof enrolledInclude }>;

export type CheckInAction = 'IN' | 'OUT' | 'NONE';

/** QR faqat o'quv kunida, smenadan shuncha oldin / keyin qabul qilinadi (rasm orqali "uzoqdan" belgilashga qarshi). */
export const QR_OPEN_BEFORE_MINUTES = 120;
export const QR_CLOSE_AFTER_MINUTES = 180;

@Injectable()
export class AttendanceChildService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: AttendanceClock,
    private readonly tokens: KioskTokenService,
    private readonly arrival: AttendanceArrivalService,
  ) {}

  /** QR skanerlash: token → maktab, bola shu maktab o'quvchisi bo'lishi shart. */
  async checkIn(userId: string, body: unknown) {
    const { token } = parseOrThrow(childCheckInSchema, body ?? {});
    const now = this.clock.now();
    const childId = await this.childIdOf(userId);
    const schoolId = await this.tokens.verify(token, now);
    const student = await this.prisma.schoolStudent.findFirst({
      where: { childId, schoolId, archived: false },
      include: enrolledInclude,
    });
    const cls = student?.class;
    if (!student || !cls) throw new CheckInError('NOT_ENROLLED');
    await this.assertSchoolHours(schoolId, cls.shift, now);
    const ctx = { schoolId, studentId: student.id, classId: cls.id, source: 'QR' as const, now };
    const existing = await this.prisma.schoolAttendance.findUnique({
      where: { studentId_date: { studentId: student.id, date: tashkentDay(now) } },
    });
    let action: CheckInAction = 'NONE';
    if (existing?.inAt) {
      const leaving =
        !existing.outAt &&
        (existing.status === 'PRESENT' || existing.status === 'LATE') &&
        tashkentMinute(now) >= hhmmToMinutes(cls.shift.end);
      if (leaving && (await this.arrival.depart(ctx, existing.id))) action = 'OUT';
    } else {
      const result = await this.arrival.arrive({
        ...ctx,
        shiftStart: cls.shift.start,
        lateAfterMinutes: student.school.lateAfterMinutes,
        byStaffId: SYSTEM_STAFF_ID,
      });
      action = result.alreadyIn ? 'NONE' : 'IN';
    }
    return { action, today: await this.todayView(student, now) };
  }

  /** Bugungi holat (bog'lanmagan bola — `today: null`). */
  async today(userId: string) {
    const child = await this.prisma.child.findUnique({ where: { childUserId: userId }, select: { id: true } });
    const student = child
      ? await this.prisma.schoolStudent.findFirst({
          where: { childId: child.id, archived: false },
          include: enrolledInclude,
        })
      : null;
    return { today: student ? await this.todayView(student, this.clock.now()) : null };
  }

  private async assertSchoolHours(schoolId: string, shift: { start: string; end: string; weekdays: number[] }, now: Date) {
    const date = tashkentDay(now);
    const minute = tashkentMinute(now);
    const holiday = await this.prisma.schoolHoliday.findUnique({ where: { schoolId_date: { schoolId, date } } });
    const open = hhmmToMinutes(shift.start) - QR_OPEN_BEFORE_MINUTES;
    const close = hhmmToMinutes(shift.end) + QR_CLOSE_AFTER_MINUTES;
    if (!isSchoolDay(date, shift, new Set(holiday ? [date] : [])) || minute < open || minute > close) {
      throw new CheckInError('OUTSIDE_SCHOOL_HOURS');
    }
  }

  private async childIdOf(userId: string): Promise<string> {
    const child = await this.prisma.child.findUnique({ where: { childUserId: userId }, select: { id: true } });
    if (!child) throw new CheckInError('NOT_ENROLLED');
    return child.id;
  }

  private async todayView(student: EnrolledStudent, now: Date) {
    const date = tashkentDay(now);
    const shift = student.class?.shift ?? null;
    const [holiday, record] = await Promise.all([
      this.prisma.schoolHoliday.findUnique({ where: { schoolId_date: { schoolId: student.schoolId, date } } }),
      this.prisma.schoolAttendance.findUnique({ where: { studentId_date: { studentId: student.id, date } } }),
    ]);
    return {
      date,
      schoolName: student.school.name,
      className: student.class?.name ?? null,
      shift: shift ? { name: shift.name, start: shift.start, end: shift.end } : null,
      schoolDay: isSchoolDay(date, shift, new Set(holiday ? [date] : [])),
      record: record ? { status: record.status, inAt: record.inAt, outAt: record.outAt, source: record.source } : null,
    };
  }
}
