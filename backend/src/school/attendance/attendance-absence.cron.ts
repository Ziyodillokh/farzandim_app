// "Kelmadi" cron'i (har 5 daqiqada, Toshkent). Panel simulyatori qoidasi:
// o'quv kunida (smena hafta kuni, bayram emas) smena boshi + lateAfterMinutes
// + 30 daqiqa o'tgach, bugun HECH QANDAY yozuvi yo'q o'quvchiga ABSENT (SYSTEM)
// yoziladi va ota-onaga bir marta "kelmadi" push. Qo'lda / kiosk / QR yozuvlari
// ustidan yozilmaydi; keyin kelsa — kirish uni PRESENT/LATE ga tuzatadi.
// Mock'dan farq: bugun davomati umuman olinmagan sinf (hech kim belgilanmagan
// yoki skanerlanmagan) o'tkazib yuboriladi — maktab bu sinfda tizimdan
// foydalanmayotgan bo'lsa ota-onalarga noto'g'ri "kelmadi" ketmasin.

import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../common/database/prisma.service';
import { isoWeekday, TASHKENT_TZ, tashkentDay } from '../../common/time/tashkent';
import { AttendanceNotifyService } from './attendance-notify.service';
import { hhmmToMinutes, tashkentHhmm, tashkentMinute } from './attendance-time';

/** Kechikish chegarasidan keyin "kelmadi" deb hisoblash uchun qo'shimcha daqiqalar (panel: 30). */
export const ABSENCE_GRACE_MINUTES = 30;

export interface AbsenceSweepResult {
  marked: number;
  notified: number;
}

@Injectable()
export class AttendanceAbsenceCron {
  private readonly logger = new Logger(AttendanceAbsenceCron.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notify: AttendanceNotifyService,
  ) {}

  @Cron('0 */5 * * * *', { name: 'school-attendance-absence', timeZone: TASHKENT_TZ })
  async handleCron(): Promise<void> {
    try {
      const result = await this.sweep(new Date());
      if (result.marked > 0) this.logger.log(`kelmadi: ${result.marked} yozuv, ${result.notified} push`);
    } catch (err) {
      this.logger.error(`kelmadi cron xatosi: ${String(err)}`);
    }
  }

  /** Idempotent: qayta ishga tushirish yangi yozuv ham, ikkinchi push ham bermaydi. */
  async sweep(now: Date = new Date()): Promise<AbsenceSweepResult> {
    const today = tashkentDay(now);
    const minute = tashkentMinute(now);
    const weekday = isoWeekday(today);
    const schools = await this.prisma.school.findMany({
      where: { status: 'ACTIVE', holidays: { none: { date: today } } },
      select: { id: true, lateAfterMinutes: true, shifts: { select: { id: true, start: true, weekdays: true } } },
    });
    const total: AbsenceSweepResult = { marked: 0, notified: 0 };
    for (const school of schools) {
      const due = school.shifts.filter(
        (s) =>
          s.weekdays.includes(weekday) &&
          minute >= hhmmToMinutes(s.start) + school.lateAfterMinutes + ABSENCE_GRACE_MINUTES,
      );
      if (due.length === 0) continue;
      const result = await this.markSchool(school.id, due.map((s) => s.id), today, tashkentHhmm(now));
      total.marked += result.marked;
      total.notified += result.notified;
    }
    return total;
  }

  private async markSchool(schoolId: string, shiftIds: string[], today: string, time: string): Promise<AbsenceSweepResult> {
    const candidates = await this.prisma.schoolStudent.findMany({
      where: {
        schoolId,
        archived: false,
        enrolledAt: { lte: today },
        class: { shiftId: { in: shiftIds } },
        attendance: { none: { date: today } },
      },
      select: { id: true, classId: true },
    });
    const taking = await this.prisma.schoolAttendance.findMany({
      where: { schoolId, date: today, source: { not: 'SYSTEM' }, classId: { not: null } },
      distinct: ['classId'],
      select: { classId: true },
    });
    const takingClasses = new Set(taking.map((r) => r.classId));
    const missing = candidates.filter((s) => s.classId && takingClasses.has(s.classId));
    if (missing.length === 0) return { marked: 0, notified: 0 };
    const created = await this.prisma.schoolAttendance.createMany({
      data: missing.map((s) => ({
        schoolId,
        date: today,
        studentId: s.id,
        classId: s.classId,
        status: 'ABSENT' as const,
        source: 'SYSTEM' as const,
      })),
      skipDuplicates: true,
    });
    // Parallel kirish (QR / kiosk) bo'lgan o'quvchi chetlanadi — faqat cron yozgan ABSENT.
    const absent = await this.prisma.schoolAttendance.findMany({
      where: { schoolId, date: today, studentId: { in: missing.map((s) => s.id) }, status: 'ABSENT', source: 'SYSTEM' },
      select: { id: true, studentId: true },
    });
    let notified = 0;
    for (const row of absent) {
      const sent = await this.notify.notifyAttendance({
        schoolId,
        studentId: row.studentId,
        date: today,
        kind: 'ABSENT',
        push: 'absent',
        time,
      });
      if (sent === 0) continue;
      notified += sent;
      await this.prisma.schoolAttendance.update({ where: { id: row.id }, data: { parentNotified: true } });
    }
    return { marked: created.count, notified };
  }
}
