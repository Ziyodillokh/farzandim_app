// Xodim navbatidagi GUARDIAN so'rovlari (K2): 6 raqamli kod bilan ota-ona o'rnini band qilgan, lekin maktab ishonchli deb
// bilmagan ota-ona (telefon mos kelmadi) — `SchoolGuardianReview`. Tasdiqlanmaguncha u vasiy EMAS va hech narsaga kira olmaydi.
// `confirm`: vasiy yozuvi ulanadi (mos yozuv bo'lsa — shu, aks holda profildan yangisi), audit `guardian.linked`; shu
// ota-onaning farzandi shu o'quvchida UNDER_REVIEW da kutayotgan bo'lsa — bog'lanish CONFIRMED. `reject`: so'rov
// yopiladi, kod yozuvidagi ota-ona o'rni bo'shaydi (audit `guardian.linkRejected`); shu ota-ona shu kodni qayta kirita olmaydi.

import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { maskPhone } from './guardian-phone';
import { linkRequestNotFound, requestStale } from './link-errors';
import { guardianReviewNotificationId } from './link-notification-ids';
import { clearLinkNotifications } from './link-notifications';
import {
  confirmOwnPendingChild,
  createGuardianFromUser,
  linkKnownGuardian,
  parentStudentSelect,
} from './parent-student-code';
import {
  decisionView,
  LINK_REQUESTS_LIMIT,
  LinkDecision,
  RequestEntry,
  requestStudentSelect,
  Resolution,
  toEntry,
} from './link-request-views';
import type { LinkNotice } from './link-decision-push';
import { studentName } from './student-view';

type Tx = Prisma.TransactionClient;

const DEFAULT_PARENT_NAME = 'Ota-ona';

export interface GuardianTarget {
  studentId: string;
  /** Qulf uchun: so'rov egasi ota-onaning bolalari. */
  childIds: string[];
}

/** Ochiq vasiylik so'rovlari (doira bo'yicha) va ota-onaning kutayotgan farzandi (bo'lsa). */
export async function listGuardianEntries(
  prisma: PrismaService,
  schoolId: string,
  inScope: { classId?: { in: string[] } },
): Promise<RequestEntry[]> {
  const reviews = await prisma.schoolGuardianReview.findMany({
    where: { schoolId, status: 'OPEN', student: { archived: false, ...inScope } },
    select: {
      id: true,
      userId: true,
      createdAt: true,
      user: { select: { name: true, phone: true } },
      student: { select: requestStudentSelect },
    },
    orderBy: { createdAt: 'asc' },
    take: LINK_REQUESTS_LIMIT,
  });
  if (reviews.length === 0) return [];
  const waiting = await prisma.schoolStudentInvite.findMany({
    where: {
      studentConfirmedAt: null,
      studentChildId: { not: null },
      OR: reviews.map((r) => ({ studentId: r.student.id, studentChild: { parentId: r.userId } })),
    },
    select: { studentId: true, studentChild: { select: { id: true, name: true, parentId: true } } },
  });
  const childOf = new Map(waiting.flatMap((w) => (w.studentChild ? [[`${w.studentId}:${w.studentChild.parentId}`, w.studentChild] as const] : [])));
  return reviews.map((r) =>
    toEntry({
      kind: 'GUARDIAN',
      id: r.id,
      at: r.createdAt,
      student: r.student,
      child: childOf.get(`${r.student.id}:${r.userId}`) ?? null,
      parent: { name: r.user.name?.trim() || DEFAULT_PARENT_NAME, maskedPhone: maskPhone(r.user.phone) },
      parentId: null,
    }),
  );
}

/** Vasiylik so'rovini maktab doirasida topadi (topilmasa `null`); sinf doirasini chaqiruvchi tekshiradi. */
export async function locateGuardianReview(
  prisma: PrismaService,
  schoolId: string,
  id: string,
): Promise<(GuardianTarget & { classId: string | null }) | null> {
  const review = await prisma.schoolGuardianReview.findFirst({
    where: { id, schoolId },
    select: { studentId: true, userId: true, student: { select: { classId: true } } },
  });
  if (!review) return null;
  const children = await prisma.child.findMany({ where: { parentId: review.userId }, select: { id: true } });
  return { studentId: review.studentId, classId: review.student.classId, childIds: children.map((c) => c.id) };
}

export async function resolveGuardianReview(
  tx: Tx,
  audit: SchoolAuditService,
  actor: SchoolActor,
  id: string,
  decision: LinkDecision,
): Promise<Resolution> {
  const review = await tx.schoolGuardianReview.findFirst({
    where: { id, schoolId: actor.schoolId },
    select: { status: true, userId: true, inviteId: true, student: { select: parentStudentSelect } },
  });
  if (!review) throw linkRequestNotFound();
  if (review.status !== 'OPEN') {
    if (review.status === decision) return { view: decisionView(id, 'GUARDIAN', decision), notices: [] };
    throw requestStale();
  }
  const { student, userId } = review;
  if (student.archived) throw requestStale();
  const now = new Date();
  const notices: LinkNotice[] = [];
  if (decision === 'CONFIRMED') {
    const guardian = (await linkKnownGuardian(tx, userId, student, now)) ?? (await createGuardianFromUser(tx, userId, student, now));
    await audit.write(
      actor,
      {
        module: 'GUARDIANS',
        action: 'guardian.linked',
        summary: `${guardian.fullName} Parvoz Parents'ga ulandi`,
        entityId: guardian.id,
        params: { name: guardian.fullName },
      },
      tx,
    );
    const children = await tx.child.findMany({ where: { parentId: userId }, select: { id: true, parentId: true } });
    notices.push({ to: 'PARENT', userId, event: 'GUARDIAN_CONFIRMED', schoolId: student.schoolId, studentFirstName: student.firstName });
    const confirmedChildId = await confirmOwnPendingChild(tx, { student, children, now });
    if (confirmedChildId) {
      notices.push({ to: 'CHILD', childId: confirmedChildId, event: 'CONFIRMED' });
      await audit.write(
        actor,
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
  } else {
    notices.push({ to: 'PARENT', userId, event: 'GUARDIAN_REJECTED' });
    if (review.inviteId) {
      await tx.schoolStudentInvite.updateMany({
        where: { id: review.inviteId, parentUserId: userId },
        data: { parentUserId: null, parentUsedAt: null },
      });
    }
    await audit.write(
      actor,
      {
        module: 'GUARDIANS',
        action: 'guardian.linkRejected',
        summary: `${studentName(student)}: ota-ona vasiylik so'rovi rad etildi`,
        entityId: student.id,
        params: { name: studentName(student) },
      },
      tx,
    );
  }
  await tx.schoolGuardianReview.update({
    where: { id },
    data: { status: decision, resolvedAt: now, resolvedByStaffId: actor.staffId },
  });
  await clearLinkNotifications(tx, [guardianReviewNotificationId(id)]);
  return { view: decisionView(id, 'GUARDIAN', decision), notices };
}
