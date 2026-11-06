// Xodim tomoni: ulanish so'rovlari (K2). Uch tur bitta ro'yxatda:
//  - REVIEW — bola 6 raqamli kodni kiritdi, bog'lanish UNDER_REVIEW (id — `<kod yozuvi id>:<bola id>`: qaror xodim
//    KO'RGAN bolaga bog'lanadi; rad etilgach shu kodni boshqa bola kiritsa, eski id unga tegmaydi — 409);
//  - CORRECTION — bola "maktab / sinf noto'g'ri" dedi (id — `SchoolLinkCorrection.id`);
//  - GUARDIAN — telefoni mos kelmagan ota-ona 6 raqamli kodni kiritdi, vasiylik tasdiq kutmoqda
//    (id — `SchoolGuardianReview.id`; `guardian-review-requests.ts`).
// `confirm`: REVIEW — bog'lanish CONFIRMED (`SchoolStudent.childId`, ota-ona PUT'idagi invariantlar); CORRECTION —
// bog'lanish qoladi, maktab ma'lumoti qayta ochiladi; GUARDIAN — ota-ona vasiy bo'ladi. `reject`: REVIEW — o'quvchi
// o'rni bo'shaydi; CORRECTION — bog'lanish uziladi; GUARDIAN — ota-ona o'rni bo'shaydi. Ruxsat —
// `LINK_REQUESTS_PERMISSION` (`guardians.link`); sinf rahbari faqat o'z sinfi (doiradan tashqari — 403).

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { allowedClassIds, assertCan, assertClassInScope, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { listGuardianEntries, locateGuardianReview, resolveGuardianReview } from './guardian-review-requests';
import { LINK_REQUESTS_PERMISSION } from './link-access';
import { linkChildToStudent, releaseChildSlots, settleConfirmedLink } from './link-core';
import { linkRequestNotFound, requestStale } from './link-errors';
import { acquireLinkLocks, childLock, studentLock } from './link-locks';
import { correctionNotificationId, reviewNotificationId } from './link-notification-ids';
import { clearLinkNotifications } from './link-notifications';
import {
  decisionView,
  LINK_REQUESTS_LIMIT,
  LinkDecision,
  LinkRequestView,
  parseReviewId,
  RequestEntry,
  requestChildSelect,
  requestStudentSelect,
  reviewRequestId,
  toEntry,
} from './link-request-views';
import { studentName } from './student-view';

type Tx = Prisma.TransactionClient;

export { LINK_REQUESTS_LIMIT, reviewRequestId };
export type { LinkDecision, LinkRequestKind, LinkRequestView } from './link-request-views';

interface Target {
  kind: 'REVIEW' | 'CORRECTION' | 'GUARDIAN';
  studentId: string;
  /** Qaror bog'lanadigan bola (REVIEW / CORRECTION). */
  childId: string | null;
  /** Qulf uchun: shu so'rov tegadigan bolalar. */
  lockChildIds: string[];
}

@Injectable()
export class LinkRequestsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  /** Tasdiq kutayotgan bog'lanishlar, ochiq tuzatish so'rovlari va vasiylik so'rovlari (doira bo'yicha), eng eskilari birinchi. */
  async list(actor: SchoolActor): Promise<LinkRequestView[]> {
    assertCan(actor, LINK_REQUESTS_PERMISSION);
    const allowed = allowedClassIds(actor);
    const inScope = allowed ? { classId: { in: allowed } } : {};
    const [invites, corrections, guardians] = await Promise.all([
      this.prisma.schoolStudentInvite.findMany({
        where: {
          schoolId: actor.schoolId,
          studentChildId: { not: null },
          studentConfirmedAt: null,
          student: { archived: false, ...inScope },
        },
        select: {
          id: true,
          studentUsedAt: true,
          createdAt: true,
          student: { select: requestStudentSelect },
          studentChild: { select: requestChildSelect },
        },
        orderBy: { studentUsedAt: 'asc' },
        take: LINK_REQUESTS_LIMIT,
      }),
      this.prisma.schoolLinkCorrection.findMany({
        where: { schoolId: actor.schoolId, status: 'OPEN', student: { archived: false, ...inScope } },
        select: {
          id: true,
          reason: true,
          note: true,
          createdAt: true,
          student: { select: requestStudentSelect },
          child: { select: requestChildSelect },
        },
        orderBy: { createdAt: 'asc' },
        take: LINK_REQUESTS_LIMIT,
      }),
      listGuardianEntries(this.prisma, actor.schoolId, inScope),
    ]);
    const entries: RequestEntry[] = [
      ...invites.flatMap((i) =>
        i.studentChild
          ? [
              toEntry({
                kind: 'REVIEW',
                id: reviewRequestId(i.id, i.studentChild.id),
                at: i.studentUsedAt ?? i.createdAt,
                student: i.student,
                child: i.studentChild,
                parentId: i.studentChild.parentId,
              }),
            ]
          : [],
      ),
      // Bog'lanish boshqa yo'l bilan uzilgan (o'quvchi endi bu bolaga ulangan emas) — so'rov ma'nosiz, ko'rsatilmaydi.
      ...corrections
        .filter((c) => c.student.childId === c.child.id)
        .map((c) =>
          toEntry({
            kind: 'CORRECTION',
            id: c.id,
            at: c.createdAt,
            student: c.student,
            child: c.child,
            parentId: c.child.parentId,
            reason: c.reason,
            note: c.note,
          }),
        ),
      ...guardians,
    ];
    const linked = await this.linkedGuardians(
      entries.flatMap((e) => (e.parentId ? [{ studentId: e.student.id, userId: e.parentId }] : [])),
    );
    return entries
      .sort((a, b) => Date.parse(a.createdAt) - Date.parse(b.createdAt) || a.id.localeCompare(b.id))
      .slice(0, LINK_REQUESTS_LIMIT)
      .map(({ parentId, ...view }) => ({ ...view, parentLinked: parentId !== null && linked.has(`${view.student.id}:${parentId}`) }));
  }

  async confirm(actor: SchoolActor, id: string) {
    return this.resolve(actor, id, 'CONFIRMED');
  }

  async reject(actor: SchoolActor, id: string) {
    return this.resolve(actor, id, 'REJECTED');
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  private async resolve(actor: SchoolActor, id: string, decision: LinkDecision) {
    assertCan(actor, LINK_REQUESTS_PERMISSION);
    const target = await this.locate(actor, id);
    return this.prisma.$transaction(async (tx) => {
      await acquireLinkLocks(tx, [...target.lockChildIds.map(childLock), studentLock(target.studentId)]);
      if (target.kind === 'GUARDIAN') return resolveGuardianReview(tx, this.audit, actor, id, decision);
      if (target.kind === 'CORRECTION') return this.resolveCorrection(tx, actor, id, decision);
      return this.resolveReview(tx, actor, id, decision, target.childId!);
    });
  }

  /**
   * So'rovni maktab doirasida topadi (boshqa maktab / noma'lum id — 404), sinf doirasini tekshiradi (403).
   * REVIEW id'si `<kod yozuvi>:<bola>`: kod yozuvida hozir boshqa bola turgan bo'lsa — 409 (xodim ko'rgan so'rov eskirgan).
   */
  private async locate(actor: SchoolActor, id: string): Promise<Target> {
    const review = parseReviewId(id);
    if (!review) return this.locateByOwnId(actor, id);
    const invite = await this.prisma.schoolStudentInvite.findFirst({
      where: { id: review.inviteId, schoolId: actor.schoolId, studentChildId: { not: null } },
      select: { studentId: true, studentChildId: true, student: { select: { classId: true } } },
    });
    if (!invite?.studentChildId) throw linkRequestNotFound();
    assertClassInScope(actor, invite.student.classId);
    if (invite.studentChildId !== review.childId) throw requestStale();
    return { kind: 'REVIEW', studentId: invite.studentId, childId: review.childId, lockChildIds: [review.childId] };
  }

  /** Tuzatish so'rovi yoki vasiylik so'rovi (oddiy UUID id). */
  private async locateByOwnId(actor: SchoolActor, id: string): Promise<Target> {
    const correction = await this.prisma.schoolLinkCorrection.findFirst({
      where: { id, schoolId: actor.schoolId },
      select: { studentId: true, childId: true, student: { select: { classId: true } } },
    });
    if (correction) {
      assertClassInScope(actor, correction.student.classId);
      return { kind: 'CORRECTION', studentId: correction.studentId, childId: correction.childId, lockChildIds: [correction.childId] };
    }
    const guardian = await locateGuardianReview(this.prisma, actor.schoolId, id);
    if (!guardian) throw linkRequestNotFound();
    assertClassInScope(actor, guardian.classId);
    return { kind: 'GUARDIAN', studentId: guardian.studentId, childId: null, lockChildIds: guardian.childIds };
  }

  private async resolveReview(tx: Tx, actor: SchoolActor, requestId: string, decision: LinkDecision, expectedChildId: string) {
    const id = parseReviewId(requestId)?.inviteId ?? requestId;
    const invite = await tx.schoolStudentInvite.findFirst({
      where: { id, schoolId: actor.schoolId },
      select: {
        studentChildId: true,
        studentConfirmedAt: true,
        student: { select: requestStudentSelect },
        studentChild: { select: requestChildSelect },
      },
    });
    // Qulf kutilganda boshqa xodim / ota-ona hal qilgan bo'lishi mumkin; xodim ko'rgan bola o'rnini boshqa bola egallagan
    // bo'lishi mumkin (rad etilgach kodni qayta kiritgan) — qaror faqat o'sha bolaga tegishli.
    if (!invite?.studentChild || invite.studentChildId !== expectedChildId) throw requestStale();
    const { student, studentChild: child } = invite;
    if (invite.studentConfirmedAt) {
      if (decision === 'CONFIRMED') return decisionView(requestId, 'REVIEW', decision);
      throw requestStale();
    }
    if (student.archived) throw requestStale();
    const name = studentName(student);
    if (decision === 'CONFIRMED') {
      await linkChildToStudent(tx, student, child);
      await settleConfirmedLink(tx, student.id, child.id);
      await this.audit.write(
        actor,
        {
          module: 'STUDENTS',
          action: 'student.childLinked',
          summary: `${name}: Parvoz bola ilovasi bog'landi`,
          entityId: student.id,
          params: { name },
        },
        tx,
      );
    } else {
      await tx.schoolStudentInvite.update({ where: { id }, data: { studentChildId: null, studentUsedAt: null } });
      await clearLinkNotifications(tx, [reviewNotificationId(id)]);
      await this.audit.write(
        actor,
        {
          module: 'STUDENTS',
          action: 'student.linkRejected',
          summary: `${name}: bola ulanish so'rovi rad etildi`,
          entityId: student.id,
          params: { name },
        },
        tx,
      );
    }
    return decisionView(requestId, 'REVIEW', decision);
  }

  private async resolveCorrection(tx: Tx, actor: SchoolActor, id: string, decision: LinkDecision) {
    const correction = await tx.schoolLinkCorrection.findFirst({
      where: { id, schoolId: actor.schoolId },
      select: { status: true, childId: true, student: { select: requestStudentSelect } },
    });
    if (!correction) throw linkRequestNotFound();
    if (correction.status !== 'OPEN') {
      if (correction.status === decision) return decisionView(id, 'CORRECTION', decision);
      throw requestStale();
    }
    const { student, childId } = correction;
    if (student.childId !== childId) throw requestStale(); // bog'lanish boshqa yo'l bilan o'zgargan
    const name = studentName(student);
    if (decision === 'REJECTED') {
      await tx.schoolStudent.update({ where: { id: student.id }, data: { childId: null } });
      await releaseChildSlots(tx, childId);
    }
    await tx.schoolLinkCorrection.update({
      where: { id },
      data: { status: decision, resolvedAt: new Date(), resolvedByStaffId: actor.staffId },
    });
    await clearLinkNotifications(tx, [correctionNotificationId(id)]);
    await this.audit.write(
      actor,
      decision === 'REJECTED'
        ? {
            module: 'STUDENTS',
            action: 'student.childUnlinked',
            summary: `${name}: Parvoz bola ilovasi uzildi`,
            entityId: student.id,
            params: { name },
          }
        : {
            module: 'STUDENTS',
            action: 'student.linkCorrectionKept',
            summary: `${name}: bola so'rovi ko'rib chiqildi, bog'lanish qoldi`,
            entityId: student.id,
            params: { name },
          },
      tx,
    );
    return decisionView(id, 'CORRECTION', decision);
  }

  /** `studentId:userId` juftliklari — shu foydalanuvchi o'quvchining ulangan vasiysi. */
  private async linkedGuardians(pairs: Array<{ studentId: string; userId: string }>): Promise<Set<string>> {
    if (pairs.length === 0) return new Set();
    const rows = await this.prisma.schoolStudentGuardian.findMany({
      where: {
        OR: pairs.map((p) => ({ studentId: p.studentId, guardian: { userId: p.userId, linkStatus: 'LINKED' as const } })),
      },
      select: { studentId: true, guardian: { select: { userId: true } } },
    });
    return new Set(rows.map((r) => `${r.studentId}:${r.guardian.userId}`));
  }
}
