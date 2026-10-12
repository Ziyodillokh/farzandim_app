import type { EmergencyState, IsoWeekday, SchoolModeException, SchoolModePolicy, Shift } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import {
  allowedAppSchema,
  emergencyInputSchema,
  exceptionInputSchema,
  policyPatchSchema,
  remindInputSchema,
  shiftUpdateSchema,
  smMsg,
  type AllowedAppInput,
  type EmergencyInput,
  type ExceptionInput,
  type PolicyPatch,
  type ShiftUpdateInput,
} from '@/data/schemas/school-mode';
import { parseOrThrow } from '@/data/schemas/validate';
import { clockNow } from '../clock';
import { assertCan, assertClassInScope, currentActor, latency, newId, writeAudit } from '../context';
import { transact } from '../db';
import { studentName } from '../lookups';
import { INITIAL_EMERGENCY } from '../seed/school-mode';
import type { Tables } from '../tables';
import {
  assertUntilWindow,
  deviceStatusOf,
  exceptionStatus,
  numberPeriods,
  requirePolicy,
  resolveUntil,
  statusMap,
  viewer,
  type RemindResult,
} from './school-mode-model';
import { schoolModeReads } from './school-mode-reads';

export type {
  BellPhase,
  ClassModeRow,
  ClassModeState,
  DeviceCounts,
  DeviceFilter,
  DeviceRow,
  ExceptionFilter,
  ExceptionList,
  ExceptionRow,
  ExceptionStatus,
  OsCounts,
  OverviewTotals,
  RemindResult,
  SchoolModeOverview,
  ShiftNow,
  ShiftRow,
} from './school-mode-model';

function manager() {
  const actor = currentActor();
  assertCan(actor, 'schoolMode.manage');
  return actor;
}

function replacePolicy(t: Tables, next: SchoolModePolicy): void {
  t.policies = t.policies.map((p) => (p.id === next.id ? next : p));
}

