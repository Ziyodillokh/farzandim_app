// Erta ketish (panel `earlyExits`, `createEarlyExit`, `decideEarlyExit`):
// xodim yoki ota-ona (Parvoz Parents) so'raydi, xodim qaror qiladi. Tasdiq
// (bugun) — o'quvchi "erta ketdi" deb belgilanadi; qaror ota-onaga push qilinadi.

import { Injectable } from '@nestjs/common';
import { EarlyExitStatus } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { actorCan, assertCan, assertClassInScope, classScopeWhere, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { classNames, staffNames, studentNames } from './attendance-lookups';
import { AttendanceNotifyService } from './attendance-notify.service';
import { AttendanceClock } from './attendance-time';
import { studentName, toEarlyExitView } from './attendance-view';
import { decisionSchema, earlyExitInputSchema, earlyExitQuerySchema } from './attendance.schemas';

/** Ro'yxat chegarasi (eng yangilari). */
export const EARLY_EXIT_LIST_LIMIT = 500;

@Injectable()
export class AttendanceEarlyExitService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
    private readonly clock: AttendanceClock,
    private readonly notify: AttendanceNotifyService,
  ) {}

  /** Tarix ruxsati bo'lmasa (navbatchi) — faqat bugungilar. */
  async list(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'attendance.view');
    const { status } = parseOrThrow(earlyExitQuerySchema, query ?? {});
    const onlyToday = !actorCan(actor, 'attendance.history');
    const rows = await this.prisma.schoolEarlyExit.findMany({
      where: {
        schoolId: actor.schoolId,
        ...classScopeWhere(actor),
        ...(status && { status }),
        ...(onlyToday && { date: tashkentDay(this.clock.now()) }),
      },
      orderBy: { requestedAt: 'desc' },
      take: EARLY_EXIT_LIST_LIMIT,
    });
    const [names, classes, staff] = await Promise.all([
      studentNames(this.prisma, actor.schoolId, rows.map((e) => e.studentId)),
      classNames(this.prisma, actor.schoolId, rows.map((e) => e.classId)),
      staffNames(this.prisma, actor.schoolId, rows.map((e) => e.decidedByStaffId)),
    ]);
    return rows.map((e) => ({
      ...toEarlyExitView(e),
      studentName: names.get(e.studentId) ?? '—',
      className: (e.classId && classes.get(e.classId)) || '',
      decidedByName: e.decidedByStaffId ? (staff.get(e.decidedByStaffId) ?? null) : null,
    }));
  }

  async create(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'attendance.earlyExit');
    const data = parseOrThrow(earlyExitInputSchema, input);
    const now = this.clock.now();
    return this.prisma.$transaction(async (tx) => {
      const student = await tx.schoolStudent.findFirst({ where: { id: data.studentId, schoolId: actor.schoolId } });
      if (!student) throw notFound(data.studentId);
      assertClassInScope(actor, student.classId);
      const request = await tx.schoolEarlyExit.create({
        data: {
          schoolId: actor.schoolId,
          studentId: student.id,
          classId: student.classId,
          date: tashkentDay(now),
          time: data.time,
          reason: data.reason,
          pickupBy: data.pickupBy,
          requestedAt: now,
        },
      });
      const name = studentName(student);
      await this.audit.write(
        actor,
        {
          module: 'ATTENDANCE',
          action: 'earlyExit.create',
          summary: `${name} — ${data.time}`,
          entityId: request.id,
          params: { name, time: data.time },
        },
        tx,
      );
      return toEarlyExitView(request);
    });
  }

  /** Tasdiqlash: bugungi yozuv "erta ketdi" bo'ladi; qaror ota-onaga yuboriladi. */
  async decide(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'attendance.earlyExit');
    const { approve } = parseOrThrow(decisionSchema, input);
    const now = this.clock.now();
    const today = tashkentDay(now);
    const status: EarlyExitStatus = approve ? 'APPROVED' : 'REJECTED';
    const request = await this.prisma.$transaction(async (tx) => {
      const found = await tx.schoolEarlyExit.findFirst({ where: { id, schoolId: actor.schoolId } });
      if (!found) throw notFound(id);
      assertClassInScope(actor, found.classId);
      if (found.status !== 'PENDING') throw conflict(found.status);
      // Parallel qarorda faqat bittasi o'tadi (holat sharti bilan yangilash).
      const { count } = await tx.schoolEarlyExit.updateMany({
        where: { id, status: 'PENDING' },
        data: { status, decidedByStaffId: actor.staffId, decidedAt: now },
      });
      if (count === 0) throw conflict('decided');
      const record = approve && found.date === today
        ? await tx.schoolAttendance.findUnique({ where: { studentId_date: { studentId: found.studentId, date: found.date } } })
        : null;
      if (record && record.status !== 'LEFT_EARLY') {
        await tx.schoolAttendanceCorrection.create({
          data: {
            attendanceId: record.id,
            at: now,
            byStaffId: actor.staffId,
            from: record.status,
            to: 'LEFT_EARLY',
            reason: `Erta ketish tasdiqlandi: ${found.reason}`,
          },
        });
        await tx.schoolAttendance.update({ where: { id: record.id }, data: { status: 'LEFT_EARLY', outAt: found.time } });
      }
      const student = await tx.schoolStudent.findUnique({ where: { id: found.studentId } });
      const name = student ? studentName(student) : found.studentId;
      await this.audit.write(
        actor,
        {
          module: 'ATTENDANCE',
          action: approve ? 'earlyExit.approve' : 'earlyExit.reject',
          summary: `${name} — ${found.time}`,
          entityId: found.id,
          params: { name, time: found.time },
        },
        tx,
      );
      return tx.schoolEarlyExit.findUniqueOrThrow({ where: { id } });
    });
    await this.notify.notifyDecision({
      schoolId: actor.schoolId,
      studentId: request.studentId,
      date: request.date,
      requestId: request.id,
      approved: approve,
      time: request.time,
      logEarlyExit: approve && request.date === today,
    });
    return toEarlyExitView(request);
  }
}
