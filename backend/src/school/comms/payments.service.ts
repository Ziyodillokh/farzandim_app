// To'lov eslatmalari (panel `commsService.payments`): ro'yxat, ko'rsatkichlar,
// CSV eksport (sahifalashsiz), tarix; yangi oila eslatmasi (`create` — panelda
// hozircha UI yo'q). O'zgartirishlar — `PaymentUpdatesService`.
// Ruxsat: payments.manage.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, invalid, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { paymentCreateSchema, paymentFilterSchema } from './comms.schemas';
import { pageOf } from './comms-paging';
import {
  historyEntry,
  loadPaymentRows,
  parseHistory,
  PaymentView,
  paymentStats,
  queryPaymentRows,
  toPaymentView,
} from './payment-views';

@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  async list(actor: SchoolActor, raw: Record<string, unknown>) {
    assertCan(actor, 'payments.manage');
    const filter = parseOrThrow(paymentFilterSchema, raw);
    const rows = await loadPaymentRows(this.prisma, actor.schoolId, tashkentDay());
    return pageOf(queryPaymentRows(rows, filter), filter.page, filter.limit);
  }

  async stats(actor: SchoolActor) {
    assertCan(actor, 'payments.manage');
    const payments = await this.prisma.schoolPaymentReminder.findMany({
      where: { schoolId: actor.schoolId },
      select: { paused: true, nextDate: true, prepaidMonths: true },
    });
    return paymentStats(payments, tashkentDay());
  }

  /** CSV uchun — filtr bo'yicha BARCHA qatorlar (sahifalashsiz). */
  async exportRows(actor: SchoolActor, raw: Record<string, unknown>) {
    assertCan(actor, 'payments.manage');
    const filter = parseOrThrow(paymentFilterSchema, raw);
    const rows = await loadPaymentRows(this.prisma, actor.schoolId, tashkentDay());
    return queryPaymentRows(rows, filter);
  }

  /** Tarix: yangi → eski, xodim ismi bilan. */
  async history(actor: SchoolActor, id: string) {
    assertCan(actor, 'payments.manage');
    const payment = await this.prisma.schoolPaymentReminder.findFirst({ where: { id, schoolId: actor.schoolId } });
    if (!payment) throw notFound(id);
    const staff = await this.prisma.schoolStaff.findMany({
      where: { schoolId: actor.schoolId },
      select: { id: true, fullName: true },
    });
    const names = new Map(staff.map((s) => [s.id, s.fullName]));
    return [...parseHistory(payment.history)].reverse().map((e) => ({ ...e, byName: names.get(e.byStaffId) ?? '—' }));
  }

  /**
   * Oila uchun to'lov eslatmasi: vasiy shu maktabniki; farzandlar — vasiyga
   * bog'langan faol o'quvchilar (berilmasa — hammasi). Vasiyga bittadan (409).
   */
  async create(actor: SchoolActor, input: unknown): Promise<PaymentView> {
    assertCan(actor, 'payments.manage');
    const data = parseOrThrow(paymentCreateSchema, input);
    return this.prisma.$transaction(async (tx) => {
      const guardian = await tx.schoolGuardian.findFirst({
        where: { id: data.guardianId, schoolId: actor.schoolId },
        select: {
          id: true,
          fullName: true,
          students: { where: { student: { schoolId: actor.schoolId, archived: false } }, select: { studentId: true } },
        },
      });
      if (!guardian) throw invalid('guardianId');
      const linked = guardian.students.map((s) => s.studentId);
      const studentIds = data.studentIds ? [...new Set(data.studentIds)] : linked;
      if (studentIds.some((sid) => !linked.includes(sid))) throw invalid('studentIds');
      if (studentIds.length === 0) throw invalid('studentIds: errors.form.selectAtLeastOne');
      const exists = await tx.schoolPaymentReminder.findUnique({
        where: { schoolId_guardianId: { schoolId: actor.schoolId, guardianId: guardian.id } },
        select: { id: true },
      });
      if (exists) throw conflict(`payment reminder exists for ${guardian.id}`);
      const created = await tx.schoolPaymentReminder.create({
        data: {
          schoolId: actor.schoolId,
          guardianId: guardian.id,
          studentIds,
          nextDate: data.nextDate,
          history: [historyEntry(actor, 'CREATED', data.note)] as unknown as Prisma.InputJsonValue,
        },
      });
      const view = toPaymentView(created);
      await this.audit.write(
        actor,
        {
          module: 'PAYMENTS',
          action: 'payment.create',
          summary: `${guardian.fullName}: to'lov eslatmasi yaratildi (keyingi sana ${data.nextDate})`,
          entityId: created.id,
          after: view,
          params: { name: guardian.fullName, date: data.nextDate },
        },
        tx,
      );
      return view;
    });
  }
}
