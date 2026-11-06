// Parvoz Growth bola ilovasi ↔ maktab o'quvchi kodi (K2): kod kiritish (bola o'rni), bog'lanish holati va
// "maktab / sinf noto'g'ri" so'rovi (A08).
//
// Ishonch modeli (D6): 6 raqamli maydon kichik, shuning uchun bola kodi O'Z-O'ZIDAN ishonch bermaydi — bog'lanish
// UNDER_REVIEW (maktab ma'lumoti yopiq) bo'lib, bolaning O'Z ota-onasi kodning ota-ona o'rnini band qilganda yoki
// o'quvchining ulangan vasiysi bo'lganda, yoki xodim tasdiqlaganda CONFIRMED bo'ladi (`SchoolStudent.childId`).
// Noto'g'ri urinishlar qattiq cheklanadi (`LinkAttemptLimiter`); maktab / o'quvchi nomi CONFIRMED'gacha hech qachon qaytmaydi.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { notEnrolled } from '../common/child-student';
import { SchoolAuditService } from '../common/school-audit.service';
import { parseOrThrow } from '../common/school-zod';
import { LinkAttemptLimiter } from './link-attempt-limiter';
import { linkChildToStudent, settleConfirmedLink } from './link-core';
import { alreadyEnrolled, childNotFound, CodeInvalidException, tooManyCorrections } from './link-errors';
import { acquireLinkLocks, childLock, studentLock } from './link-locks';
import {
  correctionNotificationId,
  LINK_CORRECTION_KIND,
  LINK_REVIEW_KIND,
  reviewNotificationId,
} from './link-notification-ids';
import { clearLinkNotifications, upsertLinkNotification } from './link-notifications';
import { LinkStatusBody, linkStatusOf } from './link-status';
import { studentName } from './student-view';
import { linkCorrectionSchema, studentCodeSchema } from './students.schemas';

type Tx = Prisma.TransactionClient;

/** Bola kuniga ko'pi bilan shuncha tuzatish so'rovi yubora oladi (takroriy `clientRequestId` hisoblanmaydi). */
export const MAX_CORRECTIONS_PER_DAY = 5;
const DAY_MS = 24 * 3_600_000;
const EXTERNAL_ACTOR = 'Bola ilovasi';

interface ChildRef {
  id: string;
  parentId: string;
}

const studentSelect = {
  id: true,
  schoolId: true,
  lastName: true,
  firstName: true,
  classId: true,
  childId: true,
  archived: true,
  class: { select: { name: true } },
  school: { select: { status: true } },
} satisfies Prisma.SchoolStudentSelect;

export interface CorrectionView {
  id: string;
  status: string;
}

