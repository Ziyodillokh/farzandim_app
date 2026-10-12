import { roleHas } from '@/auth/permissions';
import type { CareRequestStatus, CareTopicTag, CareUrgency, DeviceModeStatus, IsoDate, ReminderKind, RoleKey } from '@/data/contracts';
import { percent } from '@/lib/utils';
import { addDays, isSchoolDay } from '../calendar';
import { clockMinute, clockNow, clockToday } from '../clock';
import { allowedClassIds, currentActor, inScope, latency } from '../context';
import { getTables } from '../db';
import { compareClasses, studentName } from '../lookups';
import { classModeState } from '../school-mode-state';
import type { Tables } from '../tables';
import { attendedRate, resolveRecord, type DayCounts } from './attendance';
import { computeCareAggregate, defaultSurvey } from './care-aggregate';
import { nextOccurrence } from './comms-reminders';
import { audienceTouchesScope, localIso } from './comms-shared';
import { exceptionStatus } from './school-mode-model';

export type DashboardAlertKind = 'EMERGENCY' | 'EARLY_EXIT' | 'VERIFICATION' | 'CARE_URGENT' | 'CARE_NEW' | 'ABSENT' | 'NO_PERMISSION';
export type DashboardAlert = { kind: DashboardAlertKind; count: number; href: string; tone: 'destructive' | 'warning' | 'info' };

export type ClassToday = { classId: string; className: string; rate: number; arrived: number; total: number; late: number; absent: number };

export type DashboardOverview = {
  date: IsoDate;
  minute: number;
  role: RoleKey;
  actorName: string;
  /** Doiradagi sinflardan kamida bittasi uchun bugun o'quv kunimi. */
  schoolDay: boolean;
  attendance: { counts: DayCounts; rate: number; arrived: number } | null;
  classes: ClassToday[] | null;
  schoolMode: {
    restrictedClasses: number;
    activeClasses: number;
    emergency: boolean;
    devices: Record<DeviceModeStatus, number>;
    activeExceptions: number;
  } | null;
  parents: { linkedStudents: number; totalStudents: number; rate: number; invited: number } | null;
  alerts: DashboardAlert[];
  upcoming: Array<{ id: string; kind: ReminderKind; title: string; sendAt: string }> | null;
  /** Umumlashgan Bola ovozi (k-anonim) — direktor, administrator, psixolog. */
  care: { participation: number; wellbeing: number | null; requestsThisWeek: string } | null;
  /** Murojaatlar qutisi — faqat psixolog (care.individual). */
  careInbox: {
    newCount: number;
    urgentOpen: number;
    inProgress: number;
    meetingsToday: number;
    recent: Array<{ id: string; studentName: string; className: string; topic: CareTopicTag; urgency: CareUrgency; status: CareRequestStatus; createdAt: string }>;
  } | null;
  learning: { activeStudents: number; totalStudents: number; completedTasks: number; avgScore: number; dueThisWeek: number } | null;
};

const EMPTY: DayCounts = { present: 0, late: 0, absent: 0, leftEarly: 0, excused: 0, pending: 0, total: 0 };

function count(counts: DayCounts, status: string | null): DayCounts {
  const next = { ...counts, total: counts.total + 1 };
  if (status === null) next.pending += 1;
  else if (status === 'PRESENT') next.present += 1;
  else if (status === 'LATE') next.late += 1;
  else if (status === 'ABSENT') next.absent += 1;
  else if (status === 'LEFT_EARLY') next.leftEarly += 1;
  else next.excused += 1;
  return next;
}

function sumCounts(a: DayCounts, b: DayCounts): DayCounts {
  return {
    present: a.present + b.present,
    late: a.late + b.late,
    absent: a.absent + b.absent,
    leftEarly: a.leftEarly + b.leftEarly,
    excused: a.excused + b.excused,
    pending: a.pending + b.pending,
    total: a.total + b.total,
  };
}

