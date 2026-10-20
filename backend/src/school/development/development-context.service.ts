// Profil konteksti: o'quvchi davomati (oxirgi 30 o'quv kuni — FAQAT sinf rahbariga)
// va sinfning Growth Learning faolligi (joriy hafta, sinf darajasida). Psixologik
// javoblar shifrini ochish — faqat psixolog profili uchun.

import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { addDays, isoWeekday, tashkentDay } from '../../common/time/tashkent';
import { loadHolidays } from '../attendance/attendance-lookups';
import { isSchoolDay } from '../attendance/attendance-time';
import { addCount, attendedRate, EMPTY_COUNTS, percent } from '../attendance/attendance-view';
import { SchoolCryptoService } from '../common/school-crypto.service';
import type { LiveStudent, StudentDevProfile } from './development.types';

const ATTENDANCE_DAYS = 30;
const MAX_LOOKBACK_DAYS = 90;

type Attendance30 = NonNullable<StudentDevProfile['context']['attendance30']>;

@Injectable()
export class DevelopmentContextService {
  private readonly logger = new Logger(DevelopmentContextService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: SchoolCryptoService,
  ) {}

  /** Bugundan oldingi oxirgi 30 o'quv kuni; yozuvsiz kun — belgilanmagan (stavkaga kirmaydi). */
  async attendance30(schoolId: string, student: LiveStudent, today: string): Promise<Attendance30> {
    const empty: Attendance30 = { rate: null, late: 0, absent: 0 };
    if (!student.classId) return empty;
    const cls = await this.prisma.schoolClass.findFirst({ where: { id: student.classId, schoolId }, select: { shift: { select: { weekdays: true } } } });
    if (!cls?.shift) return empty;
    const holidays = await loadHolidays(this.prisma, schoolId);
    const days: string[] = [];
    for (let back = 1; back <= MAX_LOOKBACK_DAYS && days.length < ATTENDANCE_DAYS; back++) {
      const d = addDays(today, -back);
      if (d < student.enrolledAt) break;
      if (isSchoolDay(d, cls.shift, holidays)) days.push(d);
    }
    if (days.length === 0) return empty;
    const records = await this.prisma.schoolAttendance.findMany({
      where: { schoolId, studentId: student.id, date: { in: days } },
      select: { date: true, status: true },
    });
    const statusOf = new Map(records.map((r) => [r.date, r.status]));
    const counts = days.reduce((c, d) => addCount(c, statusOf.get(d) ?? null), EMPTY_COUNTS);
    const decided = counts.total - counts.pending;
    return { rate: decided > 0 ? attendedRate(counts) : null, late: counts.late, absent: counts.absent };
  }

  /** Sinf faolligi (joriy hafta): Parvoz'ga ulangan bola bo'lmasa — null. */
  async classLearning(schoolId: string, classId: string): Promise<StudentDevProfile['context']['classLearning']> {
    const students = await this.prisma.schoolStudent.findMany({ where: { schoolId, classId, archived: false }, select: { childId: true } });
    const children = students.flatMap((s) => (s.childId ? [s.childId] : []));
    if (children.length === 0) return null;
    const today = tashkentDay();
    const monday = addDays(today, 1 - isoWeekday(today));
    const attempts = await this.prisma.learningAttempt.findMany({
      where: { childId: { in: children }, status: 'COMPLETED', day: { gte: monday } },
      select: { childId: true, correct: true, total: true },
    });
    const active = new Set(attempts.map((a) => a.childId)).size;
    const avgScore = attempts.length ? Math.round(attempts.reduce((sum, a) => sum + percent(a.correct, a.total), 0) / attempts.length) : 0;
    return { activeRate: percent(active, students.length), avgScore };
  }

  /** Psixolog profili: o'quvchi natijalarining javoblar varag'i (ixcham kod). */
  async answers(schoolId: string, studentId: string): Promise<Map<string, string>> {
    const rows = await this.prisma.schoolPsychResult.findMany({
      where: { schoolId, studentId, answersEnc: { not: null } },
      select: { id: true, answersEnc: true },
    });
    return new Map(
      rows.flatMap((r) => {
        try {
          return r.answersEnc ? [[r.id, this.crypto.decrypt(r.answersEnc)] as const] : [];
        } catch (err) {
          this.logger.warn(`psych result ${r.id}: answers could not be decrypted (${(err as Error).message})`);
          return [];
        }
      }),
    );
  }
}