const schoolModeWrites = {
  /** NO_PERMISSION qurilmalar ota-onalariga push-eslatma (demo: audit + hisob). */
  async remindParents(studentIds: string[]): Promise<RemindResult> {
    await latency();
    const actor = viewer();
    const ids = new Set(parseOrThrow(remindInputSchema, studentIds));
    return transact((t) => {
      const targets = t.students.filter((s) => ids.has(s.id));
      for (const s of targets) assertClassInScope(actor, s.classId);
      const statuses = statusMap(t);
      const eligible = targets.filter((s) => deviceStatusOf(statuses, s) === 'NO_PERMISSION');
      if (eligible.length > 0) {
        const summary = `Ota-onalarga School Mode ruxsati eslatmasi yuborildi: ${eligible.length} o'quvchi`;
        writeAudit(t, actor, 'SCHOOL_MODE', 'device.remind', summary, null, null, { studentIds: eligible.map((s) => s.id) });
      }
      return { sent: eligible.length, skipped: ids.size - eligible.length };
    });
  },

  async updatePolicy(input: PolicyPatch): Promise<SchoolModePolicy> {
    await latency();
    const actor = manager();
    const patch = parseOrThrow(policyPatchSchema, input);
    return transact((t) => {
      const before = requirePolicy(t);
      if (patch.shiftIds?.some((id) => !t.shifts.some((s) => s.id === id))) throw new ServiceError('VALIDATION', 'shiftIds');
      const next: SchoolModePolicy = {
        ...before,
        blockedCategories: patch.blockedCategories ?? before.blockedCategories,
        relaxDuringBreaks: patch.relaxDuringBreaks ?? before.relaxDuringBreaks,
        enabled: patch.enabled ?? before.enabled,
        shiftIds: patch.shiftIds ?? before.shiftIds,
      };
      replacePolicy(t, next);
      writeAudit(t, actor, 'SCHOOL_MODE', 'policy.update', `Cheklov siyosati yangilandi: ${next.name}`, next.id, before, next);
      return next;
    });
  },

  async addAllowedApp(input: AllowedAppInput): Promise<SchoolModePolicy> {
    await latency();
    const actor = manager();
    const data = parseOrThrow(allowedAppSchema, input);
    return transact((t) => {
      const policy = requirePolicy(t);
      const exists = policy.allowedApps.some((a) => a.name.toLowerCase() === data.name.toLowerCase());
      if (exists) throw new ServiceError('CONFLICT', `name: ${smMsg.appExists}`);
      const app = { id: newId('app'), ...data };
      const next = { ...policy, allowedApps: [...policy.allowedApps, app] };
      replacePolicy(t, next);
      writeAudit(t, actor, 'SCHOOL_MODE', 'policy.appAdd', `Ruxsat etilgan ilova qo'shildi: ${app.name}`, app.id, null, app);
      return next;
    });
  },

  async removeAllowedApp(appId: string): Promise<SchoolModePolicy> {
    await latency();
    const actor = manager();
    return transact((t) => {
      const policy = requirePolicy(t);
      const app = policy.allowedApps.find((a) => a.id === appId);
      if (!app) throw new ServiceError('NOT_FOUND', appId);
      const next = { ...policy, allowedApps: policy.allowedApps.filter((a) => a.id !== appId) };
      replacePolicy(t, next);
      writeAudit(t, actor, 'SCHOOL_MODE', 'policy.appRemove', `Ruxsat etilgan ilova olib tashlandi: ${app.name}`, appId, app, null);
      return next;
    });
  },

  /** Hafta kunlari va davrlar (raqamlar, smena boshi/oxiri qayta hisoblanadi). */
  async updateShift(id: string, input: ShiftUpdateInput): Promise<Shift> {
    await latency();
    const actor = manager();
    const data = parseOrThrow(shiftUpdateSchema, input);
    return transact((t) => {
      const before = t.shifts.find((s) => s.id === id);
      if (!before) throw new ServiceError('NOT_FOUND', id);
      const periods = numberPeriods(data.periods);
      const weekdays = [...new Set(data.weekdays)].sort((a, b) => a - b) as IsoWeekday[];
      const start = periods[0]?.start ?? before.start;
      const end = periods.at(-1)?.end ?? before.end;
      const next: Shift = { ...before, weekdays, periods, start, end };
      t.shifts = t.shifts.map((s) => (s.id === id ? next : s));
      const lessons = periods.filter((p) => p.kind === 'LESSON').length;
      writeAudit(t, actor, 'SCHOOL_MODE', 'shift.update', `${next.name}: qo'ng'iroq jadvali yangilandi (${lessons} dars, ${start}–${end})`, id, before, next);
      return next;
    });
  },

  /** Vaqtinchalik istisno: sabab majburiy, muddat — shu kun oxirigacha. */
  async createException(input: ExceptionInput): Promise<SchoolModeException> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'schoolMode.exception');
    const data = parseOrThrow(exceptionInputSchema, input);
    const now = clockNow();
    return transact((t) => {
      const student = t.students.find((s) => s.id === data.studentId && !s.archived);
      if (!student) throw new ServiceError('NOT_FOUND', data.studentId);
      assertClassInScope(actor, student.classId);
      const until = resolveUntil(data.until, now);
      assertUntilWindow(until, now);
      if (t.exceptions.some((e) => e.studentId === student.id && exceptionStatus(e, now.getTime()) === 'ACTIVE')) {
        throw new ServiceError('CONFLICT', `studentId: ${smMsg.alreadyActive}`);
      }
      const exception: SchoolModeException = {
        id: newId('exc'),
        studentId: student.id,
        classId: student.classId,
        from: now.toISOString(),
        until: until.toISOString(),
        reason: data.reason,
        byStaffId: actor.staffId,
        revokedAt: null,
      };
      t.exceptions = [...t.exceptions, exception];
      writeAudit(t, actor, 'SCHOOL_MODE', 'exception.create', `Vaqtinchalik istisno: ${studentName(student)}. Sabab: ${data.reason}`, exception.id, null, exception);
      return exception;
    });
  },

  async revokeException(id: string): Promise<SchoolModeException> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'schoolMode.exception');
    const now = clockNow();
    return transact((t) => {
      const before = t.exceptions.find((e) => e.id === id);
      if (!before) throw new ServiceError('NOT_FOUND', id);
      assertClassInScope(actor, before.classId);
      if (exceptionStatus(before, now.getTime()) !== 'ACTIVE') throw new ServiceError('CONFLICT', id);
      const next = { ...before, revokedAt: now.toISOString() };
      t.exceptions = t.exceptions.map((e) => (e.id === id ? next : e));
      const student = t.students.find((s) => s.id === before.studentId);
      writeAudit(t, actor, 'SCHOOL_MODE', 'exception.revoke', `Istisno bekor qilindi: ${student ? studentName(student) : id}`, id, before, next);
      return next;
    });
  },

  /** Favqulodda o'chirish — butun maktab yoki sinflar uchun cheklovni darhol to'xtatadi. */
  async activateEmergency(input: EmergencyInput): Promise<EmergencyState> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'schoolMode.emergency');
    const data = parseOrThrow(emergencyInputSchema, input);
    return transact((t) => {
      const before = t.emergency;
      const requested = data.scope === 'SCHOOL' ? [] : [...new Set(data.classIds)];
      if (requested.some((id) => !t.classes.some((c) => c.id === id))) throw new ServiceError('VALIDATION', 'classIds');
      // Sinf bo'yicha o'chirish faol bo'lsa — yangi sinflar qo'shiladi.
      const merge = before.active && before.scope === 'CLASS' && data.scope === 'CLASS';
      const classIds = merge ? [...new Set([...before.classIds, ...requested])] : requested;
      const next: EmergencyState = { active: true, scope: data.scope, classIds, reason: data.reason, byStaffId: actor.staffId, at: clockNow().toISOString() };
      t.emergency = next;
      const target = data.scope === 'SCHOOL' ? 'butun maktab' : classIds.map((id) => t.classes.find((c) => c.id === id)?.name ?? id).join(', ');
      writeAudit(t, actor, 'SCHOOL_MODE', 'emergency.on', `Favqulodda o'chirish (${target}). Sabab: ${data.reason}`, null, before, next);
      return next;
    });
  },

  /** Cheklovni qayta yoqish (jadval bo'yicha davom etadi). */
  async deactivateEmergency(): Promise<EmergencyState> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'schoolMode.emergency');
    return transact((t) => {
      const before = t.emergency;
      if (!before.active) throw new ServiceError('CONFLICT', 'emergency');
      const next: EmergencyState = { ...INITIAL_EMERGENCY, classIds: [] };
      t.emergency = next;
      writeAudit(t, actor, 'SCHOOL_MODE', 'emergency.off', 'School Mode qayta yoqildi (favqulodda o\'chirish tugatildi)', null, before, next);
      return next;
    });
  },
};

export const schoolModeService = { ...schoolModeReads, ...schoolModeWrites };
