// Parvoz Growth bola ilovasi: o'z oylik davomati. Faqat tokendagi bolaning o'quvchisi;
// oy tekshiruvi va hisob ota-ona ko'rinishi (`AttendanceParentService.monthAttendance`)
// bilan bir xil. Farqi: tizim yozgan "kelmadi" -> `UNKNOWN`, kiosk / QR vaqtlari.

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { requireEnrolledStudent } from '../common/child-student';
import { parseOrThrow } from '../common/school-zod';
import {
  ChildAttendanceDay,
  kioskTimesByDate,
  summarize,
  toChildDay,
  unknownDay,
} from './attendance-child-view';
import { loadHolidays } from './attendance-lookups';
import { AttendanceClock, dateRange, isSchoolDay, monthBounds } from './attendance-time';
import { childMonthQuerySchema } from './attendance.schemas';

@Injectable()
export class AttendanceChildHistoryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: AttendanceClock,
  ) {}

  async month(childUserId: string, query: unknown) {
    const { month } = parseOrThrow(childMonthQuerySchema, query ?? {});
    const today = tashkentDay(this.clock.now());
    const target = month ?? today.slice(0, 7);
    const student = await requireEnrolledStudent(this.prisma, childUserId);
    const { first, last } = monthBounds(target);
    const [records, events, holidays] = await Promise.all([
      this.prisma.schoolAttendance.findMany({
        where: { studentId: student.studentId, date: { gte: first, lte: last } },
        include: { corrections: { select: { byStaffId: true } } },
      }),
      this.prisma.schoolAttendanceEvent.findMany({
        where: { studentId: student.studentId, date: { gte: first, lte: last }, source: { in: ['QR', 'KIOSK'] } },
        select: { at: true, date: true, kind: true },
        orderBy: { at: 'asc' },
      }),
      loadHolidays(this.prisma, student.schoolId),
    ]);
    const kiosk = kioskTimesByDate(events);
    const recordOf = new Map(records.map((r) => [r.date, r]));
    const days: ChildAttendanceDay[] = [];
    for (const date of dateRange(first, last)) {
      const record = recordOf.get(date);
      if (record) {
        days.push(toChildDay(record, kiosk.get(date) ?? null));
      } else if (date < today && date >= student.enrolledAt && isSchoolDay(date, student.shift, holidays)) {
        // Yozuvi yo'q o'tgan o'quv kuni — hech narsa skanerlanmagan / belgilanmagan.
        days.push(unknownDay(date));
      }
    }
    const counted = days.filter((d) => d.date <= today && isSchoolDay(d.date, student.shift, holidays));
    return { month: target, days, summary: summarize(counted) };
  }
}
