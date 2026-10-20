// Tekshiruv so'rovlari (panel `commsService.verifications`): ota-ona ilovada
// "to'laganman, tekshiring" deydi (`ParentSchoolCommsService.createVerification`),
// maktab javob beradi (ixtiyoriy — eslatma sanasini ham to'g'rilaydi) yoki
// yopadi. Javob ota-onaga push bilan boradi. Ruxsat: payments.manage.

import { Injectable, Logger } from '@nestjs/common';
import { Prisma, SchoolVerificationRequest } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { matchesSearch } from '../common/list-query';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { verificationAnsweredPush } from './comms.i18n';
import { VERIFICATION_STATUSES, verificationAnswerSchema, verificationFilterSchema, VerificationStatus } from './comms.schemas';
import { countBy, pageOf } from './comms-paging';
import { CommsPushService } from './comms-push.service';
import { childrenByGuardian, loadRoster } from './comms-roster';
import { guardianLabel, lockPayment, PaymentUpdatesService } from './payment-updates.service';

type Tx = Prisma.TransactionClient;

const STATUS_ORDER: Record<VerificationStatus, number> = { OPEN: 0, ANSWERED: 1, CLOSED: 2 };

export const toVerificationStatus = (v: string): VerificationStatus =>
  VERIFICATION_STATUSES.find((s) => s === v) ?? 'OPEN';

export function toVerificationView(v: SchoolVerificationRequest) {
  return {
    id: v.id,
    guardianId: v.guardianId,
    paymentReminderId: v.paymentReminderId,
    message: v.message,
    createdAt: v.createdAt.toISOString(),
    status: toVerificationStatus(v.status),
    answer: v.answer,
    answeredByStaffId: v.answeredByStaffId,
    answeredAt: v.answeredAt?.toISOString() ?? null,
  };
}

@Injectable()
export class VerificationsService {
  private readonly logger = new Logger(VerificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
    private readonly payments: PaymentUpdatesService,
    private readonly push: CommsPushService,
  ) {}

  async list(actor: SchoolActor, raw: Record<string, unknown>) {
    assertCan(actor, 'payments.manage');
    const filter = parseOrThrow(verificationFilterSchema, raw);
    const roster = await loadRoster(this.prisma, actor.schoolId);
    const all = await this.prisma.schoolVerificationRequest.findMany({
      where: { schoolId: actor.schoolId },
      include: { payment: { select: { id: true, nextDate: true, prepaidMonths: true, paused: true } } },
    });
    const staff = await this.prisma.schoolStaff.findMany({ where: { schoolId: actor.schoolId }, select: { id: true, fullName: true } });
    const names = new Map(staff.map((s) => [s.id, s.fullName]));
    const children = childrenByGuardian(roster);
    const rows = all.map((v) => ({
      ...toVerificationView(v),
      guardianName: roster.guardians.get(v.guardianId)?.fullName ?? '—',
      phone: roster.guardians.get(v.guardianId)?.phone ?? '',
      children: children.get(v.guardianId) ?? [],
      payment: v.payment,
      answeredByName: v.answeredByStaffId ? (names.get(v.answeredByStaffId) ?? '—') : null,
    }));
    const filtered = rows
      .filter((r) => !filter.status || r.status === filter.status)
      .filter(
        (r) =>
          !filter.search ||
          matchesSearch(`${r.guardianName} ${r.phone} ${r.message} ${r.children.map((c) => c.name).join(' ')}`, filter.search),
      )
      .sort((a, b) => STATUS_ORDER[a.status] - STATUS_ORDER[b.status] || b.createdAt.localeCompare(a.createdAt));
    return { ...pageOf(filtered, filter.page, filter.limit), counts: countBy(rows, VERIFICATION_STATUSES, (r) => r.status) };
  }

