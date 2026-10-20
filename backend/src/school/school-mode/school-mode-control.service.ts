// School Mode tezkor amallari: o'quvchiga vaqtinchalik istisno (sabab
// majburiy, muddat — shu kun oxirigacha) va favqulodda o'chirish (butun
// maktab yoki sinflar). O'zgarish bola qurilmasiga darhol yetkaziladi.

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { addDays, tashkentDay, tashkentDayStart } from '../../common/time/tashkent';
import { assertCan, assertClassInScope, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, invalid, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { toExceptionView } from '../students/student-view';
import { SchoolModeStore, toEmergencyView } from './school-mode-store';
import { SchoolModeSyncService } from './school-mode-sync.service';
import { exceptionStatus, hhmmToMinutes, tashkentInstant } from './school-mode-time';
import { emergencyInputSchema, exceptionInputSchema, smMsg } from './school-mode.schemas';

/** Istisno kamida shuncha davom etadi. */
export const MIN_EXCEPTION_MS = 5 * 60_000;

/** "HH:MM" — bugungi Toshkent vaqti; aks holda ISO sana-vaqt. */
export function resolveUntil(value: string, now: Date): Date {
  return /^\d{2}:\d{2}$/.test(value) ? tashkentInstant(tashkentDay(now), hhmmToMinutes(value)) : new Date(value);
}

@Injectable()
export class SchoolModeControlService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly store: SchoolModeStore,
    private readonly sync: SchoolModeSyncService,
    private readonly audit: SchoolAuditService,
  ) {}

  async createException(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'schoolMode.exception');
    const data = parseOrThrow(exceptionInputSchema, input);
    const now = new Date();
    const until = resolveUntil(data.until, now);
    if (until.getTime() - now.getTime() < MIN_EXCEPTION_MS) throw invalid(`until: ${smMsg.untilPast}`);
    if (until.getTime() > tashkentDayStart(addDays(tashkentDay(now), 1)).getTime()) {
      throw invalid(`until: ${smMsg.untilTooFar}`);
    }
    const created = await this.prisma.$transaction(async (tx) => {
      const student = await tx.schoolStudent.findFirst({ where: { id: data.studentId, schoolId: actor.schoolId, archived: false } });
      if (!student) throw notFound(data.studentId);
      assertClassInScope(actor, student.classId);
      // Faol yoki rejalashtirilgan istisno bilan ustma-ust tushmasin.
      const overlap = await tx.schoolModeException.count({
        where: { studentId: student.id, revokedAt: null, from: { lt: until }, until: { gt: now } },
      });
      if (overlap > 0) throw conflict(`studentId: ${smMsg.alreadyActive}`);
      const exception = await tx.schoolModeException.create({
        data: {
          schoolId: actor.schoolId,
          studentId: student.id,
          classId: student.classId,
          from: now,
          until,
          reason: data.reason,
          byStaffId: actor.staffId,
        },
      });
      const name = `${student.lastName} ${student.firstName}`;
      await this.audit.write(
        actor,
        {
          module: 'SCHOOL_MODE',
          action: 'exception.create',
          summary: `Vaqtinchalik istisno: ${name}. Sabab: ${data.reason}`,
          entityId: exception.id,
          after: toExceptionView(exception),
          params: { name, reason: data.reason },
        },
        tx,
      );
      return exception;
    });
    void this.sync.resync(actor.schoolId, { studentIds: [created.studentId] });
    return toExceptionView(created);
  }

  async revokeException(actor: SchoolActor, id: string) {
    assertCan(actor, 'schoolMode.exception');
    const now = new Date();
    const revoked = await this.prisma.$transaction(async (tx) => {
      const before = await tx.schoolModeException.findFirst({ where: { id, schoolId: actor.schoolId } });
      if (!before) throw notFound(id);
      assertClassInScope(actor, before.classId);
      const status = exceptionStatus(before, now);
      if (status !== 'ACTIVE' && status !== 'SCHEDULED') throw conflict(id);
      const next = await tx.schoolModeException.update({ where: { id }, data: { revokedAt: now } });
      const student = await tx.schoolStudent.findUnique({ where: { id: before.studentId }, select: { lastName: true, firstName: true } });
      const name = student ? `${student.lastName} ${student.firstName}` : id;
      await this.audit.write(
        actor,
        {
          module: 'SCHOOL_MODE',
          action: 'exception.revoke',
          summary: `Istisno bekor qilindi: ${name}`,
          entityId: id,
          before: toExceptionView(before),
          after: toExceptionView(next),
          params: { name },
        },
        tx,
      );
      return next;
    });
    void this.sync.resync(actor.schoolId, { studentIds: [revoked.studentId] });
    return toExceptionView(revoked);
  }

  /** Favqulodda o'chirish — cheklov darhol to'xtaydi (sinf so'rovi faol sinflarga qo'shiladi). */
  async activateEmergency(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'schoolMode.emergency');
    const data = parseOrThrow(emergencyInputSchema, input);
    const requested = data.scope === 'SCHOOL' ? [] : [...new Set(data.classIds)];
    const next = await this.prisma.$transaction(async (tx) => {
      const before = await this.store.emergency(actor.schoolId, tx);
      // Butun maktab bo'yicha o'chirish faol — uni sinf so'rovi bilan toraytirib bo'lmaydi.
      if (before.active && before.scope === 'SCHOOL') throw conflict(`scope: ${smMsg.emergencySchoolActive}`);
      const classes = await tx.schoolClass.findMany({ where: { schoolId: actor.schoolId, id: { in: requested } }, select: { id: true, name: true } });
      if (classes.length !== requested.length) throw invalid('classIds: errors.form.required');
      const merge = before.active && before.scope === 'CLASS' && data.scope === 'CLASS';
      const classIds = merge ? [...new Set([...before.classIds, ...requested])] : requested;
      const updated = await tx.schoolEmergency.update({
        where: { schoolId: actor.schoolId },
        data: { active: true, scope: data.scope, classIds, reason: data.reason, byStaffId: actor.staffId, at: new Date() },
      });
      const names = await tx.schoolClass.findMany({ where: { id: { in: classIds } }, select: { name: true }, orderBy: [{ grade: 'asc' }, { letter: 'asc' }] });
      const target = data.scope === 'SCHOOL' ? 'butun maktab' : names.map((c) => c.name).join(', ');
      await this.audit.write(
        actor,
        {
          module: 'SCHOOL_MODE',
          action: 'emergency.on',
          summary: `Favqulodda o'chirish (${target}). Sabab: ${data.reason}`,
          before: toEmergencyView(before),
          after: toEmergencyView(updated),
          params: {
            variant: data.scope === 'SCHOOL' ? 'school' : 'classes',
            classes: data.scope === 'SCHOOL' ? '' : target,
            reason: data.reason,
          },
        },
        tx,
      );
      return updated;
    });
    void this.sync.resync(actor.schoolId, next.scope === 'CLASS' ? { classIds: next.classIds } : {});
    return toEmergencyView(next);
  }

  /** Cheklovni qayta yoqish (jadval bo'yicha davom etadi). */
  async deactivateEmergency(actor: SchoolActor) {
    assertCan(actor, 'schoolMode.emergency');
    const { before, next } = await this.prisma.$transaction(async (tx) => {
      const current = await this.store.emergency(actor.schoolId, tx);
      if (!current.active) throw conflict('emergency');
      const updated = await tx.schoolEmergency.update({
        where: { schoolId: actor.schoolId },
        data: { active: false, scope: 'SCHOOL', classIds: [], reason: '', byStaffId: null, at: null },
      });
      await this.audit.write(
        actor,
        {
          module: 'SCHOOL_MODE',
          action: 'emergency.off',
          summary: 'School Mode qayta yoqildi (favqulodda o\'chirish tugatildi)',
          before: toEmergencyView(current),
          after: toEmergencyView(updated),
          params: {},
        },
        tx,
      );
      return { before: current, next: updated };
    });
    void this.sync.resync(actor.schoolId, before.scope === 'CLASS' ? { classIds: before.classIds } : {});
    return toEmergencyView(next);
  }
}
