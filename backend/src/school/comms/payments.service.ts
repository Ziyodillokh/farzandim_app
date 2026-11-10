// To'lov eslatmalari (panel `commsService.payments`): ro'yxat, ko'rsatkichlar,
// CSV eksport (sahifalashsiz), tarix; yangi oila eslatmasi (`create`) va sinf
// bo'yicha ommaviy yaratish (`bulkCreate`). O'zgartirishlar — `PaymentUpdatesService`.
// Ruxsat: o'qish — payments.view (sinf rahbari — faqat o'z sinfi, faqat ko'rish);
// yaratish va o'zgartirish — payments.manage.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { allowedClassIds, assertCan, assertClassInScope, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, forbidden, invalid, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { paymentBulkCreateSchema, paymentCreateSchema, paymentFilterSchema, paymentStatsQuerySchema } from './comms.schemas';
import { pageOf } from './comms-paging';
import {
  historyEntry,
  inClass,
  loadPaymentRows,
  parseHistory,
  PaymentView,
  paymentStats,
  PaymentRow,
  queryPaymentRows,
  scopePaymentRows,
  toPaymentView,
} from './payment-views';

type GuardianPick = { id: string; linkStatus: string; createdAt: Date };

const LINK_RANK: Record<string, number> = { LINKED: 0, INVITED: 1 };

/** Oila eslatmasi kimga: Parvoz Parents'ga ulangan vasiy, keyin taklif qilingan, keyin birinchi kiritilgan. */
export function pickGuardian(guardians: readonly GuardianPick[]): GuardianPick | null {
  const sorted = [...guardians].sort(
    (a, b) => (LINK_RANK[a.linkStatus] ?? 2) - (LINK_RANK[b.linkStatus] ?? 2) || a.createdAt.getTime() - b.createdAt.getTime(),
  );
  return sorted[0] ?? null;
}

@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  async list(actor: SchoolActor, raw: Record<string, unknown>) {
    assertCan(actor, 'payments.view');
    const filter = parseOrThrow(paymentFilterSchema, raw);
    if (filter.classId) assertClassInScope(actor, filter.classId);
    return pageOf(queryPaymentRows(await this.scopedRows(actor), filter), filter.page, filter.limit);
  }

  /** Ko'rsatkichlar — ro'yxat bilan bir xil doira va sinf filtri bo'yicha. */
  async stats(actor: SchoolActor, raw: Record<string, unknown> = {}) {
    assertCan(actor, 'payments.view');
    const { classId } = parseOrThrow(paymentStatsQuerySchema, raw);
    if (classId) assertClassInScope(actor, classId);
    const rows = (await this.scopedRows(actor)).filter((r) => inClass(r, classId));
    return paymentStats(rows, tashkentDay());
  }

  /** CSV uchun — filtr bo'yicha BARCHA qatorlar (sahifalashsiz). */
  async exportRows(actor: SchoolActor, raw: Record<string, unknown>) {
    assertCan(actor, 'payments.view');
    const filter = parseOrThrow(paymentFilterSchema, raw);
    if (filter.classId) assertClassInScope(actor, filter.classId);
    return queryPaymentRows(await this.scopedRows(actor), filter);
  }

  /** Tarix: yangi → eski, xodim ismi bilan. */
  async history(actor: SchoolActor, id: string) {
    assertCan(actor, 'payments.view');
    const payment = await this.prisma.schoolPaymentReminder.findFirst({ where: { id, schoolId: actor.schoolId } });
    if (!payment) throw notFound(id);
    if (!(await this.inScope(actor, payment.studentIds))) throw forbidden(`payment ${id}`);
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

  /**
   * Sinf bo'yicha ommaviy yaratish: sinfning eslatmasi yo'q har faol o'quvchisi uchun bitta vasiy tanlanadi
   * (`pickGuardian`); bir vasiyning shu sinfdagi farzandlari bitta eslatmada. O'quvchi boshqa eslatmada bo'lsa
   * yoki tanlangan vasiyning eslatmasi allaqachon bor bo'lsa — o'tkazib yuboriladi (`skipped`); vasiysi yo'q — `noGuardian`.
   */
  async bulkCreate(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'payments.manage');
    const data = parseOrThrow(paymentBulkCreateSchema, input);
    return this.prisma.$transaction(
      async (tx) => {
        const cls = await tx.schoolClass.findFirst({ where: { id: data.classId, schoolId: actor.schoolId }, select: { id: true, name: true } });
        if (!cls) throw invalid('classId');
        const [students, existing] = await Promise.all([
          tx.schoolStudent.findMany({
            where: { schoolId: actor.schoolId, classId: cls.id, archived: false },
            select: { id: true, guardians: { select: { guardian: { select: { id: true, linkStatus: true, createdAt: true } } } } },
            orderBy: [{ lastName: 'asc' }, { firstName: 'asc' }, { id: 'asc' }],
          }),
          tx.schoolPaymentReminder.findMany({ where: { schoolId: actor.schoolId }, select: { guardianId: true, studentIds: true } }),
        ]);
        const covered = new Set(existing.flatMap((e) => e.studentIds));
        const taken = new Set(existing.map((e) => e.guardianId));
        const plan = new Map<string, string[]>();
        let skipped = 0;
        let noGuardian = 0;
        for (const student of students) {
          const guardian = covered.has(student.id) ? null : pickGuardian(student.guardians.map((g) => g.guardian));
          if (covered.has(student.id) || (guardian && taken.has(guardian.id))) skipped += 1;
          else if (!guardian) noGuardian += 1;
          else plan.set(guardian.id, [...(plan.get(guardian.id) ?? []), student.id]);
        }
        for (const [guardianId, studentIds] of plan) {
          await tx.schoolPaymentReminder.create({
            data: {
              schoolId: actor.schoolId,
              guardianId,
              studentIds,
              nextDate: data.nextDate,
              history: [historyEntry(actor, 'CREATED', data.note)] as unknown as Prisma.InputJsonValue,
            },
          });
        }
        if (plan.size > 0) {
          await this.audit.write(
            actor,
            {
              module: 'PAYMENTS',
              action: 'payment.bulkCreate',
              summary: `${cls.name}: ${plan.size} oila uchun to'lov eslatmasi yaratildi (keyingi sana ${data.nextDate})`,
              entityId: cls.id,
              after: { created: plan.size, nextDate: data.nextDate },
              params: { className: cls.name, count: plan.size, date: data.nextDate },
            },
            tx,
          );
        }
        return { created: plan.size, skipped, noGuardian };
      },
      { timeout: 60_000 },
    );
  }

  /** Aktyor doirasidagi qatorlar (sinf rahbari — faqat o'z sinflaridagi farzandlar bilan). */
  private async scopedRows(actor: SchoolActor): Promise<PaymentRow[]> {
    const rows = await loadPaymentRows(this.prisma, actor.schoolId, tashkentDay());
    return scopePaymentRows(rows, allowedClassIds(actor));
  }

  private async inScope(actor: SchoolActor, studentIds: readonly string[]): Promise<boolean> {
    const allowed = allowedClassIds(actor);
    if (!allowed) return true;
    const count = await this.prisma.schoolStudent.count({
      where: { schoolId: actor.schoolId, id: { in: [...studentIds] }, classId: { in: allowed } },
    });
    return count > 0;
  }
}
