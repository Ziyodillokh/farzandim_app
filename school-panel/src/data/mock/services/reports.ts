import { roleHas, type Permission } from '@/auth/permissions';
import type { AgeGroup, IsoDate, IsoWeekday } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { maskSmallCount } from '@/lib/k-anon';
import { percent } from '@/lib/utils';
import { addDays, dateRange, isoWeekday, isSchoolDay, toIsoDate, toLocalIso } from '../calendar';
import { clockNow, clockToday } from '../clock';
import { assertCan, currentActor, latency } from '../context';
import { getTables } from '../db';
import { compareClasses } from '../lookups';
import type { Tables } from '../tables';
import { resolveRecord } from './attendance';
import { computeCareAggregate } from './care-aggregate';
import { effective } from './comms-announcements';

const MONTH_RE = /^\d{4}-(0[1-9]|1[0-2])$/;

export type ClassAttendanceRow = { classId: string; className: string; students: number; rate: number; late: number; absent: number; excused: number };
export type ClassLinkRow = { classId: string; className: string; linked: number; total: number; rate: number };
export type CareGroupRow = { key: AgeGroup; respondents: number; hidden: boolean; wellbeing: number | null };

export type MonthlyReport = {
  month: string;
  /** Hisobotga kirgan oxirgi to'liq kun (bugun hisobga olinmaydi). */
  until: IsoDate | null;
  schoolDays: number;
  generatedAt: string;
  generatedBy: string;
  attendance: {
    rate: number;
    late: number;
    absent: number;
    excused: number;
    byClass: ClassAttendanceRow[];
    byWeekday: Array<{ weekday: IsoWeekday; rate: number }>;
  } | null;
  parents: { linkedStudents: number; totalStudents: number; rate: number; byClass: ClassLinkRow[] } | null;
  schoolMode: { applied: number; noPermission: number; noPhone: number; offline: number; exceptions: number; changes: number } | null;
  messages: { announcements: number; recipients: number; delivered: number; read: number; deliveryRate: number; readRate: number; reminders: number } | null;
  care: { surveys: number; invited: number; respondents: number; participation: number; wellbeing: number | null; requests: string; groups: CareGroupRow[] } | null;
  learning: { avgActiveStudents: number; completedTasks: number; avgScore: number; assignments: number } | null;
};

function monthBounds(month: string): { first: IsoDate; last: IsoDate } {
  const [y, m] = month.split('-').map(Number);
  const lastDay = new Date(y ?? 2026, m ?? 1, 0).getDate();
  return { first: `${month}-01`, last: `${month}-${String(lastDay).padStart(2, '0')}` };
}

function attendanceSection(tables: Tables, days: IsoDate[], today: IsoDate): MonthlyReport['attendance'] {
  const stored = new Map(tables.attendance.map((r) => [r.id, r]));
  const classes = [...tables.classes].sort(compareClasses);
  const weekday = new Map<IsoWeekday, { attended: number; decided: number }>();
  let attended = 0;
  let decided = 0;
  let late = 0;
  let absent = 0;
  let excused = 0;
  const byClass: ClassAttendanceRow[] = classes.map((cls) => {
    const shift = tables.shifts.find((s) => s.id === cls.shiftId);
    const students = tables.students.filter((s) => !s.archived && s.classId === cls.id);
    const row = { attended: 0, decided: 0, late: 0, absent: 0, excused: 0 };
    for (const d of days) {
      if (!shift || !isSchoolDay(d, shift, tables.holidays)) continue;
      const wd = weekday.get(isoWeekday(d)) ?? { attended: 0, decided: 0 };
      for (const s of students) {
        const rec = resolveRecord(tables, s, d, today, stored.get(`${d}:${s.id}`));
        if (!rec) continue;
        const came = rec.status === 'PRESENT' || rec.status === 'LATE' || rec.status === 'LEFT_EARLY';
        row.decided += 1;
        wd.decided += 1;
        if (came) {
          row.attended += 1;
          wd.attended += 1;
        }
        if (rec.status === 'LATE') row.late += 1;
        if (rec.status === 'ABSENT') row.absent += 1;
        if (rec.status === 'EXCUSED') row.excused += 1;
      }
      weekday.set(isoWeekday(d), wd);
    }
    attended += row.attended;
    decided += row.decided;
    late += row.late;
    absent += row.absent;
    excused += row.excused;
    return {
      classId: cls.id,
      className: cls.name,
      students: students.length,
      rate: percent(row.attended, row.decided),
      late: row.late,
      absent: row.absent,
      excused: row.excused,
    };
  });
  return {
    rate: percent(attended, decided),
    late,
    absent,
    excused,
    byClass,
    byWeekday: [...weekday.entries()]
      .sort(([a], [b]) => a - b)
      .map(([wd, v]) => ({ weekday: wd, rate: percent(v.attended, v.decided) })),
  };
}