function attendanceToday(tables: Tables, classIds: Set<string>, today: IsoDate) {
  const stored = new Map(tables.attendance.filter((r) => r.date === today).map((r) => [r.studentId, r]));
  const classes = tables.classes.filter((c) => classIds.has(c.id)).sort(compareClasses);
  let totals = { ...EMPTY };
  const rows: ClassToday[] = [];
  for (const cls of classes) {
    const shift = tables.shifts.find((s) => s.id === cls.shiftId);
    if (!shift || !isSchoolDay(today, shift, tables.holidays)) continue;
    let counts = { ...EMPTY };
    for (const s of tables.students) {
      if (s.archived || s.classId !== cls.id) continue;
      counts = count(counts, resolveRecord(tables, s, today, today, stored.get(s.id))?.status ?? null);
    }
    totals = sumCounts(totals, counts);
    rows.push({
      classId: cls.id,
      className: cls.name,
      rate: attendedRate(counts),
      arrived: counts.present + counts.late + counts.leftEarly,
      total: counts.total,
      late: counts.late,
      absent: counts.absent,
    });
  }
  return { totals, rows };
}

const RECENT_REQUESTS = 5;
const UPCOMING_LIMIT = 5;

function careInbox(tables: Tables, today: IsoDate): DashboardOverview['careInbox'] {
  const open = tables.careRequests.filter((r) => r.status !== 'RESOLVED');
  const students = new Map(tables.students.map((st) => [st.id, st]));
  const classes = new Map(tables.classes.map((c) => [c.id, c.name]));
  const recent = [...open]
    .sort((a, b) => (a.urgency === b.urgency ? b.createdAt.localeCompare(a.createdAt) : a.urgency === 'URGENT' ? -1 : 1))
    .slice(0, RECENT_REQUESTS)
    .map((r) => {
      const st = students.get(r.studentId);
      return {
        id: r.id,
        studentName: st ? studentName(st) : '—',
        className: classes.get(r.classId) ?? '',
        topic: r.topic,
        urgency: r.urgency,
        status: r.status,
        createdAt: r.createdAt,
      };
    });
  return {
    newCount: open.filter((r) => r.status === 'NEW').length,
    urgentOpen: open.filter((r) => r.urgency === 'URGENT').length,
    inProgress: open.filter((r) => r.status === 'IN_PROGRESS' || r.status === 'SCHEDULED').length,
    meetingsToday: open.filter((r) => r.meetingAt?.startsWith(today)).length,
    recent,
  };
}

/** /care sahifasi bilan bir xil hisob (computeCareAggregate) — raqamlar mos tushadi. */
function careAggregate(tables: Tables, today: IsoDate): DashboardOverview['care'] {
  const survey = defaultSurvey(tables.careSurveys);
  if (!survey) return null;
  const agg = computeCareAggregate(tables, survey, 'SCHOOL', today);
  return { participation: agg.participationRate, wellbeing: agg.overall.WELLBEING ?? null, requestsThisWeek: agg.requestsThisWeek };
}

function learningSummary(tables: Tables, classIds: Set<string>, totalStudents: number, today: IsoDate): DashboardOverview['learning'] {
  const latestWeek = tables.activity.reduce((max, a) => (a.weekStart > max ? a.weekStart : max), '');
  const rows = tables.activity.filter((a) => a.weekStart === latestWeek && classIds.has(a.classId));
  const activeStudents = rows.reduce((s, a) => s + a.activeStudents, 0);
  const weekEnd = addDays(today, 7);
  return {
    activeStudents,
    totalStudents,
    completedTasks: rows.reduce((s, a) => s + a.completedTasks, 0),
    avgScore: rows.length ? Math.round(rows.reduce((s, a) => s + a.avgScore, 0) / rows.length) : 0,
    dueThisWeek: tables.assignments.filter((a) => a.dueDate >= today && a.dueDate <= weekEnd && a.classIds.some((c) => classIds.has(c))).length,
  };
}

