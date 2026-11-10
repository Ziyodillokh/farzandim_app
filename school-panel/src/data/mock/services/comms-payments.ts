import type { IsoDate, ListQuery, Paginated, ParentLinkStatus, PaymentReminder, PaymentReminderEntry } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import {
  paymentBulkCreateSchema,
  paymentBulkShiftSchema,
  paymentCreateSchema,
  paymentPauseSchema,
  paymentShiftSchema,
  type PaymentBulkCreateInput,
  type PaymentBulkShiftInput,
  type PaymentCreateInput,
  type PaymentShiftInput,
} from '@/data/schemas/comms';
import { parseOrThrow } from '@/data/schemas/validate';
import { matchesSearch } from '@/lib/normalize-search';
import { addDays, fromIsoDate, toIsoDate } from '../calendar';
import { clockToday } from '../clock';
import { type Actor, allowedClassIds, assertCan, assertClassInScope, currentActor, latency, newId, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { paginate, sortItems } from '../query';
import type { Tables } from '../tables';
import { type ChildRef, childrenByGuardian, nowLocalIso, staffName } from './comms-shared';

/**
 * To'lov ESLATMALARI. Platforma to'lov qabul qilmaydi va qarz hisoblamaydi —
 * faqat maktab tasdiqlagan keyingi eslatma sanasi saqlanadi (TZ 4.5).
 */
export type PaymentFilterKind = 'ALL' | 'DUE_SOON' | 'PREPAID' | 'PAUSED';
export type PaymentFilter = ListQuery & { filter?: PaymentFilterKind; classId?: string };
export type PaymentBulkCreateResult = { created: number; skipped: number; noGuardian: number };
export type PaymentRow = PaymentReminder & {
  guardianName: string;
  phone: string;
  linkStatus: ParentLinkStatus;
  children: ChildRef[];
  dueSoon: boolean;
  openVerifications: number;
  lastEntry: PaymentReminderEntry | null;
};
export type PaymentStats = { families: number; dueSoon: number; prepaid: number; paused: number; nearestDate: IsoDate | null; dueSoonDays: number };
export type PaymentHistoryEntry = PaymentReminderEntry & { byName: string };

/** "Yaqin" eslatmalar oynasi (kun). */
export const DUE_SOON_DAYS = 30;

export function addMonthsIso(iso: IsoDate, months: number): IsoDate {
  const date = fromIsoDate(iso);
  const day = date.getDate();
  date.setDate(1);
  date.setMonth(date.getMonth() + months);
  const lastDay = new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
  date.setDate(Math.min(day, lastDay));
  return toIsoDate(date);
}

/** `nextDate` — sana ("YYYY-MM-DD", vaqtsiz, qat'iy uzunlik), shuning uchun satr solishtirish to'g'ri. */
function isDueSoon(p: PaymentReminder, today: IsoDate): boolean {
  return !p.paused && p.nextDate >= today && p.nextDate <= addDays(today, DUE_SOON_DAYS);
}

export function paymentRows(t: Tables, today: IsoDate): PaymentRow[] {
  const guardians = new Map(t.guardians.map((g) => [g.id, g]));
  const children = childrenByGuardian(t);
  const open = new Map<string, number>();
  for (const v of t.verifications) if (v.status === 'OPEN') open.set(v.paymentReminderId, (open.get(v.paymentReminderId) ?? 0) + 1);
  return t.payments.map((p) => {
    const g = guardians.get(p.guardianId);
    const kids = children.get(p.guardianId) ?? [];
    return {
      ...p,
      guardianName: g?.fullName ?? '—',
      phone: g?.phone ?? '',
      linkStatus: g?.linkStatus ?? 'NOT_INVITED',
      children: kids.filter((c) => p.studentIds.includes(c.id)),
      dueSoon: isDueSoon(p, today),
      openVerifications: open.get(p.id) ?? 0,
      lastEntry: p.history.at(-1) ?? null,
    };
  });
}

/** Ko'rsatkichlar — berilgan eslatmalar (doira / sinf filtri qo'llangan) bo'yicha. */
export function paymentStatsOf(payments: readonly PaymentReminder[], today: IsoDate): PaymentStats {
  const active = payments.filter((p) => !p.paused && p.nextDate >= today);
  const nearestDate = active.reduce<IsoDate | null>((min, p) => (!min || p.nextDate < min ? p.nextDate : min), null);
  return {
    families: payments.length,
    dueSoon: payments.filter((p) => isDueSoon(p, today)).length,
    prepaid: payments.filter((p) => p.prepaidMonths > 0).length,
    paused: payments.filter((p) => p.paused).length,
    nearestDate,
    dueSoonDays: DUE_SOON_DAYS,
  };
}

export function paymentStats(t: Tables, today: IsoDate): PaymentStats {
  return paymentStatsOf(t.payments, today);
}

/**
 * Sinf doirasi (sinf rahbari, backend bilan bir xil): faqat o'z sinf(lar)ida farzandi bor oilalar,
 * farzandlar ro'yxati ham shu sinflar bilan cheklanadi.
 */
function scopeRows(actor: Actor, rows: PaymentRow[]): PaymentRow[] {
  const allowed = allowedClassIds(actor);
  if (!allowed) return rows;
  return rows.flatMap((r) => {
    const children = r.children.filter((c) => allowed.includes(c.classId));
    return children.length > 0 ? [{ ...r, children }] : [];
  });
}

const inClass = (r: PaymentRow, classId: string | undefined) => !classId || r.children.some((c) => c.classId === classId);

/** Oila eslatmasi kimga: ilovaga ulangan vasiy, keyin taklif qilingan, keyin birinchisi. */
const LINK_RANK: Record<string, number> = { LINKED: 0, INVITED: 1 };

function matchesFilter(r: PaymentRow, kind: PaymentFilterKind | undefined): boolean {
  if (kind === 'DUE_SOON') return r.dueSoon;
  if (kind === 'PREPAID') return r.prepaidMonths > 0;
  if (kind === 'PAUSED') return r.paused;
  return true;
}

function entry(actor: Actor, action: PaymentReminderEntry['action'], note: string): PaymentReminderEntry {
  return { at: nowLocalIso(), byStaffId: actor.staffId, action, note };
}

function findPayment(t: Tables, id: string): PaymentReminder {
  const payment = t.payments.find((p) => p.id === id);
  if (!payment) throw new ServiceError('NOT_FOUND', id);
  return payment;
}

function guardianLabel(t: Tables, p: PaymentReminder): string {
  return t.guardians.find((g) => g.id === p.guardianId)?.fullName ?? p.guardianId;
}

/** Bitta oila uchun keyingi sanani o'zgartirish (transact ichida). */
export function applyShift(t: Tables, actor: Actor, id: string, nextDate: IsoDate, note: string, action: PaymentReminderEntry['action']): PaymentReminder {
  const payment = findPayment(t, id);
  const before = { nextDate: payment.nextDate, prepaidMonths: payment.prepaidMonths };
  payment.nextDate = nextDate;
  payment.history = [...payment.history, entry(actor, action, note)];
  writeAudit(t, actor, 'PAYMENTS', 'payment.shift', `${guardianLabel(t, payment)}: eslatma sanasi ${before.nextDate} → ${nextDate}`, id, before, { nextDate }, {
    name: guardianLabel(t, payment),
    fromDate: before.nextDate,
    toDate: nextDate,
  });
  return payment;
}

const SORTERS: Record<string, (r: PaymentRow) => string | number> = {
  name: (r) => r.guardianName,
  nextDate: (r) => r.nextDate,
  prepaid: (r) => r.prepaidMonths,
};

/** Doira → filtr (holat, sinf) → qidiruv → saralash (sahifalashsiz). Ruxsat chaqiruvchida tekshiriladi. */
function queryRows(actor: Actor, filter: PaymentFilter): PaymentRow[] {
  if (filter.classId) assertClassInScope(actor, filter.classId);
  const rows = scopeRows(actor, paymentRows(getTables(), clockToday())).filter((r) => matchesFilter(r, filter.filter) && inClass(r, filter.classId));
  const search = filter.search ?? '';
  const searched = search
    ? rows.filter((r) => matchesSearch(`${r.guardianName} ${r.phone} ${r.children.map((c) => `${c.name} ${c.className}`).join(' ')}`, search))
    : rows;
  const sorter = (filter.sortBy && SORTERS[filter.sortBy]) || SORTERS.nextDate!;
  return sortItems(searched, sorter, filter.sortDir ?? 'asc');
}

async function setPaused(id: string, paused: boolean, input: { note: string }): Promise<PaymentReminder> {
  await latency();
  const actor = currentActor();
  assertCan(actor, 'payments.manage');
  const { note } = parseOrThrow(paymentPauseSchema, input);
  return transact((t) => {
    const payment = findPayment(t, id);
    if (payment.paused === paused) throw new ServiceError('CONFLICT', id);
    payment.paused = paused;
    payment.history = [...payment.history, entry(actor, paused ? 'PAUSED' : 'RESUMED', note)];
    writeAudit(t, actor, 'PAYMENTS', paused ? 'payment.pause' : 'payment.resume', `${guardianLabel(t, payment)}: eslatma ${paused ? 'to\'xtatildi' : 'qayta yoqildi'} — ${note}`, id, { paused: !paused }, { paused }, {
      name: guardianLabel(t, payment),
      note,
    });
    return payment;
  });
}

/** Vasiyga bog'langan faol (arxivlanmagan) o'quvchilar. */
function activeStudentIdsOf(t: Tables, guardianId: string): string[] {
  return t.students.filter((s) => !s.archived && s.guardianIds.includes(guardianId)).map((s) => s.id);
}

function pickGuardian(t: Tables, student: Tables['students'][number]) {
  return t.guardians
    .filter((g) => student.guardianIds.includes(g.id))
    .sort((a, b) => (LINK_RANK[a.linkStatus] ?? 2) - (LINK_RANK[b.linkStatus] ?? 2) || a.id.localeCompare(b.id))[0];
}

function newPayment(actor: Actor, guardianId: string, studentIds: string[], nextDate: IsoDate, note: string): PaymentReminder {
  return { id: newId('pay'), guardianId, studentIds, nextDate, prepaidMonths: 0, paused: false, history: [entry(actor, 'CREATED', note)] };
}

export const paymentsService = {
  async list(filter: PaymentFilter = {}): Promise<Paginated<PaymentRow>> {
    await latency(80, 180);
    const actor = currentActor();
    assertCan(actor, 'payments.view');
    return paginate(queryRows(actor, filter), filter.page, filter.limit);
  },

  /** Ro'yxat bilan bir xil doira va sinf filtri bo'yicha. */
  async stats(filter: { classId?: string } = {}): Promise<PaymentStats> {
    await latency(60, 120);
    const actor = currentActor();
    assertCan(actor, 'payments.view');
    if (filter.classId) assertClassInScope(actor, filter.classId);
    const rows = scopeRows(actor, paymentRows(getTables(), clockToday())).filter((r) => inClass(r, filter.classId));
    return paymentStatsOf(rows, clockToday());
  },

  /** CSV uchun — filtr bo'yicha BARCHA qatorlar (sahifalashsiz; `paginate` 500 bilan cheklaydi). */
  async exportRows(filter: PaymentFilter = {}): Promise<PaymentRow[]> {
    await latency(80, 180);
    const actor = currentActor();
    assertCan(actor, 'payments.view');
    return queryRows(actor, filter);
  },

  /** Bitta oila uchun eslatma: vasiyga bittadan (409); farzandlar — vasiyning faol o'quvchilari. */
  async create(input: PaymentCreateInput): Promise<PaymentReminder> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'payments.manage');
    const data = parseOrThrow(paymentCreateSchema, input);
    return transact((t) => {
      const guardian = t.guardians.find((g) => g.id === data.guardianId);
      if (!guardian) throw new ServiceError('VALIDATION', 'guardianId: errors.form.required');
      const linked = activeStudentIdsOf(t, guardian.id);
      const studentIds = data.studentIds ? [...new Set(data.studentIds)] : linked;
      if (studentIds.length === 0 || studentIds.some((id) => !linked.includes(id))) throw new ServiceError('VALIDATION', 'studentIds: errors.form.selectAtLeastOne');
      if (t.payments.some((p) => p.guardianId === guardian.id)) throw new ServiceError('CONFLICT', guardian.id);
      const payment = newPayment(actor, guardian.id, studentIds, data.nextDate, data.note);
      t.payments.push(payment);
      writeAudit(t, actor, 'PAYMENTS', 'payment.create', `${guardian.fullName}: to'lov eslatmasi yaratildi (keyingi sana ${data.nextDate})`, payment.id, null, payment, {
        name: guardian.fullName,
        date: data.nextDate,
      });
      return payment;
    });
  },

  /** Sinf bo'yicha: eslatmasi yo'q har faol o'quvchi uchun bitta vasiy (backend bilan bir xil qoida). */
  async bulkCreate(input: PaymentBulkCreateInput): Promise<PaymentBulkCreateResult> {
    await latency(200, 400);
    const actor = currentActor();
    assertCan(actor, 'payments.manage');
    const data = parseOrThrow(paymentBulkCreateSchema, input);
    return transact((t) => {
      const cls = t.classes.find((c) => c.id === data.classId);
      if (!cls) throw new ServiceError('VALIDATION', 'classId: errors.form.required');
      const covered = new Set(t.payments.flatMap((p) => p.studentIds));
      const taken = new Set(t.payments.map((p) => p.guardianId));
      const plan = new Map<string, string[]>();
      let skipped = 0;
      let noGuardian = 0;
      const students = t.students.filter((s) => s.classId === cls.id && !s.archived).sort((a, b) => a.lastName.localeCompare(b.lastName));
      for (const student of students) {
        if (covered.has(student.id)) {
          skipped += 1;
          continue;
        }
        const guardian = pickGuardian(t, student);
        if (!guardian) noGuardian += 1;
        else if (taken.has(guardian.id)) skipped += 1;
        else plan.set(guardian.id, [...(plan.get(guardian.id) ?? []), student.id]);
      }
      for (const [guardianId, studentIds] of plan) t.payments.push(newPayment(actor, guardianId, studentIds, data.nextDate, data.note));
      if (plan.size > 0) {
        writeAudit(t, actor, 'PAYMENTS', 'payment.bulkCreate', `${cls.name}: ${plan.size} oila uchun to'lov eslatmasi yaratildi (keyingi sana ${data.nextDate})`, cls.id, null, { created: plan.size }, {
          className: cls.name,
          count: plan.size,
          date: data.nextDate,
        });
      }
      return { created: plan.size, skipped, noGuardian };
    });
  },

  async shift(id: string, input: PaymentShiftInput): Promise<PaymentReminder> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'payments.manage');
    const data = parseOrThrow(paymentShiftSchema, input);
    return transact((t) => applyShift(t, actor, id, data.nextDate, data.note, 'SHIFTED'));
  },

  pause: (id: string, input: { note: string }) => setPaused(id, true, input),
  resume: (id: string, input: { note: string }) => setPaused(id, false, input),

  /** Ommaviy yangilash: N oyga surish (ixtiyoriy "oldindan to'langan") yoki aniq sana. */
  async bulkShift(input: PaymentBulkShiftInput): Promise<{ updated: number }> {
    await latency(200, 400);
    const actor = currentActor();
    assertCan(actor, 'payments.manage');
    const data = parseOrThrow(paymentBulkShiftSchema, input);
    return transact((t) => {
      const ids = [...new Set(data.ids)];
      const targets = ids.map((id) => findPayment(t, id));
      const before = targets.map((p) => ({ id: p.id, nextDate: p.nextDate, prepaidMonths: p.prepaidMonths }));
      for (const p of targets) {
        p.nextDate = data.months ? addMonthsIso(p.nextDate, data.months) : (data.date ?? p.nextDate);
        if (data.months && data.markPrepaid) p.prepaidMonths += data.months;
        p.history = [...p.history, entry(actor, 'BULK_SHIFT', data.note)];
      }
      const how = data.months ? `${data.months} oyga surildi` : `${data.date} ga o'zgartirildi`;
      const after = targets.map((p) => ({ id: p.id, nextDate: p.nextDate, prepaidMonths: p.prepaidMonths }));
      const params: Record<string, string | number> = data.months
        ? { variant: 'months', count: targets.length, months: data.months, note: data.note }
        : { variant: 'date', count: targets.length, date: data.date ?? '', note: data.note };
      writeAudit(t, actor, 'PAYMENTS', 'payment.bulkShift', `${targets.length} oila uchun eslatma sanasi ${how} — ${data.note}`, null, before, after, params);
      return { updated: targets.length };
    });
  },

  async history(id: string): Promise<PaymentHistoryEntry[]> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'payments.view');
    const t = getTables();
    const payment = findPayment(t, id);
    const allowed = allowedClassIds(actor);
    if (allowed && !t.students.some((s) => payment.studentIds.includes(s.id) && allowed.includes(s.classId))) throw new ServiceError('FORBIDDEN', id);
    return [...payment.history].reverse().map((e) => ({ ...e, byName: staffName(t, e.byStaffId) }));
  },
};
