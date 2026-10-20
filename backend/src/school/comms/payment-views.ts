// To'lov ESLATMALARI ko'rinishlari (panel `PaymentReminder` / `PaymentRow`).
// Platforma to'lov qabul qilmaydi va qarz hisoblamaydi — faqat maktab
// tasdiqlagan keyingi eslatma sanasi (TZ 4.5). Javobda qarz maydoni YO'Q.

import { GuardianLinkStatus, Prisma, SchoolPaymentReminder } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { addDays, DayKey } from '../../common/time/tashkent';
import { SchoolActor } from '../auth/school-actor';
import { matchesSearch, sortItems } from '../common/list-query';
import { PaymentFilterKind } from './comms.schemas';
import { ChildRef, childrenByGuardian, loadRoster } from './comms-roster';

type Db = Prisma.TransactionClient | PrismaService;

export type PaymentAction = 'CREATED' | 'SHIFTED' | 'PAUSED' | 'RESUMED' | 'BULK_SHIFT' | 'VERIFIED';
const ACTIONS: readonly PaymentAction[] = ['CREATED', 'SHIFTED', 'PAUSED', 'RESUMED', 'BULK_SHIFT', 'VERIFIED'];

export interface PaymentEntry {
  /** Lahza (ISO). */
  at: string;
  byStaffId: string;
  action: PaymentAction;
  note: string;
}

export interface PaymentView {
  id: string;
  guardianId: string;
  studentIds: string[];
  nextDate: DayKey;
  prepaidMonths: number;
  paused: boolean;
  history: PaymentEntry[];
}

export interface PaymentRow extends PaymentView {
  guardianName: string;
  phone: string;
  linkStatus: GuardianLinkStatus;
  children: ChildRef[];
  dueSoon: boolean;
  openVerifications: number;
  lastEntry: PaymentEntry | null;
}

/** "Yaqin" eslatmalar oynasi (kun). */
export const DUE_SOON_DAYS = 30;

export function parseHistory(value: Prisma.JsonValue): PaymentEntry[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((raw) => {
    const e = (raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {}) as Record<string, unknown>;
    const action = ACTIONS.find((a) => a === e.action);
    if (!action || typeof e.at !== 'string') return [];
    return [{ at: e.at, byStaffId: String(e.byStaffId ?? ''), action, note: String(e.note ?? '') }];
  });
}

export function toPaymentView(p: SchoolPaymentReminder): PaymentView {
  return {
    id: p.id,
    guardianId: p.guardianId,
    studentIds: [...p.studentIds],
    nextDate: p.nextDate,
    prepaidMonths: p.prepaidMonths,
    paused: p.paused,
    history: parseHistory(p.history),
  };
}

export function historyEntry(actor: SchoolActor, action: PaymentAction, note: string, at = new Date()): PaymentEntry {
  return { at: at.toISOString(), byStaffId: actor.staffId, action, note };
}

/** `nextDate` — qat'iy "YYYY-MM-DD", shuning uchun satr solishtirish to'g'ri. */
export function isDueSoon(p: { paused: boolean; nextDate: DayKey }, today: DayKey): boolean {
  return !p.paused && p.nextDate >= today && p.nextDate <= addDays(today, DUE_SOON_DAYS);
}

export function paymentStats(payments: readonly { paused: boolean; nextDate: DayKey; prepaidMonths: number }[], today: DayKey) {
  const nearestDate = payments
    .filter((p) => !p.paused && p.nextDate >= today)
    .reduce<DayKey | null>((min, p) => (!min || p.nextDate < min ? p.nextDate : min), null);
  return {
    families: payments.length,
    dueSoon: payments.filter((p) => isDueSoon(p, today)).length,
    prepaid: payments.filter((p) => p.prepaidMonths > 0).length,
    paused: payments.filter((p) => p.paused).length,
    nearestDate,
    dueSoonDays: DUE_SOON_DAYS,
  };
}

/** Maktabning barcha to'lov eslatmalari — vasiy, farzandlar, ochiq so'rovlar bilan. */
export async function loadPaymentRows(db: Db, schoolId: string, today: DayKey): Promise<PaymentRow[]> {
  const roster = await loadRoster(db, schoolId);
  const payments = await db.schoolPaymentReminder.findMany({
    where: { schoolId },
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
  });
  const open = await db.schoolVerificationRequest.groupBy({
    by: ['paymentReminderId'],
    where: { schoolId, status: 'OPEN' },
    _count: { _all: true },
  });
  const openBy = new Map(open.map((o) => [o.paymentReminderId, o._count._all]));
  const children = childrenByGuardian(roster);
  return payments.map((p) => {
    const view = toPaymentView(p);
    const g = roster.guardians.get(p.guardianId);
    return {
      ...view,
      guardianName: g?.fullName ?? '—',
      phone: g?.phone ?? '',
      linkStatus: g?.linkStatus ?? 'NOT_INVITED',
      children: (children.get(p.guardianId) ?? []).filter((c) => view.studentIds.includes(c.id)),
      dueSoon: isDueSoon(view, today),
      openVerifications: openBy.get(p.id) ?? 0,
      lastEntry: view.history.at(-1) ?? null,
    };
  });
}

const SORTERS: Record<string, (r: PaymentRow) => string | number> = {
  name: (r) => r.guardianName,
  nextDate: (r) => r.nextDate,
  prepaid: (r) => r.prepaidMonths,
};

function matchesFilter(r: PaymentRow, kind: PaymentFilterKind | undefined): boolean {
  if (kind === 'DUE_SOON') return r.dueSoon;
  if (kind === 'PREPAID') return r.prepaidMonths > 0;
  if (kind === 'PAUSED') return r.paused;
  return true;
}

/** Filtr → qidiruv → saralash (sahifalashsiz). */
export function queryPaymentRows(
  rows: readonly PaymentRow[],
  filter: { filter?: PaymentFilterKind; search?: string; sortBy?: string; sortDir?: 'asc' | 'desc' },
): PaymentRow[] {
  const search = filter.search ?? '';
  const searched = rows
    .filter((r) => matchesFilter(r, filter.filter))
    .filter(
      (r) =>
        !search ||
        matchesSearch(`${r.guardianName} ${r.phone} ${r.children.map((c) => `${c.name} ${c.className}`).join(' ')}`, search),
    );
  const sorter = (filter.sortBy && SORTERS[filter.sortBy]) || SORTERS.nextDate!;
  return sortItems(searched, sorter, filter.sortDir ?? 'asc');
}