@Injectable()
export class ChildLinkService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
    private readonly limiter: LinkAttemptLimiter,
  ) {}

  /**
   * Kodni kiritish (bola o'rni). Noto'g'ri / muddati o'tgan / yopilgan / o'rni band kod — bir xil 404 `CODE_INVALID`
   * (sababi ajratilmaydi); limit to'lgach 429 `LOCKED`. Bola allaqachon tasdiqlangan bo'lsa — 409 `ALREADY_ENROLLED`
   * (kod nima bo'lishidan qat'i nazar: javob kodni tekshirish vositasi bo'lmasin). Natija — holat tanasi.
   */
  async redeem(childUserId: string, input: unknown, ip = 'unknown'): Promise<LinkStatusBody> {
    const { code } = parseOrThrow(studentCodeSchema, input);
    const child = await this.childOf(childUserId);
    await this.limiter.guarded(child.id, ip, () => this.prisma.$transaction((tx) => this.redeemInTx(tx, child, code)));
    return linkStatusOf(this.prisma, child);
  }

  async status(childUserId: string): Promise<LinkStatusBody> {
    return linkStatusOf(this.prisma, await this.childOf(childUserId));
  }

  /**
   * "Maktab yoki sinf noto'g'ri" (A08). Faqat tasdiqlangan bog'lanish uchun (aks holda 404 `NOT_ENROLLED`).
   * Takroriy `clientRequestId` — o'sha so'rov; bolada bitta ochiq so'rov (yangisi o'shani qaytaradi).
   * OPEN bo'lganda bolaning maktab ma'lumoti yopiq (`requireEnrolledStudent` — 404 `UNDER_REVIEW`).
   */
  async requestCorrection(childUserId: string, input: unknown): Promise<CorrectionView> {
    const data = parseOrThrow(linkCorrectionSchema, input);
    const child = await this.childOf(childUserId);
    return this.prisma.$transaction(async (tx) => {
      await acquireLinkLocks(tx, [childLock(child.id)]);
      const replay = await tx.schoolLinkCorrection.findUnique({
        where: { childId_clientRequestId: { childId: child.id, clientRequestId: data.clientRequestId } },
      });
      if (replay) return toCorrectionView(replay);
      const student = await tx.schoolStudent.findFirst({
        where: { childId: child.id, archived: false, school: { status: 'ACTIVE' } },
        select: studentSelect,
      });
      if (!student) throw notEnrolled();
      const open = await tx.schoolLinkCorrection.findFirst({ where: { childId: child.id, status: 'OPEN' } });
      if (open) return toCorrectionView(open);
      const now = new Date();
      const recent = await tx.schoolLinkCorrection.count({
        where: { childId: child.id, createdAt: { gte: new Date(now.getTime() - DAY_MS) } },
      });
      if (recent >= MAX_CORRECTIONS_PER_DAY) throw tooManyCorrections();
      const created = await tx.schoolLinkCorrection.create({
        data: {
          schoolId: student.schoolId,
          studentId: student.id,
          childId: child.id,
          reason: data.reason,
          note: data.note,
          clientRequestId: data.clientRequestId,
        },
      });
      await upsertLinkNotification(tx, { id: correctionNotificationId(created.id), kind: LINK_CORRECTION_KIND, student, at: now });
      await this.audit.writeExternal(
        student.schoolId,
        EXTERNAL_ACTOR,
        {
          module: 'STUDENTS',
          action: 'student.linkCorrection',
          summary: `${studentName(student)}: bola maktab yoki sinf noto'g'ri deb xabar berdi`,
          entityId: student.id,
          params: { name: studentName(student) },
        },
        tx,
      );
      return toCorrectionView(created);
    });
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  private async redeemInTx(tx: Tx, child: ChildRef, code: string): Promise<void> {
    const now = new Date();
    await acquireLinkLocks(tx, [childLock(child.id)]);
    // Takroriy so'rov (birinchi javob yo'qolgan): bola shu kodni allaqachon o'zi kiritgan va o'rin hali kuchda
    // (kutayotgan yoki bog'lanish saqlanib turibdi) — o'zgarishsiz, xato emas.
    const own = await tx.schoolStudentInvite.findFirst({
      where: {
        code,
        studentChildId: child.id,
        expiresAt: { gt: now },
        OR: [{ studentConfirmedAt: null }, { student: { childId: child.id } }],
      },
      select: { id: true },
    });
    if (own) return;
    const confirmed = await tx.schoolStudent.findFirst({
      where: { childId: child.id, archived: false, school: { status: 'ACTIVE' } },
      select: { id: true },
    });
    const found = await tx.schoolStudentInvite.findFirst({
      where: { code, closedAt: null, expiresAt: { gt: now } },
      select: { id: true, studentId: true },
    });
    // Tasdiqlangan bola faqat O'Z o'quvchisining kodini qayta kirita oladi; boshqa HAR QANDAY kod (yaroqli ham,
    // yaroqsiz ham) — bir xil 409: javob kod haqida hech narsa bildirmaydi.
    if (confirmed && found?.studentId !== confirmed.id) throw alreadyEnrolled();
    if (!found) throw new CodeInvalidException();

    await acquireLinkLocks(tx, [studentLock(found.studentId)]);
    const invite = await tx.schoolStudentInvite.findFirst({
      where: { id: found.id, closedAt: null, expiresAt: { gt: now } },
      include: { student: { select: studentSelect } },
    });
    if (!invite || invite.student.archived || invite.student.school.status !== 'ACTIVE') throw new CodeInvalidException();
    const student = invite.student;
    if (invite.studentChildId && invite.studentChildId !== child.id) throw new CodeInvalidException(); // o'quvchi o'rni boshqa bolada
    if (student.childId && student.childId !== child.id) throw new CodeInvalidException(); // o'quvchi boshqa bolaga tasdiqlangan

    await this.releasePendingElsewhere(tx, child.id, invite.id);
    const alreadyLinked = student.childId === child.id;
    await tx.schoolStudentInvite.update({
      where: { id: invite.id },
      data: {
        studentChildId: child.id,
        studentUsedAt: now,
        studentConfirmedAt: alreadyLinked ? now : null,
        // Ikkala o'rin ham band bo'lsa kod yopiladi.
        closedAt: invite.parentUserId ? now : null,
      },
    });
    if (!alreadyLinked) {
      if (await this.parentVouches(tx, child, student.id)) {
        await this.confirm(tx, student, child, now);
      } else {
        await this.requestReview(tx, student, invite.id, now);
      }
    }
  }

  /** Bola boshqa o'quvchida kutayotgan bo'lsa — o'sha o'rin bo'shaydi (yangi kod uni almashtiradi). */
  private async releasePendingElsewhere(tx: Tx, childId: string, keepInviteId: string): Promise<void> {
    const others = await tx.schoolStudentInvite.findMany({
      where: { studentChildId: childId, studentConfirmedAt: null, id: { not: keepInviteId } },
      select: { id: true },
    });
    if (others.length === 0) return;
    await tx.schoolStudentInvite.updateMany({
      where: { id: { in: others.map((o) => o.id) } },
      data: { studentChildId: null, studentUsedAt: null },
    });
    await clearLinkNotifications(tx, others.map((o) => reviewNotificationId(o.id)));
  }

  /**
   * Bolaning O'Z ota-onasi hozir o'quvchining ulangan vasiysi. Ota-ona o'rnini band qilish vasiylikni shu
   * tranzaksiyada yaratadi, shuning uchun jonli tekshiruv yetarli — aloqasi uzilgan ota-onaning eski "o'rni" ishonch bermaydi.
   */
  private async parentVouches(tx: Tx, child: ChildRef, studentId: string): Promise<boolean> {
    const guardians = await tx.schoolStudentGuardian.count({
      where: { studentId, guardian: { userId: child.parentId, linkStatus: 'LINKED' } },
    });
    return guardians > 0;
  }

  private async confirm(tx: Tx, student: LinkStudent, child: ChildRef, now: Date): Promise<void> {
    await linkChildToStudent(tx, student, child);
    await settleConfirmedLink(tx, student.id, child.id, now);
    await this.audit.writeExternal(
      student.schoolId,
      EXTERNAL_ACTOR,
      {
        module: 'STUDENTS',
        action: 'student.childLinked',
        summary: `${studentName(student)}: Parvoz bola ilovasi bog'landi`,
        entityId: student.id,
        params: { name: studentName(student) },
      },
      tx,
    );
  }

  private async requestReview(tx: Tx, student: LinkStudent, inviteId: string, now: Date): Promise<void> {
    await upsertLinkNotification(tx, { id: reviewNotificationId(inviteId), kind: LINK_REVIEW_KIND, student, at: now });
    await this.audit.writeExternal(
      student.schoolId,
      EXTERNAL_ACTOR,
      {
        module: 'STUDENTS',
        action: 'student.linkRequested',
        summary: `${studentName(student)}: bola kod kiritdi, tasdiq kutilmoqda`,
        entityId: student.id,
        params: { name: studentName(student) },
      },
      tx,
    );
  }

  private async childOf(childUserId: string): Promise<ChildRef> {
    const child = await this.prisma.child.findUnique({ where: { childUserId }, select: { id: true, parentId: true } });
    if (!child) throw childNotFound();
    return child;
  }
}

type LinkStudent = Prisma.SchoolStudentGetPayload<{ select: typeof studentSelect }>;

const toCorrectionView = (c: { id: string; status: string }): CorrectionView => ({ id: c.id, status: c.status });
