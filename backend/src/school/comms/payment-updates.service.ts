// To'lov eslatmasini o'zgartirish (panel `payments.shift / pause / resume /
// bulkShift`): har o'zgarish — tarixga yozuv + audit. Qator `FOR UPDATE` bilan
// qulflanadi: parallel o'zgarishlarda tarix yozuvi yo'qolmaydi.

import { Injectable } from '@nestjs/common';
import { Prisma, SchoolPaymentReminder } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { paymentBulkShiftSchema, paymentPauseSchema, paymentShiftSchema } from './comms.schemas';
import { addMonthsDay } from './comms-time';
import { historyEntry, parseHistory, PaymentAction, PaymentEntry, PaymentView, toPaymentView } from './payment-views';

type Tx = Prisma.TransactionClient;

/** Ommaviy yangilash tranzaksiyasi (yuzlab oila — bir nechta soniya). */
const BULK_TX_TIMEOUT_MS = 60_000;

const historyJson = (entries: readonly PaymentEntry[]) => entries as unknown as Prisma.InputJsonValue;

export async function lockPayment(tx: Tx, schoolId: string, id: string): Promise<SchoolPaymentReminder> {
  const rows = await tx.$queryRaw<{ id: string }[]>`
    SELECT id FROM school_payment_reminders WHERE id = ${id} AND school_id = ${schoolId} FOR UPDATE`;
  if (rows.length === 0) throw notFound(id);
  return tx.schoolPaymentReminder.findUniqueOrThrow({ where: { id } });
}

/** Bir nechtasini bir xil tartibda qulflash (deadlock bo'lmasin); birinchi yo'q id — 404. */
async function lockPayments(tx: Tx, schoolId: string, ids: readonly string[]): Promise<SchoolPaymentReminder[]> {
  const rows = await tx.$queryRaw<{ id: string }[]>`
    SELECT id FROM school_payment_reminders
    WHERE school_id = ${schoolId} AND id = ANY(${[...ids]}) ORDER BY id FOR UPDATE`;
  const found = new Set(rows.map((r) => r.id));
  const missing = ids.find((id) => !found.has(id));
  if (missing) throw notFound(missing);
  const payments = await tx.schoolPaymentReminder.findMany({ where: { id: { in: [...ids] } } });
  const byId = new Map(payments.map((p) => [p.id, p]));
  return ids.map((id) => byId.get(id)!);
}

export async function guardianLabel(tx: Tx, p: Pick<SchoolPaymentReminder, 'schoolId' | 'guardianId'>): Promise<string> {
  const g = await tx.schoolGuardian.findFirst({ where: { id: p.guardianId, schoolId: p.schoolId }, select: { fullName: true } });
  return g?.fullName ?? p.guardianId;
}