  /** Javob (ota-onaga push). `newDate` — eslatma sanasini ham to'g'rilash (tarixda VERIFIED). */
  async answer(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'payments.manage');
    const data = parseOrThrow(verificationAnswerSchema, input);
    const next = await this.prisma.$transaction(async (tx) => {
      const current = await this.findOpen(tx, actor, id);
      if (data.newDate) {
        const payment = await lockPayment(tx, actor.schoolId, current.paymentReminderId);
        await this.payments.applyShift(tx, actor, payment, data.newDate, `Tekshiruv so'rovi bo'yicha: ${data.text}`, 'VERIFIED');
      }
      const updated = await this.setStatus(tx, actor, id, {
        status: 'ANSWERED',
        answer: data.text,
        answeredByStaffId: actor.staffId,
        answeredAt: new Date(),
      });
      const name = await guardianLabel(tx, current);
      await this.audit.write(
        actor,
        {
          module: 'PAYMENTS',
          action: 'verification.answer',
          summary: `${name}ning tekshiruv so'roviga javob berildi${data.newDate ? ` (yangi sana: ${data.newDate})` : ''}`,
          entityId: id,
          before: toVerificationView(current),
          after: toVerificationView(updated),
          params: { variant: data.newDate ? 'newDate' : 'plain', name, newDate: data.newDate ?? '' },
        },
        tx,
      );
      return updated;
    });
    await this.notifyAnswered(next);
    return toVerificationView(next);
  }

  async close(actor: SchoolActor, id: string) {
    assertCan(actor, 'payments.manage');
    return this.prisma.$transaction(async (tx) => {
      const current = await this.findOpen(tx, actor, id);
      const next = await this.setStatus(tx, actor, id, { status: 'CLOSED' });
      const name = await guardianLabel(tx, current);
      await this.audit.write(
        actor,
        {
          module: 'PAYMENTS',
          action: 'verification.close',
          summary: `${name}ning tekshiruv so'rovi yopildi`,
          entityId: id,
          before: { status: current.status },
          after: { status: 'CLOSED' },
          params: { name },
        },
        tx,
      );
      return toVerificationView(next);
    });
  }

  /** Shu maktabdagi, hali yopilmagan so'rov (yo'q → 404, yopilgan → 409). */
  private async findOpen(tx: Tx, actor: SchoolActor, id: string): Promise<SchoolVerificationRequest> {
    const current = await tx.schoolVerificationRequest.findFirst({ where: { id, schoolId: actor.schoolId } });
    if (!current) throw notFound(id);
    if (current.status === 'CLOSED') throw conflict('closed');
    return current;
  }

  /** Shartli: parallel yopilgan bo'lsa — 409. */
  private async setStatus(
    tx: Tx,
    actor: SchoolActor,
    id: string,
    data: Prisma.SchoolVerificationRequestUpdateManyMutationInput,
  ): Promise<SchoolVerificationRequest> {
    const res = await tx.schoolVerificationRequest.updateMany({
      where: { id, schoolId: actor.schoolId, status: { not: 'CLOSED' } },
      data,
    });
    if (res.count !== 1) throw conflict('closed');
    return tx.schoolVerificationRequest.findUniqueOrThrow({ where: { id } });
  }

  /** Ota-onaga (ilovasi bo'lsa) javob haqida push — javob saqlangan, xato faqat log. */
  private async notifyAnswered(v: SchoolVerificationRequest): Promise<void> {
    try {
      const guardian = await this.prisma.schoolGuardian.findFirst({
        where: { id: v.guardianId, schoolId: v.schoolId, linkStatus: 'LINKED' },
        select: { userId: true },
      });
      if (!guardian?.userId || !v.answer) return;
      const school = await this.push.schoolLabel(v.schoolId);
      const answer = v.answer;
      await this.push.sendOne(guardian.userId, (lang) =>
        verificationAnsweredPush(lang, { id: v.id, school, answer, paymentReminderId: v.paymentReminderId }),
      );
    } catch (err) {
      this.logger.error(`tekshiruv javobi push xatosi (${v.id}): ${String(err)}`);
    }
  }
}
