// Kirish / chiqish yadrosi — xodim kioski (`KIOSK`) va Parvoz Growth QR
// (`QR`) uchun umumiy. Panel kiosk qoidasi: bugun kirgan bo'lsa — mavjud
// yozuv (`alreadyIn`); kirishsiz yozuv (masalan cron "kelmadi") bo'lsa —
// tuzatish bilan PRESENT/LATE ga o'tadi; kechikish — smena boshi + lateAfterMinutes.

import { Injectable } from '@nestjs/common';
import { AttendanceSource, AttendanceStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { isUniqueViolation } from './attendance-lookups';
import { AttendanceNotifyService } from './attendance-notify.service';
import { isLateAt, minutesToHhmm, tashkentMinute } from './attendance-time';
import { RecordWithCorrections, recordInclude } from './attendance-view';

export interface ArrivalContext {
  schoolId: string;
  studentId: string;
  classId: string | null;
  shiftStart: string;
  lateAfterMinutes: number;
  source: Extract<AttendanceSource, 'KIOSK' | 'QR'>;
  /** Kiosk — navbatchi xodim; QR — `SYSTEM_STAFF_ID`. */
  byStaffId: string;
  now: Date;
}

export interface ArrivalResult {
  record: RecordWithCorrections;
  alreadyIn: boolean;
}

type Tx = Prisma.TransactionClient;
type AfterWrite = (tx: Tx, record: RecordWithCorrections) => Promise<void>;

const ARRIVAL_REASON: Record<ArrivalContext['source'], string> = {
  KIOSK: 'Kirish nuqtasida qayd etildi',
  QR: 'Parvoz QR orqali qayd etildi',
};

/** Parallel so'rov bir xil (o'quvchi, kun) yozuvini yaratsa — bir marta qayta urinish. */
export async function retryOnConflict<T>(run: () => Promise<T>): Promise<T> {
  try {
    return await run();
  } catch (err) {
    if (!isUniqueViolation(err)) throw err;
    return run();
  }
}

@Injectable()
export class AttendanceArrivalService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notify: AttendanceNotifyService,
  ) {}

  /** Kirishni qayd etish (+ ota-onaga "keldi"/"kechikdi" — faqat yangi kirishda). */
  async arrive(ctx: ArrivalContext, afterWrite?: AfterWrite): Promise<ArrivalResult> {
    const result = await retryOnConflict(() => this.prisma.$transaction((tx) => this.arriveTx(tx, ctx, afterWrite)));
    if (!result.alreadyIn) {
      await this.notify.notifyAttendance({
        schoolId: ctx.schoolId,
        studentId: ctx.studentId,
        date: result.record.date,
        kind: 'ARRIVED',
        push: result.record.status === 'LATE' ? 'late' : 'arrived',
        time: result.record.inAt ?? '',
      });
    }
    return result;
  }

  /**
   * Chiqish: kirgan va hali chiqmagan yozuvga `outAt` + OUT hodisasi, ota-onaga
   * "chiqdi" (bir marta). Parallel skanerlashda faqat bittasi yozadi.
   */
  async depart(ctx: Omit<ArrivalContext, 'shiftStart' | 'lateAfterMinutes' | 'byStaffId'>, recordId: string) {
    const time = minutesToHhmm(Math.floor(tashkentMinute(ctx.now)));
    const record = await this.prisma.$transaction(async (tx) => {
      const { count } = await tx.schoolAttendance.updateMany({
        where: { id: recordId, outAt: null, inAt: { not: null } },
        data: { outAt: time },
      });
      if (count === 0) return null;
      const updated = await tx.schoolAttendance.findUniqueOrThrow({ where: { id: recordId }, include: recordInclude });
      await tx.schoolAttendanceEvent.create({
        data: {
          schoolId: ctx.schoolId,
          at: ctx.now,
          date: updated.date,
          studentId: ctx.studentId,
          classId: ctx.classId,
          kind: 'OUT',
          source: ctx.source,
        },
      });
      return updated;
    });
    if (record) {
      await this.notify.notifyAttendance({
        schoolId: ctx.schoolId,
        studentId: ctx.studentId,
        date: record.date,
        kind: 'LEFT',
        push: 'left',
        time,
      });
    }
    return record;
  }

  private async arriveTx(tx: Tx, ctx: ArrivalContext, afterWrite?: AfterWrite): Promise<ArrivalResult> {
    const date = tashkentDay(ctx.now);
    const minute = tashkentMinute(ctx.now);
    const existing = await tx.schoolAttendance.findUnique({
      where: { studentId_date: { studentId: ctx.studentId, date } },
      include: recordInclude,
    });
    if (existing?.inAt) return { record: existing, alreadyIn: true };
    // Bola o'zi skanerlagan QR xodim qarorini (qo'lda / kiosk) bosib ketmaydi —
    // faqat tizim yozgan "kelmadi"ni tuzatadi (rasm orqali uzoqdan skanerlashga qarshi).
    if (existing && ctx.source === 'QR' && existing.source !== 'SYSTEM') return { record: existing, alreadyIn: true };

    const late = isLateAt(minute, ctx.shiftStart, ctx.lateAfterMinutes);
    const status: AttendanceStatus = late ? 'LATE' : 'PRESENT';
    const inAt = minutesToHhmm(Math.floor(minute));
    const hasParents = await this.notify.hasParentUsers(tx, ctx.studentId);
    if (existing) {
      await tx.schoolAttendanceCorrection.create({
        data: {
          attendanceId: existing.id,
          at: ctx.now,
          byStaffId: ctx.byStaffId,
          from: existing.status,
          to: status,
          reason: ARRIVAL_REASON[ctx.source],
        },
      });
    }
    const data = { status, inAt, source: ctx.source, parentNotified: (existing?.parentNotified ?? false) || hasParents };
    const record = existing
      ? await tx.schoolAttendance.update({ where: { id: existing.id }, data, include: recordInclude })
      : await tx.schoolAttendance.create({
          data: { ...data, schoolId: ctx.schoolId, date, studentId: ctx.studentId, classId: ctx.classId },
          include: recordInclude,
        });
    await tx.schoolAttendanceEvent.create({
      data: {
        schoolId: ctx.schoolId,
        at: ctx.now,
        date,
        studentId: ctx.studentId,
        classId: ctx.classId,
        kind: 'IN',
        source: ctx.source,
        late,
      },
    });
    if (afterWrite) await afterWrite(tx, record);
    return { record, alreadyIn: false };
  }
}
