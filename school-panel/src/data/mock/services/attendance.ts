import type {
  AttendanceEvent,
  AttendanceRecord,
  AttendanceStatus,
  EarlyExitRequest,
  EntryToken,
  IsoDate,
  ParentNotification,
  SchoolClass,
  Student,
} from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { correctionSchema, earlyExitInputSchema, type CorrectionInput, type EarlyExitInput } from '@/data/schemas/attendance';
import { parseOrThrow } from '@/data/schemas/validate';
import { hashString } from '@/lib/rng';
import { hhmmToMinutes, minutesToHhmm, percent } from '@/lib/utils';
import { planDay, recordFromPlan } from '../attendance-plan';
import { addDays, dateRange, isSchoolDay } from '../calendar';
import { clockMinute, clockNow, clockToday } from '../clock';
import { assertCan, assertClassInScope, currentActor, inScope, latency, newId, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { buildIndexes, compareClasses, studentName } from '../lookups';
import type { Tables } from '../tables';

export type DayCounts = { present: number; late: number; absent: number; leftEarly: number; excused: number; pending: number; total: number };

export type ClassBoardRow = {
  classId: string;
  className: string;
  grade: number;
  shiftName: string;
  homeroomName: string | null;
  counts: DayCounts;
  /** Kelganlar ulushi (kelgan + kechikkan + erta ketgan) / jami. */
  rate: number;
  schoolDay: boolean;
};

export type StudentDayRow = {
  studentId: string;
  name: string;
  studentCode: string;
  classId: string;
  className: string;
  device: Student['device'];
  record: AttendanceRecord | null;
};

export type FeedItem = AttendanceEvent & { studentName: string; className: string };

const EMPTY: DayCounts = { present: 0, late: 0, absent: 0, leftEarly: 0, excused: 0, pending: 0, total: 0 };

function addCount(counts: DayCounts, status: AttendanceStatus | null): DayCounts {
  const next = { ...counts, total: counts.total + 1 };
  if (status === null) next.pending += 1;
  else if (status === 'PRESENT') next.present += 1;
  else if (status === 'LATE') next.late += 1;
  else if (status === 'ABSENT') next.absent += 1;
  else if (status === 'LEFT_EARLY') next.leftEarly += 1;
  else next.excused += 1;
  return next;
}

export function attendedRate(c: DayCounts): number {
  const decided = c.total - c.pending;
  return percent(c.present + c.late + c.leftEarly, decided);
}

/**
 * Berilgan kun uchun o'quvchi yozuvi: bugun — saqlangan (jonli); o'tgan kun —
 * saqlangan tuzatish yoki rejadan hisoblangan; kelajak — null.
 */
export function resolveRecord(tables: Tables, student: Student, date: IsoDate, today: IsoDate, stored?: AttendanceRecord): AttendanceRecord | null {
  if (stored) return stored;
  if (date >= today) return null;
  const cls = tables.classes.find((c) => c.id === student.classId);
  const shift = cls ? tables.shifts.find((s) => s.id === cls.shiftId) : undefined;
  if (!cls || !shift) return null;
  const plan = planDay(student, cls, shift, date, tables.holidays, tables.school.lateAfterMinutes);
  return plan ? recordFromPlan(student, date, plan, true) : null;
}

function storedMap(tables: Tables, date: IsoDate): Map<string, AttendanceRecord> {
  return new Map(tables.attendance.filter((r) => r.date === date).map((r) => [r.studentId, r]));
}

function isClassSchoolDay(tables: Tables, cls: SchoolClass, date: IsoDate): boolean {
  const shift = tables.shifts.find((s) => s.id === cls.shiftId);
  return Boolean(shift && isSchoolDay(date, shift, tables.holidays));
}

/** Kiosk kodi: 30 soniyalik oyna, 6 raqam (xeshdan). */
const TOKEN_WINDOW_MS = 30_000;
function tokenFor(windowIndex: number): string {
  return String(hashString(`pnm-kiosk-${windowIndex}`) % 1_000_000).padStart(6, '0');
}

export const attendanceService = {
  /** Sinflar bo'yicha kun taxtasi. */
  async board(date?: IsoDate): Promise<{ date: IsoDate; rows: ClassBoardRow[]; totals: DayCounts }> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'attendance.view');
    const tables = getTables();
    const today = clockToday();
    const day = date ?? today;
    if (day !== today) assertCan(actor, 'attendance.history');
    const idx = buildIndexes(tables);
    const stored = storedMap(tables, day);
    const classes = inScope(actor, tables.classes.map((c) => ({ ...c, classId: c.id }))).sort(compareClasses);
    let totals = { ...EMPTY };
    const rows: ClassBoardRow[] = classes.map((cls) => {
      const schoolDay = isClassSchoolDay(tables, cls, day);
      let counts = { ...EMPTY };
      if (schoolDay) {
        for (const s of tables.students) {
          if (s.archived || s.classId !== cls.id) continue;
          const rec = resolveRecord(tables, s, day, today, stored.get(s.id));
          counts = addCount(counts, rec?.status ?? null);
        }
      }
      totals = {
        present: totals.present + counts.present,
        late: totals.late + counts.late,
        absent: totals.absent + counts.absent,
        leftEarly: totals.leftEarly + counts.leftEarly,
        excused: totals.excused + counts.excused,
        pending: totals.pending + counts.pending,
        total: totals.total + counts.total,
      };
      return {
        classId: cls.id,
        className: cls.name,
        grade: cls.grade,
        shiftName: idx.shifts.get(cls.shiftId)?.name ?? '',
        homeroomName: cls.homeroomStaffId ? (idx.staff.get(cls.homeroomStaffId)?.fullName ?? null) : null,
        counts,
        rate: attendedRate(counts),
        schoolDay,
      };
    });
    return { date: day, rows, totals };
  },

  /** Bitta sinfning kun ro'yxati. */
  async classDay(classId: string, date?: IsoDate): Promise<{ date: IsoDate; className: string; rows: StudentDayRow[] }> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'attendance.view');
    assertClassInScope(actor, classId);
    const tables = getTables();
    const today = clockToday();
    const day = date ?? today;
    if (day !== today) assertCan(actor, 'attendance.history');
    const cls = tables.classes.find((c) => c.id === classId);
    if (!cls) throw new ServiceError('NOT_FOUND', classId);
    const stored = storedMap(tables, day);
    const rows = tables.students
      .filter((s) => !s.archived && s.classId === classId)
      .sort((a, b) => studentName(a).localeCompare(studentName(b), 'uz'))
      .map((s) => ({
        studentId: s.id,
        name: studentName(s),
        studentCode: s.studentCode,
        classId: s.classId,
        className: cls.name,
        device: s.device,
        record: isClassSchoolDay(tables, cls, day) ? resolveRecord(tables, s, day, today, stored.get(s.id)) : null,
      }));
    return { date: day, className: cls.name, rows };
  },

  /** Bugungi jonli oqim (eng yangisi birinchi). */
  async feed(options: { classId?: string; limit?: number } = {}): Promise<FeedItem[]> {
    await latency(40, 100);
    const actor = currentActor();
    assertCan(actor, 'attendance.view');
    if (options.classId) assertClassInScope(actor, options.classId);
    const tables = getTables();
    const idx = buildIndexes(tables);
    const events = inScope(actor, tables.attendanceEvents)
      .filter((e) => !options.classId || e.classId === options.classId)
      .sort((a, b) => b.at.localeCompare(a.at))
      .slice(0, options.limit ?? 50);
    return events.map((e) => {
      const s = idx.students.get(e.studentId);
      return { ...e, studentName: s ? studentName(s) : '—', className: idx.classes.get(e.classId)?.name ?? '' };
    });
  },

  /** Xodim qo'lda belgilashi (bugun). Mavjud holatni o'zgartirish — tuzatish (sabab bilan). */
  async mark(studentId: string, status: AttendanceStatus, reason = ''): Promise<AttendanceRecord> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'attendance.mark');
    const today = clockToday();
    return transact((tables) => {
      const student = tables.students.find((s) => s.id === studentId);
      if (!student) throw new ServiceError('NOT_FOUND', studentId);
      assertClassInScope(actor, student.classId);
      const existing = tables.attendance.find((r) => r.date === today && r.studentId === studentId);
      const time = minutesToHhmm(Math.floor(clockMinute()));
      if (existing) {
        if (existing.status === status) return existing;
        if (!reason.trim()) throw new ServiceError('VALIDATION', 'reason');
        existing.corrections.push({ at: clockNow().toISOString(), byStaffId: actor.staffId, from: existing.status, to: status, reason: reason.trim() });
        existing.status = status;
        if ((status === 'PRESENT' || status === 'LATE') && !existing.inAt) existing.inAt = time;
        writeAudit(tables, actor, 'ATTENDANCE', 'attendance.correct', `${studentName(student)}: ${existing.corrections.at(-1)?.from} → ${status}`, existing.id);
        return existing;
      }
      const record: AttendanceRecord = {
        id: `${today}:${studentId}`,
        date: today,
        studentId,
        classId: student.classId,
        status,
        inAt: status === 'PRESENT' || status === 'LATE' ? time : null,
        outAt: null,
        source: 'MANUAL',
        corrections: [],
        parentNotified: status !== 'EXCUSED',
      };
      tables.attendance.push(record);
      if (record.inAt) {
        tables.attendanceEvents.push({ id: `${today}:${studentId}:IN`, at: clockNow().toISOString(), studentId, classId: student.classId, kind: 'IN', source: 'MANUAL', late: status === 'LATE' });
      }
      writeAudit(tables, actor, 'ATTENDANCE', 'attendance.mark', `${studentName(student)} — ${status}`, record.id);
      return record;
    });
  },

  /** Tuzatish (bugun yoki o'tgan kun) — sabab majburiy, tarixda saqlanadi. */
  async correct(input: CorrectionInput): Promise<AttendanceRecord> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'attendance.correct');
    const data = parseOrThrow(correctionSchema, input);
    const today = clockToday();
    if (data.date > today) throw new ServiceError('VALIDATION', 'date');
    return transact((tables) => {
      const student = tables.students.find((s) => s.id === data.studentId);
      if (!student) throw new ServiceError('NOT_FOUND', data.studentId);
      assertClassInScope(actor, student.classId);
      const stored = tables.attendance.find((r) => r.date === data.date && r.studentId === student.id);
      const base = stored ?? resolveRecord(tables, student, data.date, today);
      if (!base) throw new ServiceError('VALIDATION', 'not a school day');
      const record: AttendanceRecord = stored ?? { ...base, corrections: [] };
      if (record.status === data.status) return record;
      record.corrections.push({ at: clockNow().toISOString(), byStaffId: actor.staffId, from: record.status, to: data.status, reason: data.reason });
      record.status = data.status;
      if (!stored) tables.attendance.push(record);
      writeAudit(tables, actor, 'ATTENDANCE', 'attendance.correct', `${studentName(student)} (${data.date}): ${record.corrections.at(-1)?.from} → ${data.status}`, record.id);
      return record;
    });
  },

  /** Barcha tuzatishlar (eng yangisi birinchi). */
  async corrections(): Promise<Array<{ record: AttendanceRecord; studentName: string; className: string; correction: AttendanceRecord['corrections'][number]; byName: string }>> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'attendance.correct');
    const tables = getTables();
    const idx = buildIndexes(tables);
    const out = [];
    for (const record of inScope(actor, tables.attendance)) {
      for (const correction of record.corrections) {
        const s = idx.students.get(record.studentId);
        out.push({
          record,
          studentName: s ? studentName(s) : '—',
          className: idx.classes.get(record.classId)?.name ?? '',
          correction,
          byName: idx.staff.get(correction.byStaffId)?.fullName ?? '—',
        });
      }
    }
    return out.sort((a, b) => b.correction.at.localeCompare(a.correction.at));
  },

  // ─── Kirish nuqtasi (kiosk) ─────────────────────────────────────

  currentToken(): EntryToken {
    const now = Date.now();
    const windowIndex = Math.floor(now / TOKEN_WINDOW_MS);
    return {
      code: tokenFor(windowIndex),
      issuedAt: new Date(windowIndex * TOKEN_WINDOW_MS).toISOString(),
      expiresAt: new Date((windowIndex + 1) * TOKEN_WINDOW_MS).toISOString(),
    };
  },

  /** Joriy yoki oldingi oynadagi kod qabul qilinadi (tarmoq kechikishi uchun). */
  verifyToken(code: string): boolean {
    const windowIndex = Math.floor(Date.now() / TOKEN_WINDOW_MS);
    return code === tokenFor(windowIndex) || code === tokenFor(windowIndex - 1);
  },

  /** Kiosk: o'quvchi kodi (P-1234) yoki ID bo'yicha kirishni qayd etish. */
  async checkIn(codeOrId: string): Promise<{ student: Student; className: string; status: AttendanceStatus; alreadyIn: boolean }> {
    await latency(80, 160);
    const actor = currentActor();
    assertCan(actor, 'attendance.kiosk');
    const today = clockToday();
    const minute = clockMinute();
    const query = codeOrId.trim().toUpperCase();
    return transact((tables) => {
      const student = tables.students.find((s) => !s.archived && (s.studentCode.toUpperCase() === query || s.id === codeOrId));
      if (!student) throw new ServiceError('NOT_FOUND', codeOrId);
      const cls = tables.classes.find((c) => c.id === student.classId);
      const shift = cls ? tables.shifts.find((s) => s.id === cls.shiftId) : undefined;
      if (!cls || !shift) throw new ServiceError('NOT_FOUND', student.classId);
      const existing = tables.attendance.find((r) => r.date === today && r.studentId === student.id);
      if (existing && existing.inAt) return { student, className: cls.name, status: existing.status, alreadyIn: true };
      const late = minute > hhmmToMinutes(shift.start) + tables.school.lateAfterMinutes;
      const status: AttendanceStatus = late ? 'LATE' : 'PRESENT';
      const time = minutesToHhmm(Math.floor(minute));
      if (existing) {
        existing.corrections.push({ at: clockNow().toISOString(), byStaffId: actor.staffId, from: existing.status, to: status, reason: 'Kirish nuqtasida qayd etildi' });
        existing.status = status;
        existing.inAt = time;
        existing.source = 'KIOSK';
      } else {
        tables.attendance.push({ id: `${today}:${student.id}`, date: today, studentId: student.id, classId: student.classId, status, inAt: time, outAt: null, source: 'KIOSK', corrections: [], parentNotified: true });
      }
      tables.attendanceEvents.push({ id: `${today}:${student.id}:IN`, at: clockNow().toISOString(), studentId: student.id, classId: student.classId, kind: 'IN', source: 'KIOSK', late });
      const guardian = student.guardianIds.map((id) => tables.guardians.find((g) => g.id === id)).find((g) => g?.linkStatus === 'LINKED');
      if (guardian) {
        tables.parentNotifications.push({ id: newId('ntf'), at: clockNow().toISOString(), studentId: student.id, guardianId: guardian.id, kind: 'ARRIVED', delivered: true });
      }
      writeAudit(tables, actor, 'ATTENDANCE', 'attendance.kiosk', `${studentName(student)} (${cls.name}) — ${status}`, `${today}:${student.id}`);
      return { student, className: cls.name, status, alreadyIn: false };
    });
  },

  /** Kiosk qidiruvi (ism yoki kod bo'yicha, telefonsiz o'quvchi uchun). */
  async kioskSearch(query: string): Promise<Array<{ id: string; name: string; className: string; studentCode: string; inToday: boolean }>> {
    const actor = currentActor();
    assertCan(actor, 'attendance.kiosk');
    const q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    const tables = getTables();
    const idx = buildIndexes(tables);
    const today = clockToday();
    const inToday = new Set(tables.attendance.filter((r) => r.date === today && r.inAt).map((r) => r.studentId));
    return tables.students
      .filter((s) => !s.archived && (studentName(s).toLowerCase().includes(q) || s.studentCode.toLowerCase().includes(q)))
      .slice(0, 8)
      .map((s) => ({ id: s.id, name: studentName(s), className: idx.classes.get(s.classId)?.name ?? '', studentCode: s.studentCode, inToday: inToday.has(s.id) }));
  },

  // ─── Erta ketish ─────────────────────────────────────────────────

  async earlyExits(status?: EarlyExitRequest['status']): Promise<Array<EarlyExitRequest & { studentName: string; className: string; decidedByName: string | null }>> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'attendance.view');
    const tables = getTables();
    const idx = buildIndexes(tables);
    return inScope(actor, tables.earlyExits)
      .filter((e) => !status || e.status === status)
      .sort((a, b) => b.requestedAt.localeCompare(a.requestedAt))
      .map((e) => {
        const s = idx.students.get(e.studentId);
        return {
          ...e,
          studentName: s ? studentName(s) : '—',
          className: idx.classes.get(e.classId)?.name ?? '',
          decidedByName: e.decidedByStaffId ? (idx.staff.get(e.decidedByStaffId)?.fullName ?? null) : null,
        };
      });
  },

  async createEarlyExit(input: EarlyExitInput): Promise<EarlyExitRequest> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'attendance.earlyExit');
    const data = parseOrThrow(earlyExitInputSchema, input);
    return transact((tables) => {
      const student = tables.students.find((s) => s.id === data.studentId);
      if (!student) throw new ServiceError('NOT_FOUND', data.studentId);
      assertClassInScope(actor, student.classId);
      const request: EarlyExitRequest = {
        id: newId('exit'),
        studentId: student.id,
        classId: student.classId,
        date: clockToday(),
        time: data.time,
        reason: data.reason,
        pickupBy: data.pickupBy,
        status: 'PENDING',
        requestedAt: clockNow().toISOString(),
        decidedByStaffId: null,
        decidedAt: null,
      };
      tables.earlyExits.push(request);
      writeAudit(tables, actor, 'ATTENDANCE', 'earlyExit.create', `${studentName(student)} — ${data.time}`, request.id);
      return request;
    });
  },

  /** Tasdiqlash: o'quvchi "erta ketdi" deb belgilanadi va ota-onaga xabar ketadi. */
  async decideEarlyExit(id: string, approve: boolean): Promise<EarlyExitRequest> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'attendance.earlyExit');
    return transact((tables) => {
      const request = tables.earlyExits.find((e) => e.id === id);
      if (!request) throw new ServiceError('NOT_FOUND', id);
      assertClassInScope(actor, request.classId);
      if (request.status !== 'PENDING') throw new ServiceError('CONFLICT', request.status);
      request.status = approve ? 'APPROVED' : 'REJECTED';
      request.decidedByStaffId = actor.staffId;
      request.decidedAt = clockNow().toISOString();
      const student = tables.students.find((s) => s.id === request.studentId);
      if (approve && student && request.date === clockToday()) {
        const record = tables.attendance.find((r) => r.date === request.date && r.studentId === student.id);
        if (record) {
          record.corrections.push({ at: request.decidedAt, byStaffId: actor.staffId, from: record.status, to: 'LEFT_EARLY', reason: `Erta ketish tasdiqlandi: ${request.reason}` });
          record.status = 'LEFT_EARLY';
          record.outAt = request.time;
        }
        const guardian = student.guardianIds.map((gid) => tables.guardians.find((g) => g.id === gid)).find((g) => g?.linkStatus === 'LINKED');
        if (guardian) {
          tables.parentNotifications.push({ id: newId('ntf'), at: request.decidedAt, studentId: student.id, guardianId: guardian.id, kind: 'EARLY_EXIT', delivered: true });
        }
      }
      writeAudit(tables, actor, 'ATTENDANCE', approve ? 'earlyExit.approve' : 'earlyExit.reject', `${student ? studentName(student) : request.studentId} — ${request.time}`, request.id);
      return request;
    });
  },

  // ─── Ota-onaga xabarlar jurnali ─────────────────────────────────

  async notifications(limit = 100): Promise<Array<ParentNotification & { studentName: string; className: string; guardianName: string }>> {
    await latency(60, 120);
    const actor = currentActor();
    assertCan(actor, 'attendance.view');
    const tables = getTables();
    const idx = buildIndexes(tables);
    const guardians = new Map(tables.guardians.map((g) => [g.id, g]));
    const allowed = new Set(inScope(actor, tables.students.map((s) => ({ ...s, classId: s.classId }))).map((s) => s.id));
    return tables.parentNotifications
      .filter((n) => allowed.has(n.studentId))
      .sort((a, b) => b.at.localeCompare(a.at))
      .slice(0, limit)
      .map((n) => {
        const s = idx.students.get(n.studentId);
        return { ...n, studentName: s ? studentName(s) : '—', className: s ? (idx.classes.get(s.classId)?.name ?? '') : '', guardianName: guardians.get(n.guardianId)?.fullName ?? '—' };
      });
  },

  // ─── Hisobot va tarix ───────────────────────────────────────────

  /** Oylik hisobot: har o'quvchi uchun kunlar bo'yicha holat + jami. */
  async monthReport(month: string, classId: string): Promise<{
    month: string;
    className: string;
    days: IsoDate[];
    rows: Array<{ studentId: string; name: string; cells: Array<AttendanceStatus | null>; summary: DayCounts; rate: number }>;
  }> {
    await latency(120, 260);
    const actor = currentActor();
    assertCan(actor, 'attendance.history');
    assertClassInScope(actor, classId);
    const tables = getTables();
    const cls = tables.classes.find((c) => c.id === classId);
    if (!cls) throw new ServiceError('NOT_FOUND', classId);
    const today = clockToday();
    const first = `${month}-01`;
    const [y, m] = month.split('-').map(Number);
    const lastDay = new Date(y ?? 2026, m ?? 1, 0).getDate();
    const last = `${month}-${String(lastDay).padStart(2, '0')}`;
    const days = dateRange(first, last < today ? last : today).filter((d) => isClassSchoolDay(tables, cls, d));
    const storedByKey = new Map(tables.attendance.map((r) => [r.id, r]));
    const rows = tables.students
      .filter((s) => !s.archived && s.classId === classId)
      .sort((a, b) => studentName(a).localeCompare(studentName(b), 'uz'))
      .map((s) => {
        let summary = { ...EMPTY };
        const cells = days.map((d) => {
          const rec = resolveRecord(tables, s, d, today, storedByKey.get(`${d}:${s.id}`));
          summary = addCount(summary, rec?.status ?? null);
          return rec?.status ?? null;
        });
        return { studentId: s.id, name: studentName(s), cells, summary, rate: attendedRate(summary) };
      });
    return { month, className: cls.name, days, rows };
  },

  /** Oxirgi N o'quv kuni bo'yicha maktab davomati (bosh sahifa grafigi). */
  async trend(daysBack = 14): Promise<Array<{ date: IsoDate; rate: number; late: number }>> {
    await latency(80, 160);
    const actor = currentActor();
    assertCan(actor, 'attendance.view');
    const tables = getTables();
    const today = clockToday();
    const storedByKey = new Map(tables.attendance.map((r) => [r.id, r]));
    const students = inScope(actor, tables.students.filter((s) => !s.archived));
    const out: Array<{ date: IsoDate; rate: number; late: number }> = [];
    for (let i = daysBack; i >= 0; i--) {
      const d = addDays(today, -i);
      let counts = { ...EMPTY };
      for (const s of students) {
        const rec = resolveRecord(tables, s, d, today, storedByKey.get(`${d}:${s.id}`));
        if (rec || (d === today && tables.classes.some((c) => c.id === s.classId && isClassSchoolDay(tables, c, d)))) {
          counts = addCount(counts, rec?.status ?? null);
        }
      }
      if (counts.total > 0 && counts.total > counts.pending) out.push({ date: d, rate: attendedRate(counts), late: counts.late });
    }
    return out;
  },

  /** O'quvchi tarixi (kalendar uchun). */
  async studentMonth(studentId: string, month: string): Promise<Array<{ date: IsoDate; record: AttendanceRecord | null }>> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'attendance.view');
    const tables = getTables();
    const student = tables.students.find((s) => s.id === studentId);
    if (!student) throw new ServiceError('NOT_FOUND', studentId);
    assertClassInScope(actor, student.classId);
    const cls = tables.classes.find((c) => c.id === student.classId);
    const today = clockToday();
    const [y, m] = month.split('-').map(Number);
    const lastDay = new Date(y ?? 2026, m ?? 1, 0).getDate();
    const storedByKey = new Map(tables.attendance.map((r) => [r.id, r]));
    return dateRange(`${month}-01`, `${month}-${String(lastDay).padStart(2, '0')}`).map((d) => ({
      date: d,
      record: cls && isClassSchoolDay(tables, cls, d) ? resolveRecord(tables, student, d, today, storedByKey.get(`${d}:${student.id}`)) : null,
    }));
  },
};
