import type { ListQuery, Paginated, PaymentReminder, VerificationRequest, VerificationStatus } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { verificationAnswerSchema, type VerificationAnswerInput } from '@/data/schemas/comms';
import { parseOrThrow } from '@/data/schemas/validate';
import { matchesSearch } from '@/lib/normalize-search';
import { assertCan, currentActor, latency, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { paginate } from '../query';
import type { Tables } from '../tables';
import { applyShift } from './comms-payments';
import { type ChildRef, childrenByGuardian, nowLocalIso, staffName } from './comms-shared';

/** Ota-ona "eslatmada xato bor" desa — maktab tekshirib javob beradi (TZ 4.5). */
export type VerificationRow = VerificationRequest & {
  guardianName: string;
  phone: string;
  children: ChildRef[];
  payment: Pick<PaymentReminder, 'id' | 'nextDate' | 'prepaidMonths' | 'paused'> | null;
  answeredByName: string | null;
};
export type VerificationCounts = Record<'ALL' | VerificationStatus, number>;
export type VerificationFilter = ListQuery & { status?: VerificationStatus };
export type VerificationList = Paginated<VerificationRow> & { counts: VerificationCounts };

const STATUS_ORDER: Record<VerificationStatus, number> = { OPEN: 0, ANSWERED: 1, CLOSED: 2 };

export function verificationCounts(t: Tables): VerificationCounts {
  const counts: VerificationCounts = { ALL: t.verifications.length, OPEN: 0, ANSWERED: 0, CLOSED: 0 };
  for (const v of t.verifications) counts[v.status] += 1;
  return counts;
}

function toRows(t: Tables): VerificationRow[] {
  const guardians = new Map(t.guardians.map((g) => [g.id, g]));
  const payments = new Map(t.payments.map((p) => [p.id, p]));
  const children = childrenByGuardian(t);
  return t.verifications.map((v) => {
    const p = payments.get(v.paymentReminderId);
    return {
      ...v,
      guardianName: guardians.get(v.guardianId)?.fullName ?? '—',
      phone: guardians.get(v.guardianId)?.phone ?? '',
      children: children.get(v.guardianId) ?? [],
      payment: p ? { id: p.id, nextDate: p.nextDate, prepaidMonths: p.prepaidMonths, paused: p.paused } : null,
      answeredByName: v.answeredByStaffId ? staffName(t, v.answeredByStaffId) : null,
    };
  });
}

function findIndex(t: Tables, id: string): { index: number; current: VerificationRequest } {
  const index = t.verifications.findIndex((v) => v.id === id);
  const current = t.verifications[index];
  if (!current) throw new ServiceError('NOT_FOUND', id);
  return { index, current };
}

function guardianName(t: Tables, v: VerificationRequest): string {
  return t.guardians.find((g) => g.id === v.guardianId)?.fullName ?? v.guardianId;
}

export const verificationsService = {
  async list(filter: VerificationFilter = {}): Promise<VerificationList> {
    await latency(80, 180);
    const actor = currentActor();
    assertCan(actor, 'payments.manage');
    const t = getTables();
    const rows = toRows(t)
      .filter((r) => !filter.status || r.status === filter.status)
      .filter((r) => !filter.search || matchesSearch(`${r.guardianName} ${r.phone} ${r.message} ${r.children.map((c) => c.name).join(' ')}`, filter.search))
      .sort((a, b) => STATUS_ORDER[a.status] - STATUS_ORDER[b.status] || new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    return { ...paginate(rows, filter.page, filter.limit ?? 20), counts: verificationCounts(t) };
  },

  /** Javob (ota-onaga Parvoz/SMS orqali). `newDate` — eslatma sanasini ham to'g'rilash. */
  async answer(id: string, input: VerificationAnswerInput): Promise<VerificationRequest> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'payments.manage');
    const data = parseOrThrow(verificationAnswerSchema, input);
    return transact((t) => {
      const { index, current } = findIndex(t, id);
      if (current.status === 'CLOSED') throw new ServiceError('CONFLICT', 'closed');
      if (data.newDate) applyShift(t, actor, current.paymentReminderId, data.newDate, `Tekshiruv so'rovi bo'yicha: ${data.text}`, 'VERIFIED');
      const next: VerificationRequest = { ...current, status: 'ANSWERED', answer: data.text, answeredByStaffId: actor.staffId, answeredAt: nowLocalIso() };
      t.verifications[index] = next;
      writeAudit(t, actor, 'PAYMENTS', 'verification.answer', `${guardianName(t, next)}ning tekshiruv so'roviga javob berildi${data.newDate ? ` (yangi sana: ${data.newDate})` : ''}`, id, current, next);
      return next;
    });
  },

  async close(id: string): Promise<VerificationRequest> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'payments.manage');
    return transact((t) => {
      const { index, current } = findIndex(t, id);
      if (current.status === 'CLOSED') throw new ServiceError('CONFLICT', 'closed');
      const next: VerificationRequest = { ...current, status: 'CLOSED' };
      t.verifications[index] = next;
      writeAudit(t, actor, 'PAYMENTS', 'verification.close', `${guardianName(t, next)}ning tekshiruv so'rovi yopildi`, id, { status: current.status }, { status: 'CLOSED' });
      return next;
    });
  },
};
