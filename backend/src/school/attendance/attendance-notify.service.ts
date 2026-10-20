// Ota-onaga davomat push'lari (Parvoz Parents). Har xabar — o'quvchining
// ilovaga ulangan BARCHA ota-onalariga (`SchoolGuardian.userId`). Takrorlanmaslik:
// `SchoolParentNotice` (o'quvchi + kun + tur + ota-ona — unikal) yozuvi push'dan
// OLDIN yaratiladi; qayta urinish / parallel so'rov / cron qayta ishga tushishi
// ikkinchi push bermaydi. Push xatosi so'rovni buzmaydi (log + davom).

import { Injectable, Logger } from '@nestjs/common';
import { AttendanceStatus, ParentNoticeKind, Prisma, SchoolParentNotice } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { isUniqueViolation } from './attendance-lookups';
import { AttendancePushKey, attendancePushText } from './attendance.i18n';

interface ParentTarget {
  guardianId: string;
  userId: string;
}

export interface AttendanceNotice {
  schoolId: string;
  studentId: string;
  date: string;
  kind: ParentNoticeKind;
  push: AttendancePushKey;
  time: string;
}

export interface DecisionNotice {
  schoolId: string;
  studentId: string;
  date: string;
  requestId: string;
  approved: boolean;
  time: string;
  /** Tasdiq bugungi kun uchun — jurnalga EARLY_EXIT xabari ham yoziladi (panel kabi). */
  logEarlyExit: boolean;
}

/** Holat → push matni (EXCUSED — xabar yo'q). */
export function pushKeyForStatus(status: AttendanceStatus): AttendancePushKey | null {
  const keys: Record<AttendanceStatus, AttendancePushKey | null> = {
    PRESENT: 'arrived',
    LATE: 'late',
    ABSENT: 'absent',
    LEFT_EARLY: 'leftEarly',
    EXCUSED: null,
  };
  return keys[status];
}

@Injectable()
export class AttendanceNotifyService {
  private readonly logger = new Logger(AttendanceNotifyService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
  ) {}

  /** O'quvchining ilovaga ulangan ota-onalari bormi (yozuvdagi `parentNotified` uchun). */
  async hasParentUsers(db: Prisma.TransactionClient | PrismaService, studentId: string): Promise<boolean> {
    const count = await db.schoolStudentGuardian.count({
      where: { studentId, guardian: { userId: { not: null } } },
    });
    return count > 0;
  }

  /** Davomat xabari — har ota-onaga kun + tur bo'yicha bir marta. Yuborilganlar soni. */
  async notifyAttendance(notice: AttendanceNotice): Promise<number> {
    try {
      const name = await this.firstName(notice.studentId);
      if (name === null) return 0;
      const data = { type: 'school_attendance', kind: notice.kind, studentId: notice.studentId, date: notice.date };
      let sent = 0;
      for (const target of await this.targets(notice.studentId)) {
        const row = await this.claim(notice, notice.kind, target.guardianId);
        if (!row) continue;
        const delivered = await this.push(target.userId, notice.push, { name, time: notice.time }, data);
        if (delivered) await this.markDelivered(row.id);
        sent += 1;
      }
      return sent;
    } catch (err) {
      this.logger.warn(`davomat xabari yuborilmadi: ${String(err)}`);
      return 0;
    }
  }

  /** Erta ketish qarori — so'rov PENDING holatidan faqat bir marta chiqadi, shuning uchun bir push. */
  async notifyDecision(notice: DecisionNotice): Promise<number> {
    try {
      const name = await this.firstName(notice.studentId);
      if (name === null) return 0;
      const status = notice.approved ? 'APPROVED' : 'REJECTED';
      const data = { type: 'school_early_exit', status, requestId: notice.requestId, studentId: notice.studentId };
      const key: AttendancePushKey = notice.approved ? 'earlyExitApproved' : 'earlyExitRejected';
      let sent = 0;
      for (const target of await this.targets(notice.studentId)) {
        const row = notice.approved && notice.logEarlyExit ? await this.claim(notice, 'EARLY_EXIT', target.guardianId) : null;
        const delivered = await this.push(target.userId, key, { name, time: notice.time }, data);
        if (row && delivered) await this.markDelivered(row.id);
        sent += 1;
      }
      return sent;
    } catch (err) {
      this.logger.warn(`erta ketish qarori xabari yuborilmadi: ${String(err)}`);
      return 0;
    }
  }

  private async targets(studentId: string): Promise<ParentTarget[]> {
    const links = await this.prisma.schoolStudentGuardian.findMany({
      where: { studentId, guardian: { userId: { not: null } } },
      select: { guardian: { select: { id: true, userId: true } } },
      orderBy: { guardian: { createdAt: 'asc' } },
    });
    return links.flatMap(({ guardian }) => (guardian.userId ? [{ guardianId: guardian.id, userId: guardian.userId }] : []));
  }

  private async firstName(studentId: string): Promise<string | null> {
    const student = await this.prisma.schoolStudent.findUnique({ where: { id: studentId }, select: { firstName: true } });
    return student?.firstName ?? null;
  }

  /** Xabar yozuvini "egallash": allaqachon bor bo'lsa — null (push yuborilmaydi). */
  private async claim(
    notice: { schoolId: string; studentId: string; date: string },
    kind: ParentNoticeKind,
    guardianId: string,
  ): Promise<SchoolParentNotice | null> {
    try {
      return await this.prisma.schoolParentNotice.create({
        data: { schoolId: notice.schoolId, studentId: notice.studentId, date: notice.date, kind, guardianId },
      });
    } catch (err) {
      if (isUniqueViolation(err)) return null;
      throw err;
    }
  }

  private async markDelivered(id: string): Promise<void> {
    await this.prisma.schoolParentNotice.update({ where: { id }, data: { delivered: true } });
  }

  private async push(
    userId: string,
    key: AttendancePushKey,
    params: { name: string; time: string },
    data: Record<string, string>,
  ): Promise<boolean> {
    try {
      const lang = await this.fcm.getUserLang(userId);
      const result = await this.fcm.sendPushToUser(userId, { ...attendancePushText(lang, key, params), data });
      return result.sent > 0;
    } catch (err) {
      this.logger.warn(`davomat push xatosi: ${String(err)}`);
      return false;
    }
  }
}