function parentsSection(tables: Tables): MonthlyReport['parents'] {
  const guardians = new Map(tables.guardians.map((g) => [g.id, g]));
  const isLinked = (ids: string[]) => ids.some((g) => guardians.get(g)?.linkStatus === 'LINKED');
  const active = tables.students.filter((s) => !s.archived);
  const byClass = [...tables.classes].sort(compareClasses).map((cls) => {
    const students = active.filter((s) => s.classId === cls.id);
    const linked = students.filter((s) => isLinked(s.guardianIds)).length;
    return { classId: cls.id, className: cls.name, linked, total: students.length, rate: percent(linked, students.length) };
  });
  const linkedStudents = byClass.reduce((s, r) => s + r.linked, 0);
  return { linkedStudents, totalStudents: active.length, rate: percent(linkedStudents, active.length), byClass };
}

/** Vaqt belgisi berilgan oyga tegishlimi — mahalliy sana bo'yicha (UTC `…Z` yozuvlar ham to'g'ri). */
function inMonth(iso: string | null, month: string): boolean {
  if (!iso) return false;
  const ms = Date.parse(iso);
  return Number.isFinite(ms) && toIsoDate(new Date(ms)).slice(0, 7) === month;
}

/** Oyning oxirgi so'rovnomasi bo'yicha /care bilan bir xil k-anonim natija; qatnashish — oy bo'yicha. */
function careSection(tables: Tables, month: string, today: IsoDate): MonthlyReport['care'] {
  const surveys = tables.careSurveys
    .filter((s) => s.status !== 'DRAFT' && s.weekStart.slice(0, 7) === month)
    .sort((a, b) => a.weekStart.localeCompare(b.weekStart));
  const surveyIds = new Set(surveys.map((s) => s.id));
  const respondents = tables.careResponses.filter((r) => surveyIds.has(r.surveyId)).length;
  const invited = surveys.reduce((s, v) => s + v.invited, 0);
  const requests = maskSmallCount(tables.careRequests.filter((r) => inMonth(r.createdAt, month)).length);
  const latest = surveys[surveys.length - 1];
  const agg = latest ? computeCareAggregate(tables, latest, 'AGE_GROUP', today) : null;
  return {
    surveys: surveys.length,
    invited,
    respondents,
    participation: percent(respondents, invited),
    wellbeing: agg?.overall.WELLBEING ?? null,
    requests,
    groups: (agg?.groups ?? []).map((g) => ({
      key: g.key as AgeGroup,
      respondents: g.hidden ? 0 : g.respondents,
      hidden: g.hidden,
      wellbeing: g.hidden ? null : (g.topicScores?.WELLBEING ?? null),
    })),
  };
}