export const dashboardService = {
  /** Rolga mos bosh sahifa: ruxsat bo'lmagan bo'lim `null` qaytadi. */
  async overview(): Promise<DashboardOverview> {
    await latency(80, 180);
    const actor = currentActor();
    const can = (p: Parameters<typeof roleHas>[1]) => roleHas(actor.role, p);
    const tables = getTables();
    const today = clockToday();
    const minute = clockMinute();
    const nowMs = clockNow().getTime();
    const allowed = allowedClassIds(actor);
    const classIds = new Set(tables.classes.filter((c) => !allowed || allowed.includes(c.id)).map((c) => c.id));
    const students = tables.students.filter((s) => !s.archived && classIds.has(s.classId));
    const studentIds = new Set(students.map((s) => s.id));
    const inScopeClasses = tables.classes.filter((c) => classIds.has(c.id));
    const schoolDay = inScopeClasses.some((c) => {
      const shift = tables.shifts.find((s) => s.id === c.shiftId);
      return Boolean(shift && isSchoolDay(today, shift, tables.holidays));
    });

    const att = can('attendance.view') ? attendanceToday(tables, classIds, today) : null;

    let schoolMode: DashboardOverview['schoolMode'] = null;
    if (can('schoolMode.view')) {
      const states = inScopeClasses.map((c) => classModeState(tables, c, today, minute));
      const devices: Record<DeviceModeStatus, number> = { APPLIED: 0, NO_PERMISSION: 0, NO_PHONE: 0, OFFLINE: 0 };
      for (const d of tables.devices) if (studentIds.has(d.studentId)) devices[d.status] += 1;
      schoolMode = {
        restrictedClasses: states.filter((s) => s.restricted).length,
        activeClasses: states.filter((s) => s.kind === 'LESSON' || s.kind === 'BREAK').length,
        emergency: tables.emergency.active,
        devices,
        activeExceptions: inScope(actor, tables.exceptions).filter((e) => exceptionStatus(e, nowMs) === 'ACTIVE').length,
      };
    }

    let parents: DashboardOverview['parents'] = null;
    if (can('students.view') && !can('care.individual')) {
      const guardians = new Map(tables.guardians.map((g) => [g.id, g]));
      const linkedStudents = students.filter((s) => s.guardianIds.some((g) => guardians.get(g)?.linkStatus === 'LINKED')).length;
      const invited = new Set(students.flatMap((s) => s.guardianIds).filter((g) => guardians.get(g)?.linkStatus === 'INVITED')).size;
      parents = { linkedStudents, totalStudents: students.length, rate: percent(linkedStudents, students.length), invited };
    }

    const alerts: DashboardAlert[] = [];
    const push = (kind: DashboardAlertKind, n: number, href: string, tone: DashboardAlert['tone']) => {
      if (n > 0) alerts.push({ kind, count: n, href, tone });
    };
    if (schoolMode?.emergency) push('EMERGENCY', 1, '/school-mode', 'destructive');
    if (can('care.individual')) {
      const open = tables.careRequests.filter((r) => r.status !== 'RESOLVED');
      push('CARE_URGENT', open.filter((r) => r.urgency === 'URGENT').length, '/care/requests', 'destructive');
      push('CARE_NEW', open.filter((r) => r.status === 'NEW').length, '/care/requests', 'info');
    }
    if (can('attendance.earlyExit')) {
      push('EARLY_EXIT', inScope(actor, tables.earlyExits).filter((e) => e.status === 'PENDING').length, '/attendance/early-exit', 'warning');
    }
    if (att && can('attendance.view')) push('ABSENT', att.totals.absent, '/attendance', 'warning');
    if (can('payments.manage')) push('VERIFICATION', tables.verifications.filter((v) => v.status === 'OPEN').length, '/reminders/verifications', 'info');
    if (schoolMode) push('NO_PERMISSION', schoolMode.devices.NO_PERMISSION, '/school-mode', 'info');

    const now = clockNow();
    const upcoming = can('messages.view')
      ? tables.reminders
          .filter((r) => r.active)
          .filter((r) => audienceTouchesScope(actor, tables, r.audience))
          .map((r) => ({ r, next: nextOccurrence(r, now) }))
          .filter((x): x is { r: (typeof tables.reminders)[number]; next: Date } => x.next !== null)
          .sort((a, b) => a.next.getTime() - b.next.getTime())
          .slice(0, UPCOMING_LIMIT)
          .map(({ r, next }) => ({ id: r.id, kind: r.kind, title: r.title, sendAt: localIso(next) }))
      : null;

    return {
      date: today,
      minute,
      role: actor.role,
      actorName: actor.name,
      schoolDay,
      attendance: att
        ? { counts: att.totals, rate: attendedRate(att.totals), arrived: att.totals.present + att.totals.late + att.totals.leftEarly }
        : null,
      classes: att ? att.rows : null,
      schoolMode,
      parents,
      alerts,
      upcoming,
      care: can('care.aggregate') ? careAggregate(tables, today) : null,
      careInbox: can('care.individual') ? careInbox(tables, today) : null,
      learning: can('learning.view') ? learningSummary(tables, classIds, students.length, today) : null,
    };
  },
};