@Injectable()
export class PaymentUpdatesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  async shift(actor: SchoolActor, id: string, input: unknown): Promise<PaymentView> {
    assertCan(actor, 'payments.manage');
    const data = parseOrThrow(paymentShiftSchema, input);
    return this.prisma.$transaction(async (tx) => {
      const payment = await lockPayment(tx, actor.schoolId, id);
      return toPaymentView(await this.applyShift(tx, actor, payment, data.nextDate, data.note, 'SHIFTED'));
    });
  }

  pause(actor: SchoolActor, id: string, input: unknown): Promise<PaymentView> {
    return this.setPaused(actor, id, true, input);
  }

  resume(actor: SchoolActor, id: string, input: unknown): Promise<PaymentView> {
    return this.setPaused(actor, id, false, input);
  }

  /** Bitta oila uchun keyingi sanani o'zgartirish (qulflangan qator, tranzaksiya ichida). */
  async applyShift(
    tx: Tx,
    actor: SchoolActor,
    payment: SchoolPaymentReminder,
    nextDate: string,
    note: string,
    action: PaymentAction,
  ): Promise<SchoolPaymentReminder> {
    const name = await guardianLabel(tx, payment);
    const next = await tx.schoolPaymentReminder.update({
      where: { id: payment.id },
      data: { nextDate, history: historyJson([...parseHistory(payment.history), historyEntry(actor, action, note)]) },
    });
    await this.audit.write(
      actor,
      {
        module: 'PAYMENTS',
        action: 'payment.shift',
        summary: `${name}: eslatma sanasi ${payment.nextDate} → ${nextDate}`,
        entityId: payment.id,
        before: { nextDate: payment.nextDate, prepaidMonths: payment.prepaidMonths },
        after: { nextDate },
        params: { name, fromDate: payment.nextDate, toDate: nextDate },
      },
      tx,
    );
    return next;
  }

  /** Ommaviy: N oyga surish (ixtiyoriy "oldindan to'langan") yoki aniq sana. */
  async bulkShift(actor: SchoolActor, input: unknown): Promise<{ updated: number }> {
    assertCan(actor, 'payments.manage');
    const data = parseOrThrow(paymentBulkShiftSchema, input);
    const ids = [...new Set(data.ids)];
    return this.prisma.$transaction(
      async (tx) => {
        const targets = await lockPayments(tx, actor.schoolId, ids);
        const entry = historyEntry(actor, 'BULK_SHIFT', data.note);
        const before = targets.map((p) => ({ id: p.id, nextDate: p.nextDate, prepaidMonths: p.prepaidMonths }));
        const after = targets.map((p) => ({
          id: p.id,
          nextDate: data.months ? addMonthsDay(p.nextDate, data.months) : (data.date ?? p.nextDate),
          prepaidMonths: data.months && data.markPrepaid ? p.prepaidMonths + data.months : p.prepaidMonths,
          history: historyJson([...parseHistory(p.history), entry]),
        }));
        for (const { id, ...fields } of after) {
          await tx.schoolPaymentReminder.update({ where: { id }, data: fields });
        }
        const how = data.months ? `${data.months} oyga surildi` : `${data.date} ga o'zgartirildi`;
        const params: Record<string, string | number> = data.months
          ? { variant: 'months', count: targets.length, months: data.months, note: data.note }
          : { variant: 'date', count: targets.length, date: data.date ?? '', note: data.note };
        await this.audit.write(
          actor,
          {
            module: 'PAYMENTS',
            action: 'payment.bulkShift',
            summary: `${targets.length} oila uchun eslatma sanasi ${how} — ${data.note}`,
            entityId: null,
            before,
            after: after.map(({ id, nextDate, prepaidMonths }) => ({ id, nextDate, prepaidMonths })),
            params,
          },
          tx,
        );
        return { updated: targets.length };
      },
      { timeout: BULK_TX_TIMEOUT_MS },
    );
  }

  private async setPaused(actor: SchoolActor, id: string, paused: boolean, input: unknown): Promise<PaymentView> {
    assertCan(actor, 'payments.manage');
    const { note } = parseOrThrow(paymentPauseSchema, input);
    return this.prisma.$transaction(async (tx) => {
      const payment = await lockPayment(tx, actor.schoolId, id);
      if (payment.paused === paused) throw conflict(id);
      const name = await guardianLabel(tx, payment);
      const next = await tx.schoolPaymentReminder.update({
        where: { id },
        data: {
          paused,
          history: historyJson([...parseHistory(payment.history), historyEntry(actor, paused ? 'PAUSED' : 'RESUMED', note)]),
        },
      });
      await this.audit.write(
        actor,
        {
          module: 'PAYMENTS',
          action: paused ? 'payment.pause' : 'payment.resume',
          summary: `${name}: eslatma ${paused ? "to'xtatildi" : 'qayta yoqildi'} — ${note}`,
          entityId: id,
          before: { paused: !paused },
          after: { paused },
          params: { name, note },
        },
        tx,
      );
      return toPaymentView(next);
    });
  }
}
