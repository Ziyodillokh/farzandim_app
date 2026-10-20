// School Mode — o'qish (panel `schoolModeReads` + `classes.modeNow/modesNow`):
// jonli holat, qurilmalar, siyosat, smenalar, istisnolar. `schoolMode.view`,
// sinf rahbari — faqat o'z sinfi.

import { Injectable } from '@nestjs/common';
import { SchoolDeviceOs } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { allowedClassIds, assertCan, assertClassInScope, classScopeWhere, SchoolActor } from '../auth/school-actor';
import { deviceChildSelect, DeviceModeStatus, deviceStateOf } from '../common/device-state';
import { compareClasses, matchesSearch, runListQuery, sortItems } from '../common/list-query';
import { notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { ModeContext, SchoolModeStore, toEmergencyView, toPolicyView } from './school-mode-store';
import {
  bellPhase,
  classModeState,
  ClassModeState,
  exceptionStatus,
  ExceptionStatus,
  hhmmToMinutes,
  isSchoolDay,
  tashkentMinute,
} from './school-mode-time';
import { deviceFilterSchema, exceptionFilterSchema } from './school-mode.schemas';

type DeviceCounts = Record<DeviceModeStatus, number> & { total: number };
type OsCounts = Record<SchoolDeviceOs, number>;

/** Muammoli qurilmalar ro'yxat boshida. */
const STATUS_RANK: Record<DeviceModeStatus, number> = { NO_PERMISSION: 0, OFFLINE: 1, NO_PHONE: 2, APPLIED: 3 };
const emptyCounts = (): DeviceCounts => ({ APPLIED: 0, NO_PERMISSION: 0, NO_PHONE: 0, OFFLINE: 0, total: 0 });
const emptyOs = (): OsCounts => ({ IOS: 0, ANDROID: 0, NONE: 0 });
const percent = (part: number, total: number) => (total > 0 ? Math.round((part / total) * 100) : 0);
const phoneRate = (c: DeviceCounts) => percent(c.APPLIED, c.total - c.NO_PHONE);

@Injectable()
export class SchoolModeReadsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly store: SchoolModeStore,
  ) {}

  async overview(actor: SchoolActor) {
    assertCan(actor, 'schoolMode.view');
    const now = new Date();
    const today = tashkentDay(now);
    const minute = tashkentMinute(now);
    const ctx = await this.store.context(actor.schoolId, today);
    const classes = await this.classRows(actor, ctx, today, minute, now);
    const usedShifts = new Set(classes.map((c) => c.shiftId));
    const shifts = ctx.shifts
      .filter((s) => usedShifts.size === 0 || usedShifts.has(s.id))
      .map((s) => {
        const own = classes.filter((c) => c.shiftId === s.id);
        return {
          id: s.id,
          name: s.name,
          start: s.start,
          end: s.end,
          phase: bellPhase(s, today, minute, ctx.holidays),
          classCount: own.length,
          restrictedClasses: own.filter((c) => c.state.restricted).length,
        };
      });
    const e = ctx.emergency;
    const [byStaff, emergencyClasses] = await Promise.all([
      e.byStaffId ? this.prisma.schoolStaff.findFirst({ where: { id: e.byStaffId, schoolId: actor.schoolId }, select: { fullName: true } }) : null,
      this.prisma.schoolClass.findMany({ where: { schoolId: actor.schoolId, id: { in: e.classIds } }, select: { id: true, name: true } }),
    ]);
    const classNames = new Map(emergencyClasses.map((c) => [c.id, c.name]));
    const devices = emptyCounts();
    const os = emptyOs();
    for (const r of classes) {
      for (const k of Object.keys(devices) as Array<keyof DeviceCounts>) devices[k] += r.devices[k];
      for (const k of Object.keys(os) as SchoolDeviceOs[]) os[k] += r.os[k];
    }
    return {
      now: now.toISOString(),
      today,
      policyEnabled: ctx.policy.enabled,
      holiday: ctx.holidays[0] ? { id: ctx.holidays[0].id, date: ctx.holidays[0].date, name: ctx.holidays[0].name } : null,
      emergency: {
        ...toEmergencyView(e),
        byName: byStaff?.fullName ?? null,
        classNames: e.classIds.map((id) => classNames.get(id) ?? id),
      },
      shifts,
      totals: {
        classes: classes.length,
        restrictedClasses: classes.filter((c) => c.state.restricted).length,
        devices,
        os,
        appliedRate: phoneRate(devices),
        activeExceptions: classes.reduce((n, c) => n + c.activeExceptions, 0),
      },
      classes,
    };
  }

  /** O'quvchilar qurilmalari (muammolilari birinchi). */
  async devices(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'schoolMode.view');
    const filter = parseOrThrow(deviceFilterSchema, query);
    if (filter.classId) assertClassInScope(actor, filter.classId);
    const now = new Date();
    const allowed = allowedClassIds(actor);
    const [students, excepted] = await Promise.all([
      this.prisma.schoolStudent.findMany({
        where: {
          schoolId: actor.schoolId,
          archived: false,
          ...(allowed && { classId: { in: allowed } }),
          ...(filter.classId && { classId: filter.classId }),
          ...(filter.os && { device: filter.os }),
        },
        select: {
          id: true, lastName: true, firstName: true, studentCode: true, classId: true, device: true,
          class: { select: { name: true } },
          child: { select: deviceChildSelect },
        },
      }),
      this.activeExceptionStudents(actor.schoolId, now),
    ]);
    const rows = students
      .map((s) => {
        const state = deviceStateOf(s, s.child, now);
        return {
          studentId: s.id,
          studentName: `${s.lastName} ${s.firstName}`,
          studentCode: s.studentCode,
          classId: s.classId ?? '',
          className: s.class?.name ?? '—',
          os: s.device,
          status: state.status,
          lastSeenAt: state.lastSeenAt,
          hasException: excepted.has(s.id),
        };
      })
      .filter((r) => !filter.status || r.status === filter.status);
    return runListQuery(rows, filter, {
      searchText: (r) => `${r.studentName} ${r.studentCode} ${r.className}`,
      sorters: {
        name: (r) => r.studentName,
        class: (r) => r.className,
        status: (r) => STATUS_RANK[r.status],
        lastSeen: (r) => (r.lastSeenAt ? Date.parse(r.lastSeenAt) : null),
      },
      defaultSort: 'status',
    });
  }

  async policy(actor: SchoolActor) {
    assertCan(actor, 'schoolMode.view');
    return toPolicyView(await this.store.policy(actor.schoolId));
  }

  /** Smenalar + qaysi sinflar foydalanadi + hozirgi bosqich. */
  async shifts(actor: SchoolActor) {
    assertCan(actor, 'schoolMode.view');
    const now = new Date();
    const today = tashkentDay(now);
    const minute = tashkentMinute(now);
    const [ctx, classes, counts] = await Promise.all([
      this.store.context(actor.schoolId, today),
      this.prisma.schoolClass.findMany({ where: { schoolId: actor.schoolId }, select: { id: true, name: true, grade: true, letter: true, shiftId: true } }),
      this.prisma.schoolStudent.groupBy({ by: ['classId'], where: { schoolId: actor.schoolId, archived: false }, _count: { _all: true } }),
    ]);
    const sizes = new Map(counts.map((c) => [c.classId, c._count._all]));
    return ctx.shifts.map((shift) => {
      const own = classes.filter((c) => c.shiftId === shift.id).sort(compareClasses);
      return {
        ...shift,
        classes: own.map((c) => ({ id: c.id, name: c.name })),
        studentCount: own.reduce((n, c) => n + (sizes.get(c.id) ?? 0), 0),
        lessonCount: shift.periods.filter((p) => p.kind === 'LESSON').length,
        phase: bellPhase(shift, today, minute, ctx.holidays),
      };
    });
  }

  /** Istisnolar — holat bo'yicha (standart: faollari) + har holat soni. */
  async exceptions(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'schoolMode.view');
    const filter = parseOrThrow(exceptionFilterSchema, query);
    const now = new Date();
    const rows = await this.prisma.schoolModeException.findMany({
      where: { schoolId: actor.schoolId, ...classScopeWhere(actor) },
    });
    const [students, classes, staff] = await Promise.all([
      this.prisma.schoolStudent.findMany({ where: { id: { in: rows.map((r) => r.studentId) } }, select: { id: true, lastName: true, firstName: true } }),
      this.prisma.schoolClass.findMany({ where: { schoolId: actor.schoolId }, select: { id: true, name: true } }),
      this.prisma.schoolStaff.findMany({ where: { schoolId: actor.schoolId, id: { in: rows.map((r) => r.byStaffId) } }, select: { id: true, fullName: true } }),
    ]);
    const studentName = new Map(students.map((s) => [s.id, `${s.lastName} ${s.firstName}`]));
    const className = new Map(classes.map((c) => [c.id, c.name]));
    const staffName = new Map(staff.map((s) => [s.id, s.fullName]));
    const all = rows.map((e) => ({
      id: e.id,
      studentId: e.studentId,
      classId: e.classId ?? '',
      from: e.from.toISOString(),
      until: e.until.toISOString(),
      reason: e.reason,
      byStaffId: e.byStaffId,
      revokedAt: e.revokedAt?.toISOString() ?? null,
      studentName: studentName.get(e.studentId) ?? '—',
      className: (e.classId && className.get(e.classId)) || '—',
      byName: staffName.get(e.byStaffId) ?? '—',
      status: exceptionStatus(e, now),
    }));
    const searched = filter.search
      ? all.filter((r) => matchesSearch(`${r.studentName} ${r.className} ${r.reason} ${r.byName}`, filter.search ?? ''))
      : all;
    const counts: Record<ExceptionStatus, number> = { ACTIVE: 0, SCHEDULED: 0, EXPIRED: 0, REVOKED: 0 };
    for (const r of searched) counts[r.status] += 1;
    const status = filter.status ?? 'ACTIVE';
    const items = status === 'ALL' ? searched : searched.filter((r) => r.status === status);
    const sorted =
      status === 'ACTIVE'
        ? sortItems(items, (r) => Date.parse(r.until))
        : status === 'SCHEDULED'
          ? sortItems(items, (r) => Date.parse(r.from))
          : sortItems(items, (r) => Date.parse(r.from), 'desc');
    return { items: sorted, counts };
  }

  /** Sinf sahifasi: hozirgi School Mode holati. */
  async classNow(actor: SchoolActor, classId: string) {
    assertCan(actor, 'classes.view');
    const cls = await this.prisma.schoolClass.findFirst({ where: { id: classId, schoolId: actor.schoolId }, select: { id: true, shiftId: true } });
    if (!cls) throw notFound(classId);
    assertClassInScope(actor, classId);
    const now = new Date();
    const date = tashkentDay(now);
    const minute = tashkentMinute(now);
    const ctx = await this.store.context(actor.schoolId, date);
    return { classId, date, minute, state: this.stateOf(ctx, cls, date, minute) };
  }

  /** Barcha (ruxsat etilgan) sinflarning hozirgi holati. */
  async classesNow(actor: SchoolActor): Promise<Record<string, ClassModeState>> {
    assertCan(actor, 'classes.view');
    const allowed = allowedClassIds(actor);
    const now = new Date();
    const date = tashkentDay(now);
    const minute = tashkentMinute(now);
    const [ctx, classes] = await Promise.all([
      this.store.context(actor.schoolId, date),
      this.prisma.schoolClass.findMany({ where: { schoolId: actor.schoolId, ...(allowed && { id: { in: allowed } }) }, select: { id: true, shiftId: true } }),
    ]);
    return Object.fromEntries(classes.map((c) => [c.id, this.stateOf(ctx, c, date, minute)]));
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  private stateOf(ctx: ModeContext, cls: { id: string; shiftId: string }, date: string, minute: number): ClassModeState {
    const shift = ctx.shifts.find((s) => s.id === cls.shiftId) ?? null;
    return classModeState({ classId: cls.id, shift, policy: ctx.policy, emergency: ctx.emergency, holidays: ctx.holidays }, date, minute);
  }

  private async activeExceptionStudents(schoolId: string, now: Date): Promise<Set<string>> {
    const rows = await this.prisma.schoolModeException.findMany({
      where: { schoolId, revokedAt: null, from: { lte: now }, until: { gt: now } },
      select: { studentId: true },
    });
    return new Set(rows.map((r) => r.studentId));
  }

  private async classRows(actor: SchoolActor, ctx: ModeContext, today: string, minute: number, now: Date) {
    const allowed = allowedClassIds(actor);
    const inScope = allowed ? { in: allowed } : undefined;
    const [classes, students, exceptions] = await Promise.all([
      this.prisma.schoolClass.findMany({
        where: { schoolId: actor.schoolId, ...(inScope && { id: inScope }) },
        include: { homeroom: { select: { fullName: true } } },
      }),
      this.prisma.schoolStudent.findMany({
        where: { schoolId: actor.schoolId, archived: false, ...(inScope && { classId: inScope }) },
        select: { id: true, classId: true, device: true, child: { select: deviceChildSelect } },
      }),
      this.prisma.schoolModeException.findMany({
        where: { schoolId: actor.schoolId, revokedAt: null, from: { lte: now }, until: { gt: now } },
        select: { classId: true },
      }),
    ]);
    const buckets = new Map<string, { devices: DeviceCounts; os: OsCounts }>();
    for (const s of students) {
      if (!s.classId) continue;
      const bucket = buckets.get(s.classId) ?? { devices: emptyCounts(), os: emptyOs() };
      bucket.devices[deviceStateOf(s, s.child, now).status] += 1;
      bucket.devices.total += 1;
      bucket.os[s.device] += 1;
      buckets.set(s.classId, bucket);
    }
    const activeByClass = new Map<string, number>();
    for (const e of exceptions) if (e.classId) activeByClass.set(e.classId, (activeByClass.get(e.classId) ?? 0) + 1);
    const shiftById = new Map(ctx.shifts.map((s) => [s.id, s]));
    // Hozir davom etayotgan smena sinflari birinchi, keyin boshlanadiganlar, oxirida tugaganlar.
    const rank = (shiftId: string) => {
      const s = shiftById.get(shiftId);
      if (!s || !isSchoolDay(today, s, ctx.holidays) || minute >= hhmmToMinutes(s.end)) return 2;
      return minute >= hhmmToMinutes(s.start) ? 0 : 1;
    };
    return [...classes]
      .sort((a, b) => rank(a.shiftId) - rank(b.shiftId) || compareClasses(a, b))
      .map((c) => {
        const bucket = buckets.get(c.id) ?? { devices: emptyCounts(), os: emptyOs() };
        return {
          classId: c.id,
          className: c.name,
          grade: c.grade,
          shiftId: c.shiftId,
          shiftName: shiftById.get(c.shiftId)?.name ?? '',
          homeroomName: c.homeroom?.fullName ?? null,
          state: this.stateOf(ctx, c, today, minute),
          devices: bucket.devices,
          os: bucket.os,
          appliedRate: phoneRate(bucket.devices),
          activeExceptions: activeByClass.get(c.id) ?? 0,
        };
      });
  }
}
