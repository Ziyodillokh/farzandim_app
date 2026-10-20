// Qo'lda belgilash va tuzatishlar (panel `mark`, `correct`, `corrections`).
// Mavjud holatni o'zgartirish — tuzatish: alohida ruxsat + sabab, tarixda saqlanadi.
// Bugungi holat o'zgarsa ota-onaga xabar (tur bo'yicha kuniga bir marta).

import { Injectable } from '@nestjs/common';
import { Prisma, SchoolClass, SchoolShift, SchoolStudent } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { assertCan, assertClassInScope, classScopeWhere, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { invalid, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { retryOnConflict } from './attendance-arrival.service';
import { classNames, staffNames, studentNames } from './attendance-lookups';
import { AttendanceNotifyService, pushKeyForStatus } from './attendance-notify.service';
import { AttendanceClock, isSchoolDay, tashkentHhmm } from './attendance-time';
import {
  noticeKindFor,
  RecordWithCorrections,
  recordInclude,
  studentName,
  toCorrectionView,
  toRecordView,
} from './attendance-view';
import { correctionSchema, markSchema } from './attendance.schemas';

/** Tuzatishlar ro'yxati chegarasi (eng yangilari). */
const CORRECTIONS_LIMIT = 500;

type Tx = Prisma.TransactionClient;
type StudentWithShift = SchoolStudent & { class: (SchoolClass & { shift: SchoolShift }) | null };

interface WriteResult {
  record: RecordWithCorrections;
  changed: boolean;
}

@Injectable()
export class AttendanceMarkingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
    private readonly clock: AttendanceClock,
    private readonly notify: AttendanceNotifyService,
  ) {}

  /** Xodim qo'lda belgilashi (bugun). Mavjud holatni o'zgartirish — tuzatish (sabab bilan). */
  async mark(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'attendance.mark');
    const data = parseOrThrow(markSchema, input);
    const now = this.clock.now();
    const today = tashkentDay(now);
    const time = tashkentHhmm(now);
    const result = await retryOnConflict(() =>
      this.prisma.$transaction(async (tx): Promise<WriteResult> => {
        const student = await this.findStudent(tx, actor, data.studentId);
        const name = studentName(student);
        const existing = await tx.schoolAttendance.findUnique({
          where: { studentId_date: { studentId: student.id, date: today } },
          include: recordInclude,
        });
        if (existing?.status === data.status) return { record: existing, changed: false };
        const notifies = noticeKindFor(data.status) !== null && (await this.notify.hasParentUsers(tx, student.id));
        const arrived = data.status === 'PRESENT' || data.status === 'LATE';
        if (existing) {
          // Mavjud holatni o'zgartirish — tuzatish: alohida ruxsat (navbatchida yo'q).
          assertCan(actor, 'attendance.correct');
          if (!data.reason) throw invalid('reason: errors.form.required');
          await tx.schoolAttendanceCorrection.create({
            data: { attendanceId: existing.id, at: now, byStaffId: actor.staffId, from: existing.status, to: data.status, reason: data.reason },
          });
          const record = await tx.schoolAttendance.update({
            where: { id: existing.id },
            data: {
              status: data.status,
              ...(arrived && !existing.inAt && { inAt: time }),
              parentNotified: existing.parentNotified || notifies,
            },
            include: recordInclude,
          });
          await this.audit.write(
            actor,
            {
              module: 'ATTENDANCE',
              action: 'attendance.correct',
              summary: `${name}: ${existing.status} → ${data.status}`,
              entityId: record.id,
              params: { name, date: today, from: existing.status, to: data.status },
            },
            tx,
          );
          return { record, changed: true };
        }
        const record = await tx.schoolAttendance.create({
          data: {
            schoolId: actor.schoolId,
            date: today,
            studentId: student.id,
            classId: student.classId,
            status: data.status,
            inAt: arrived ? time : null,
            source: 'MANUAL',
            parentNotified: notifies,
          },
          include: recordInclude,
        });
        if (arrived) {
          await tx.schoolAttendanceEvent.create({
            data: {
              schoolId: actor.schoolId,
              at: now,
              date: today,
              studentId: student.id,
              classId: student.classId,
              kind: 'IN',
              source: 'MANUAL',
              late: data.status === 'LATE',
            },
          });
        }
        await this.audit.write(
          actor,
          {
            module: 'ATTENDANCE',
            action: 'attendance.mark',
            summary: `${name} — ${data.status}`,
            entityId: record.id,
            params: { name, status: data.status },
          },
          tx,
        );
        return { record, changed: true };
      }),
    );
    if (result.changed) await this.notifyStatus(actor.schoolId, result.record, time);
    return toRecordView(result.record);
  }

  /** Tuzatish (bugun yoki o'tgan kun) — sabab majburiy, tarixda saqlanadi. */
  async correct(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'attendance.correct');
    const data = parseOrThrow(correctionSchema, input);
    const now = this.clock.now();
    const today = tashkentDay(now);
    if (data.date > today) throw invalid('date: errors.form.invalidDate');
    const result = await retryOnConflict(() =>
      this.prisma.$transaction(async (tx): Promise<WriteResult> => {
        const student = await this.findStudent(tx, actor, data.studentId);
        const stored = await tx.schoolAttendance.findUnique({
          where: { studentId_date: { studentId: student.id, date: data.date } },
          include: recordInclude,
        });
        const base = stored ?? (await this.materializeAbsent(tx, student, data.date, today));
        if (base.status === data.status) return { record: base, changed: false };
        await tx.schoolAttendanceCorrection.create({
          data: { attendanceId: base.id, at: now, byStaffId: actor.staffId, from: base.status, to: data.status, reason: data.reason },
        });
        const record = await tx.schoolAttendance.update({
          where: { id: base.id },
          data: { status: data.status },
          include: recordInclude,
        });
        const name = studentName(student);
        await this.audit.write(
          actor,
          {
            module: 'ATTENDANCE',
            action: 'attendance.correct',
            summary: `${name} (${data.date}): ${base.status} → ${data.status}`,
            entityId: record.id,
            params: { name, date: data.date, from: base.status, to: data.status },
          },
          tx,
        );
        return { record, changed: true };
      }),
    );
    if (result.changed && data.date === today) await this.notifyStatus(actor.schoolId, result.record, tashkentHhmm(now));
    return toRecordView(result.record);
  }

  /** Barcha tuzatishlar (eng yangisi birinchi). */
  async corrections(actor: SchoolActor) {
    assertCan(actor, 'attendance.correct');
    const rows = await this.prisma.schoolAttendanceCorrection.findMany({
      where: { attendance: { schoolId: actor.schoolId, ...classScopeWhere(actor) } },
      orderBy: { at: 'desc' },
      take: CORRECTIONS_LIMIT,
      include: { attendance: { include: recordInclude } },
    });
    const [names, classes, staff] = await Promise.all([
      studentNames(this.prisma, actor.schoolId, rows.map((c) => c.attendance.studentId)),
      classNames(this.prisma, actor.schoolId, rows.map((c) => c.attendance.classId)),
      staffNames(this.prisma, actor.schoolId, rows.map((c) => c.byStaffId)),
    ]);
    return rows.map((c) => ({
      record: toRecordView(c.attendance),
      studentName: names.get(c.attendance.studentId) ?? '—',
      className: (c.attendance.classId && classes.get(c.attendance.classId)) || '',
      correction: toCorrectionView(c),
      byName: staff.get(c.byStaffId) ?? '—',
    }));
  }

  private async findStudent(tx: Tx, actor: SchoolActor, studentId: string): Promise<StudentWithShift> {
    const student = await tx.schoolStudent.findFirst({
      where: { id: studentId, schoolId: actor.schoolId },
      include: { class: { include: { shift: true } } },
    });
    if (!student) throw notFound(studentId);
    assertClassInScope(actor, student.classId);
    return student;
  }

  /**
   * Yozuvsiz O'TGAN o'quv kuni: "kelmadi" cron'i yozadigan ABSENT (SYSTEM)
   * yozuvi tiklanadi, so'ng odatdagidek tuzatiladi. Bugun / dam olish kuni /
   * qabul qilinishidan oldingi kun — VALIDATION (bugun uchun `mark` ishlatiladi).
   */
  private async materializeAbsent(tx: Tx, student: StudentWithShift, date: string, today: string) {
    const holiday = await tx.schoolHoliday.findUnique({ where: { schoolId_date: { schoolId: student.schoolId, date } } });
    const schoolDay = isSchoolDay(date, student.class?.shift, new Set(holiday ? [date] : []));
    if (date >= today || !schoolDay || date < student.enrolledAt) throw invalid('date: errors.form.invalidDate');
    return tx.schoolAttendance.create({
      data: {
        schoolId: student.schoolId,
        date,
        studentId: student.id,
        classId: student.classId,
        status: 'ABSENT',
        source: 'SYSTEM',
      },
      include: recordInclude,
    });
  }

  private async notifyStatus(schoolId: string, record: RecordWithCorrections, time: string): Promise<void> {
    const kind = noticeKindFor(record.status);
    const push = pushKeyForStatus(record.status);
    if (!kind || !push) return;
    await this.notify.notifyAttendance({
      schoolId,
      studentId: record.studentId,
      date: record.date,
      kind,
      push,
      time: record.inAt ?? time,
    });
  }
}