export const reportsService = {
  /** O'quv yili boshidan joriy oygacha (yangisi birinchi). */
  months(): string[] {
    const tables = getTables();
    const start = tables.school.quarters[0]?.start.slice(0, 7) ?? clockToday().slice(0, 7);
    const end = clockToday().slice(0, 7);
    const out: string[] = [];
    let [y, m] = start.split('-').map(Number) as [number, number];
    while (`${y}-${String(m).padStart(2, '0')}` <= end) {
      out.unshift(`${y}-${String(m).padStart(2, '0')}`);
      m += 1;
      if (m > 12) {
        m = 1;
        y += 1;
      }
    }
    return out;
  },

  /** Oylik umumiy hisobot (direktor / administrator). Bo'lim ruxsat bo'lmasa — null. */
  async monthly(month: string): Promise<MonthlyReport> {
    await latency(150, 300);
    if (!MONTH_RE.test(month)) throw new ServiceError('VALIDATION', 'errors.form.invalid');
    const actor = currentActor();
    assertCan(actor, 'reports.view');
    if (actor.scope !== 'SCHOOL') throw new ServiceError('FORBIDDEN', 'reports.scope');
    const can = (p: Permission) => roleHas(actor.role, p);
    const tables = getTables();
    const today = clockToday();
    const { first, last } = monthBounds(month);
    const yesterday = addDays(today, -1);
    const until = last < yesterday ? last : yesterday;
    const days = until >= first ? dateRange(first, until) : [];
    const anyShiftDay = (d: IsoDate) => tables.shifts.some((s) => isSchoolDay(d, s, tables.holidays));
    const now = clockNow();
    const nowMs = now.getTime();

    const devices = { applied: 0, noPermission: 0, noPhone: 0, offline: 0 };
    for (const d of tables.devices) {
      if (d.status === 'APPLIED') devices.applied += 1;
      else if (d.status === 'NO_PERMISSION') devices.noPermission += 1;
      else if (d.status === 'NO_PHONE') devices.noPhone += 1;
      else devices.offline += 1;
    }

    // Vaqti kelgan rejalashtirilganlar ham yuborilgan (/messages bilan bir xil).
    const sent = tables.announcements.map((a) => effective(tables, a, clockNow())).filter((a) => a.status === 'SENT' && inMonth(a.sentAt, month));
    const recipients = sent.reduce((s, a) => s + a.stats.recipients, 0);
    const delivered = sent.reduce((s, a) => s + a.stats.delivered, 0);
    const read = sent.reduce((s, a) => s + a.stats.read, 0);

    const activity = tables.activity.filter((a) => a.weekStart.slice(0, 7) === month);
    const weeks = new Set(activity.map((a) => a.weekStart)).size;

    return {
      month,
      until: days.length ? until : null,
      schoolDays: days.filter(anyShiftDay).length,
      generatedAt: toLocalIso(now),
      generatedBy: actor.name,
      attendance: can('attendance.history') ? attendanceSection(tables, days, today) : null,
      parents: can('students.view') ? parentsSection(tables) : null,
      schoolMode: can('schoolMode.view')
        ? {
            ...devices,
            exceptions: tables.exceptions.filter((e) => inMonth(e.from, month)).length,
            changes: tables.audit.filter((a) => a.module === 'SCHOOL_MODE' && inMonth(a.at, month)).length,
          }
        : null,
      messages: can('messages.view')
        ? {
            announcements: sent.length,
            recipients,
            delivered,
            read,
            deliveryRate: percent(delivered, recipients),
            readRate: percent(read, recipients),
            reminders: tables.reminders.filter((r) => inMonth(r.sendAt, month) && Date.parse(r.sendAt) <= nowMs).length,
          }
        : null,
      care: can('care.aggregate') ? careSection(tables, month, today) : null,
      learning: can('learning.view')
        ? {
            avgActiveStudents: weeks ? Math.round(activity.reduce((s, a) => s + a.activeStudents, 0) / weeks) : 0,
            completedTasks: activity.reduce((s, a) => s + a.completedTasks, 0),
            avgScore: activity.length ? Math.round(activity.reduce((s, a) => s + a.avgScore, 0) / activity.length) : 0,
            assignments: tables.assignments.filter((a) => inMonth(a.createdAt, month)).length,
          }
        : null,
    };
  },
};
