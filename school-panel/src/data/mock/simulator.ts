import type { AttendanceEvent, AttendanceRecord, IsoDate, ParentNotification } from '@/data/contracts';
import { hhmmToMinutes, minutesToHhmm } from '@/lib/utils';
import { planDay, recordFromPlan } from './attendance-plan';
import type { Tables } from './tables';

const MAX_NOTIFICATIONS = 2500;

/**
 * Simulyator: `processedUntilMinute` dan `minute` gacha bo'lgan rejadagi
 * kirish/chiqishlarni "o'ynaydi". Qo'lda (kiosk/xodim) belgilangan yozuvlar
 * ustidan yozilmaydi. Yangi hodisalarni qaytaradi (UI toast'lari uchun).
 */
export function simulate(tables: Tables, date: IsoDate, minute: number, epoch = 0): AttendanceEvent[] {
  const simKey = `${date}#${epoch}`;
  if (tables.sim.date !== simKey) resetDay(tables, date, simKey);
  const from = tables.sim.processedUntilMinute;
  if (minute <= from) return [];

  const classes = new Map(tables.classes.map((c) => [c.id, c]));
  const shifts = new Map(tables.shifts.map((s) => [s.id, s]));
  const guardians = new Map(tables.guardians.map((g) => [g.id, g]));
  const records = new Map(tables.attendance.filter((r) => r.date === date).map((r) => [r.studentId, r]));
  const events: AttendanceEvent[] = [];
  const lateAfter = tables.school.lateAfterMinutes;

  const notify = (studentId: string, guardianIds: string[], kind: ParentNotification['kind'], at: string) => {
    const linked = guardianIds.map((id) => guardians.get(id)).find((g) => g?.linkStatus === 'LINKED');
    if (!linked) return false;
    tables.parentNotifications.push({ id: `ntf-${date}-${studentId}-${kind}`, at, studentId, guardianId: linked.id, kind, delivered: true });
    return true;
  };

  for (const student of tables.students) {
    if (student.archived) continue;
    const cls = classes.get(student.classId);
    const shift = cls ? shifts.get(cls.shiftId) : undefined;
    if (!cls || !shift) continue;
    const plan = planDay(student, cls, shift, date, tables.holidays, lateAfter);
    if (!plan) continue;
    const existing = records.get(student.id);
    const atIso = (m: number) => `${date}T${minutesToHhmm(m)}:00`;

    if (plan.inMinute !== null && !existing && plan.inMinute > from && plan.inMinute <= minute) {
      const rec: AttendanceRecord = {
        ...recordFromPlan(student, date, plan, false),
        status: plan.status === 'LEFT_EARLY' ? 'PRESENT' : plan.status,
        outAt: null,
      };
      rec.parentNotified = notify(student.id, student.guardianIds, 'ARRIVED', atIso(plan.inMinute));
      tables.attendance.push(rec);
      records.set(student.id, rec);
      events.push({
        id: `${date}:${student.id}:IN`,
        at: atIso(plan.inMinute),
        studentId: student.id,
        classId: student.classId,
        kind: 'IN',
        source: plan.source,
        late: plan.status === 'LATE',
      });
      continue;
    }

    if (plan.inMinute === null && !existing) {
      const markAt = hhmmToMinutes(shift.start) + lateAfter + 30;
      if (markAt > from && markAt <= minute) {
        const rec = recordFromPlan(student, date, plan, false);
        rec.parentNotified = plan.status === 'ABSENT' ? notify(student.id, student.guardianIds, 'ABSENT', atIso(markAt)) : false;
        tables.attendance.push(rec);
        records.set(student.id, rec);
      }
      continue;
    }

    const current = records.get(student.id);
    if (
      current &&
      plan.outMinute !== null &&
      current.inAt &&
      !current.outAt &&
      current.status !== 'ABSENT' &&
      plan.outMinute > from &&
      plan.outMinute <= minute
    ) {
      current.outAt = minutesToHhmm(plan.outMinute);
      const early = plan.status === 'LEFT_EARLY';
      if (early && current.corrections.length === 0) current.status = 'LEFT_EARLY';
      notify(student.id, student.guardianIds, early ? 'EARLY_EXIT' : 'LEFT', atIso(plan.outMinute));
      events.push({
        id: `${date}:${student.id}:OUT`,
        at: atIso(plan.outMinute),
        studentId: student.id,
        classId: student.classId,
        kind: 'OUT',
        source: current.source,
        late: false,
      });
    }
  }

  tables.attendanceEvents.push(...events);
  if (tables.parentNotifications.length > MAX_NOTIFICATIONS) {
    tables.parentNotifications.splice(0, tables.parentNotifications.length - MAX_NOTIFICATIONS);
  }
  tables.sim.processedUntilMinute = minute;
  return events;
}

/** Yangi kun / ssenariy qayta boshlandi: tuzatilmagan kundalik yozuvlar tozalanadi. */
function resetDay(tables: Tables, date: IsoDate, simKey: string): void {
  tables.attendance = tables.attendance.filter((r) => r.corrections.length > 0 && r.date !== date);
  // Jonli oqim faqat joriy kunniki.
  tables.attendanceEvents = [];
  tables.parentNotifications = tables.parentNotifications.filter((n) => !n.at.startsWith(date));
  tables.sim = { date: simKey, processedUntilMinute: -1 };
}
