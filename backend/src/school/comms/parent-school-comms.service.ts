// Parvoz Parents ilovasi: maktab e'lonlari (o'qildi belgisi), to'lov
// eslatmalari va "to'laganman, tekshiring" so'rovlari. Ota-ona faqat `userId`si
// o'ziniki bo'lgan vasiy yozuvlariga yuborilganlarni ko'radi — boshqasi 404.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { conflict, notFound } from '../common/school-errors';
import { paginate, parseOrThrow } from '../common/school-zod';
import { parentPageSchema, verificationCreateSchema } from './comms.schemas';
import { toAudience } from './comms-roster';
import { lockPayment } from './payment-updates.service';
import { parseHistory } from './payment-views';
import { toVerificationStatus } from './verifications.service';

/** Ota-onaga ko'rsatiladigan so'nggi tekshiruv so'rovlari soni. */
const MAX_PARENT_VERIFICATIONS = 100;
/** To'lov tarixidan ota-onaga ko'rsatiladigan yozuvlar. */
const MAX_PARENT_HISTORY = 24;

const earliest = (dates: readonly (Date | null)[]): Date | null =>
  dates.reduce<Date | null>((min, d) => (d && (!min || d < min) ? d : min), null);

@Injectable()
export class ParentSchoolCommsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Yuborilgan e'lonlar (yangisi oldin) + o'qilmaganlar soni. */
  async announcements(userId: string, raw: Record<string, unknown>) {
    const query = parseOrThrow(parentPageSchema, raw);
    const guardianIds = await this.guardianIds(userId);
    const mine = { guardianId: { in: guardianIds } };
    const where = { status: 'SENT' as const, deliveries: { some: mine } };
    const total = await this.prisma.schoolAnnouncement.count({ where });
    const unread = await this.prisma.schoolAnnouncement.count({
      where: { status: 'SENT', deliveries: { some: { ...mine, readAt: null } } },
    });
    const rows = await this.prisma.schoolAnnouncement.findMany({
      where,
      orderBy: [{ sentAt: 'desc' }, { id: 'desc' }],
      skip: (query.page - 1) * query.limit,
      take: query.limit,
      include: { school: { select: { name: true } }, deliveries: { where: mine, select: { readAt: true } } },
    });
    const [authors, classNames] = await Promise.all([this.authors(rows), this.classNames(rows)]);
    const items = rows.map((a) => ({
      id: a.id,
      schoolId: a.schoolId,
      schoolName: a.school.name,
      title: a.title,
      body: a.body,
      priority: a.priority === 'IMPORTANT' ? 'IMPORTANT' : 'NORMAL',
      sentAt: a.sentAt?.toISOString() ?? null,
      readAt: earliest(a.deliveries.map((d) => d.readAt))?.toISOString() ?? null,
      from: authors.get(a.byStaffId) ?? null,
      audience: this.audienceView(a.audience, classNames),
    }));
    return { ...paginate(items, total, { page: query.page, limit: query.limit }), unread };
  }

  /** E'lon ochildi — o'qildi (va yetkazildi) deb belgilanadi; takror chaqirish vaqtni o'zgartirmaydi. */
  async markRead(userId: string, announcementId: string) {
    const guardianIds = await this.guardianIds(userId);
    const mine = { announcementId, guardianId: { in: guardianIds }, announcement: { status: 'SENT' as const } };
    const exists = await this.prisma.schoolAnnouncementDelivery.count({ where: mine });
    if (exists === 0) throw notFound(announcementId);
    const now = new Date();
    await this.prisma.schoolAnnouncementDelivery.updateMany({ where: { ...mine, readAt: null }, data: { readAt: now } });
    await this.prisma.schoolAnnouncementDelivery.updateMany({ where: { ...mine, deliveredAt: null }, data: { deliveredAt: now } });
    const rows = await this.prisma.schoolAnnouncementDelivery.findMany({ where: mine, select: { readAt: true } });
    return { id: announcementId, readAt: earliest(rows.map((r) => r.readAt))?.toISOString() ?? now.toISOString() };
  }

  /** To'lov eslatmalari: keyingi sana (maktab tasdiqlagan), farzandlar, ochiq so'rov bormi. */
  async payments(userId: string) {
    const guardianIds = await this.guardianIds(userId);
    const payments = await this.prisma.schoolPaymentReminder.findMany({
      where: { guardianId: { in: guardianIds } },
      orderBy: [{ nextDate: 'asc' }, { id: 'asc' }],
      include: { school: { select: { name: true } }, verifications: { where: { status: 'OPEN' }, select: { id: true } } },
    });
    const students = await this.prisma.schoolStudent.findMany({
      where: { id: { in: payments.flatMap((p) => p.studentIds) }, archived: false },
      select: { id: true, schoolId: true, lastName: true, firstName: true, class: { select: { name: true } } },
    });
    const byId = new Map(students.map((s) => [s.id, s]));
    return payments.map((p) => ({
      id: p.id,
      schoolId: p.schoolId,
      schoolName: p.school.name,
      nextDate: p.nextDate,
      prepaidMonths: p.prepaidMonths,
      paused: p.paused,
      children: p.studentIds
        .map((id) => byId.get(id))
        .filter((s): s is NonNullable<typeof s> => Boolean(s) && s?.schoolId === p.schoolId)
        .map((s) => ({ id: s.id, name: `${s.lastName} ${s.firstName}`, className: s.class?.name ?? '' })),
      openVerification: p.verifications.length > 0,
      // Tarix: faqat amal va vaqt — xodim izohi va kimligi ota-onaga ko'rsatilmaydi (ichki yozuv).
      history: parseHistory(p.history)
        .map((e) => ({ at: e.at, action: e.action }))
        .sort((a, b) => b.at.localeCompare(a.at))
        .slice(0, MAX_PARENT_HISTORY),
    }));
  }

  /** Mening tekshiruv so'rovlarim (yangisi oldin) — maktab javobi bilan. */
  async verifications(userId: string) {
    const guardianIds = await this.guardianIds(userId);
    const rows = await this.prisma.schoolVerificationRequest.findMany({
      where: { guardianId: { in: guardianIds } },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: MAX_PARENT_VERIFICATIONS,
      include: { school: { select: { name: true } }, payment: { select: { nextDate: true } } },
    });
    return rows.map((v) => this.toParentVerification(v, v.school.name, v.payment.nextDate));
  }

  /** "To'laganman, tekshiring": faqat o'z to'lov eslatmasiga; bittasida bir vaqtda bitta ochiq (409). */
  async createVerification(userId: string, body: unknown) {
    const data = parseOrThrow(verificationCreateSchema, body);
    const guardianIds = await this.guardianIds(userId);
    const payment = await this.prisma.schoolPaymentReminder.findFirst({
      where: { id: data.paymentReminderId, guardianId: { in: guardianIds } },
      include: { school: { select: { name: true } } },
    });
    if (!payment) throw notFound(data.paymentReminderId);
    const created = await this.prisma.$transaction(async (tx) => {
      await lockPayment(tx, payment.schoolId, payment.id);
      const open = await tx.schoolVerificationRequest.count({ where: { paymentReminderId: payment.id, status: 'OPEN' } });
      if (open > 0) throw conflict('open verification exists');
      return tx.schoolVerificationRequest.create({
        data: {
          schoolId: payment.schoolId,
          guardianId: payment.guardianId,
          paymentReminderId: payment.id,
          message: data.message,
          status: 'OPEN',
        },
      });
    });
    return this.toParentVerification(created, payment.school.name, payment.nextDate);
  }

  /** E'lon muallifi: rol va lavozim (ism — rasmiy e'lon imzosi). */
  private async authors(rows: readonly { byStaffId: string }[]) {
    const ids = [...new Set(rows.map((r) => r.byStaffId))];
    if (ids.length === 0) return new Map<string, { role: string; name: string; position: string }>();
    const staff = await this.prisma.schoolStaff.findMany({ where: { id: { in: ids } }, select: { id: true, role: true, fullName: true, position: true } });
    return new Map(staff.map((s) => [s.id, { role: s.role, name: s.fullName, position: s.position }]));
  }

  private async classNames(rows: readonly { audience: Prisma.JsonValue }[]) {
    const ids = [...new Set(rows.flatMap((r) => toAudience(r.audience).classIds))];
    if (ids.length === 0) return new Map<string, string>();
    const classes = await this.prisma.schoolClass.findMany({ where: { id: { in: ids } }, select: { id: true, name: true } });
    return new Map(classes.map((c) => [c.id, c.name]));
  }

  /** Kimga: butun maktab / sinflar / shaxsan (vasiylar ro'yxati oshkor qilinmaydi). */
  private audienceView(value: Prisma.JsonValue, classNames: ReadonlyMap<string, string>) {
    const a = toAudience(value);
    if (a.kind === 'SCHOOL') return { kind: 'SCHOOL' as const, classNames: [] };
    if (a.kind === 'CLASSES') {
      const names = a.classIds.map((id) => classNames.get(id)).filter((n): n is string => Boolean(n));
      return { kind: 'CLASSES' as const, classNames: names.sort((x, y) => x.localeCompare(y, 'uz', { numeric: true })) };
    }
    return { kind: 'PERSONAL' as const, classNames: [] };
  }

  private async guardianIds(userId: string): Promise<string[]> {
    const rows = await this.prisma.schoolGuardian.findMany({
      where: { userId, linkStatus: 'LINKED', school: { status: 'ACTIVE' } },
      select: { id: true },
    });
    return rows.map((r) => r.id);
  }

  private toParentVerification(
    v: { id: string; paymentReminderId: string; schoolId: string; message: string; status: string; answer: string | null; answeredAt: Date | null; createdAt: Date },
    schoolName: string,
    nextDate: string,
  ) {
    return {
      id: v.id,
      paymentReminderId: v.paymentReminderId,
      schoolId: v.schoolId,
      schoolName,
      nextDate,
      message: v.message,
      status: toVerificationStatus(v.status),
      answer: v.answer,
      answeredAt: v.answeredAt?.toISOString() ?? null,
      createdAt: v.createdAt.toISOString(),
    };
  }
}
