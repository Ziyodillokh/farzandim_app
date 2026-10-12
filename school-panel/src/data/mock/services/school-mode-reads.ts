import type { Paginated, SchoolModePolicy } from '@/data/contracts';
import { matchesSearch } from '@/lib/normalize-search';
import { clockMinute, clockNow, clockToday } from '../clock';
import { allowedClassIds, assertClassInScope, inScope, latency } from '../context';
import { getTables } from '../db';
import { buildIndexes, compareClasses, studentName } from '../lookups';
import { runListQuery, sortItems } from '../query';
import {
  bellPhase,
  buildClassRows,
  deviceStatusOf,
  exceptionStatus,
  requirePolicy,
  STATUS_RANK,
  statusMap,
  sumTotals,
  viewer,
  type DeviceFilter,
  type DeviceRow,
  type ExceptionFilter,
  type ExceptionList,
  type ExceptionRow,
  type ExceptionStatus,
  type SchoolModeOverview,
  type ShiftRow,
} from './school-mode-model';

/** School Mode — o'qish amallari (schoolMode.view, sinf rahbari — faqat o'z sinfi). */
export const schoolModeReads = {
  /** Jonli holat: sinflar, qurilmalar, smenalar, favqulodda holat (doira bo'yicha). */
  async overview(): Promise<SchoolModeOverview> {
    await latency(60, 140);
    const actor = viewer();
    const t = getTables();
    const idx = buildIndexes(t);
    const today = clockToday();
    const minute = clockMinute();
    const now = clockNow();
    const classes = buildClassRows(t, allowedClassIds(actor), today, minute, now.getTime());
    const usedShifts = new Set(classes.map((c) => c.shiftId));
    const shifts = t.shifts
      .filter((s) => usedShifts.size === 0 || usedShifts.has(s.id))
      .map((s) => {
        const own = classes.filter((c) => c.shiftId === s.id);
        return {
          id: s.id,
          name: s.name,
          start: s.start,
          end: s.end,
          phase: bellPhase(s, today, minute, t.holidays),
          classCount: own.length,
          restrictedClasses: own.filter((c) => c.state.restricted).length,
        };
      });
    const e = t.emergency;
    return {
      now: now.toISOString(),
      today,
      policyEnabled: requirePolicy(t).enabled,
      holiday: t.holidays.find((h) => h.date === today) ?? null,
      emergency: {
        ...e,
        byName: e.byStaffId ? (idx.staff.get(e.byStaffId)?.fullName ?? null) : null,
        classNames: e.classIds.map((id) => idx.classes.get(id)?.name ?? id),
      },
      shifts,
      totals: sumTotals(classes),
      classes,
    };
  },

  /** O'quvchilar qurilmalari (muammolilari birinchi). */
  async devices(filter: DeviceFilter = {}): Promise<Paginated<DeviceRow>> {
    await latency(80, 180);
    const actor = viewer();
    if (filter.classId) assertClassInScope(actor, filter.classId);
    const t = getTables();
    const idx = buildIndexes(t);
    const nowMs = clockNow().getTime();
    const excepted = new Set(t.exceptions.filter((e) => exceptionStatus(e, nowMs) === 'ACTIVE').map((e) => e.studentId));
    const lastSeen = new Map(t.devices.map((d) => [d.studentId, d.lastSeenAt]));
    const statuses = statusMap(t);
    const rows: DeviceRow[] = inScope(actor, t.students.filter((s) => !s.archived))
      .map((s) => ({
        studentId: s.id,
        studentName: studentName(s),
        studentCode: s.studentCode,
        classId: s.classId,
        className: idx.classes.get(s.classId)?.name ?? '—',
        os: s.device,
        status: deviceStatusOf(statuses, s),
        lastSeenAt: lastSeen.get(s.id) ?? null,
        hasException: excepted.has(s.id),
      }))
      .filter(
        (r) =>
          (!filter.classId || r.classId === filter.classId) &&
          (!filter.status || r.status === filter.status) &&
          (!filter.os || r.os === filter.os),
      );
    return runListQuery(rows, filter, {
      searchText: (r) => `${r.studentName} ${r.studentCode} ${r.className}`,
      sorters: {
        name: (r) => r.studentName,
        class: (r) => r.className,
        status: (r) => STATUS_RANK[r.status],
        lastSeen: (r) => r.lastSeenAt,
      },
      defaultSort: 'status',
    });
  },

  async policy(): Promise<SchoolModePolicy> {
    await latency(40, 100);
    viewer();
    return requirePolicy(getTables());
  },

  /** Smenalar + qaysi sinflar foydalanadi + hozirgi bosqich. */
  async shifts(): Promise<ShiftRow[]> {
    await latency(40, 100);
    viewer();
    const t = getTables();
    const today = clockToday();
    const minute = clockMinute();
    return t.shifts.map((s) => {
      const classes = t.classes.filter((c) => c.shiftId === s.id).sort(compareClasses);
      const ids = new Set(classes.map((c) => c.id));
      return {
        ...s,
        classes: classes.map((c) => ({ id: c.id, name: c.name })),
        studentCount: t.students.filter((st) => !st.archived && ids.has(st.classId)).length,
        lessonCount: s.periods.filter((p) => p.kind === 'LESSON').length,
        phase: bellPhase(s, today, minute, t.holidays),
      };
    });
  },

  /** Istisnolar — holat bo'yicha (standart: faollari) + har holat soni. */
  async exceptions(filter: ExceptionFilter = {}): Promise<ExceptionList> {
    await latency(60, 140);
    const actor = viewer();
    const t = getTables();
    const idx = buildIndexes(t);
    const nowMs = clockNow().getTime();
    const rows: ExceptionRow[] = inScope(actor, t.exceptions).map((e) => {
      const s = idx.students.get(e.studentId);
      return {
        ...e,
        studentName: s ? studentName(s) : '—',
        className: idx.classes.get(e.classId)?.name ?? '—',
        byName: idx.staff.get(e.byStaffId)?.fullName ?? '—',
        status: exceptionStatus(e, nowMs),
      };
    });
    const query = filter.search ?? '';
    const searched = query ? rows.filter((r) => matchesSearch(`${r.studentName} ${r.className} ${r.reason} ${r.byName}`, query)) : rows;
    const counts: Record<ExceptionStatus, number> = { ACTIVE: 0, EXPIRED: 0, REVOKED: 0 };
    for (const r of searched) counts[r.status] += 1;
    const status = filter.status ?? 'ACTIVE';
    const items = status === 'ALL' ? searched : searched.filter((r) => r.status === status);
    const sorted = status === 'ACTIVE' ? sortItems(items, (r) => Date.parse(r.until)) : sortItems(items, (r) => Date.parse(r.from), 'desc');
    return { items: sorted, counts };
  },
};
