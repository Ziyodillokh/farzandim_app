// Parvoz Parents ilovasi ↔ 6 raqamli o'quvchi kodi (K2, ota-ona o'rni). 6 raqamli kod O'ZI hech qachon vasiylik
// bermaydi (maydon kichik — begona ota-ona tasodifan topib olishi mumkin):
//  (a) ota-ona allaqachon shu o'quvchining vasiysi (`userId`) — o'zgarishsiz;
//  (b) hech kimga ulanmagan, maktab kiritgan vasiy yozuvining telefoni ota-onaning HAQIQIY telefoniga mos (oxirgi 9 raqam;
//      `tg:` soxta telefon hech qachon) — maktab bu telefonga allaqachon ishongan, yozuv ulanadi;
//  (c) aks holda vasiy ULANMAYDI: xodim tasdig'ini kutuvchi `SchoolGuardianReview` yaratiladi (xodimga GUARDIAN_REVIEW
//      bildirishnomasi). Ota-ona o'rni band hisoblanadi; tasdiqlanmaguncha bu ota-ona hech qanday o'quvchi ma'lumotiga,
//      xabarga, davomatga, olib ketish va erta ketish so'roviga kira olmaydi.
// Bolasi shu o'quvchida UNDER_REVIEW da kutayotgan bo'lsa — vasiy ulangach (hozir yoki xodim tasdiqlaganda) bog'lanish
// CONFIRMED bo'ladi. 8 belgili vasiy kodi bilan ulanganda ham shunday (`ParentLinksService.redeemCode`): natija
// kim birinchi kod kiritganiga bog'liq emas.
//
// Qulf tartibi (`link-locks`): avval ota-onaning bolalari, keyin o'quvchi.

import { NotFoundException } from '@nestjs/common';
import { Prisma, SchoolGuardian } from '@prisma/client';
import { SchoolAuditService } from '../common/school-audit.service';
import { phoneTail, realPhone } from './guardian-phone';
import { settleConfirmedLink, tryLinkChildToStudent } from './link-core';
import { acquireLinkLocks, childLock, studentLock } from './link-locks';
import { GUARDIAN_REVIEW_KIND, guardianReviewNotificationId } from './link-notification-ids';
import { upsertLinkNotification } from './link-notifications';
import { studentName } from './student-view';

type Tx = Prisma.TransactionClient;

const GUARDIAN_NAME_MAX = 80;
const DEFAULT_GUARDIAN_NAME = 'Ota-ona';
const EXTERNAL_ACTOR = 'Ota-ona ilovasi';

/** Ota-ona ilovasidagi mavjud xato kodi (`INVITE_INVALID`) — yangi kod qo'shilmaydi. */
const inviteInvalid = () => new NotFoundException({ code: 'INVITE_INVALID', message: 'Invite code is invalid or expired' });

export const parentStudentSelect = {
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

export type ParentStudent = Prisma.SchoolStudentGetPayload<{ select: typeof parentStudentSelect }>;

const isLinkedGuardian = async (tx: Tx, studentId: string, userId: string): Promise<boolean> =>
  (await tx.schoolStudentGuardian.count({ where: { studentId, guardian: { userId, linkStatus: 'LINKED' } } })) > 0;

const hasOpenReview = async (tx: Tx, studentId: string, userId: string): Promise<boolean> =>
  (await tx.schoolGuardianReview.count({ where: { userId, studentId, status: 'OPEN' } })) > 0;

const linkedNow = (now: Date) => ({ linkStatus: 'LINKED' as const, linkedAt: now, inviteCode: null, inviteExpiresAt: null });

/**
 * Maktab allaqachon ishongan vasiy yozuvi: (a) shu foydalanuvchining o'z yozuvi, (b) hech kimga ulanmagan yozuv —
 * telefon bo'yicha. Topilsa LINKED holatga keltiriladi va qaytariladi; aks holda `null` (kod ishonch bermaydi).
 */
export async function linkKnownGuardian(
  tx: Tx,
  userId: string,
  student: { id: string; schoolId: string },
  now: Date,
): Promise<SchoolGuardian | null> {
  const guardians = await tx.schoolGuardian.findMany({
    where: { schoolId: student.schoolId, students: { some: { studentId: student.id } } },
  });
  const mine = guardians.find((g) => g.userId === userId);
  if (mine) {
    return mine.linkStatus === 'LINKED' ? mine : tx.schoolGuardian.update({ where: { id: mine.id }, data: linkedNow(now) });
  }
  const user = await tx.user.findUnique({ where: { id: userId }, select: { phone: true } });
  const tail = phoneTail(user?.phone);
  const byPhone = tail ? guardians.find((g) => g.userId === null && phoneTail(g.phone) === tail) : undefined;
  return byPhone ? tx.schoolGuardian.update({ where: { id: byPhone.id }, data: { ...linkedNow(now), userId } }) : null;
}

/** Xodim tasdiqlaganda: foydalanuvchi profilidan yangi LINKED vasiy yozuvi (`tg:` soxta telefon ko'chirilmaydi). */
export async function createGuardianFromUser(
  tx: Tx,
  userId: string,
  student: { id: string; schoolId: string },
  now: Date,
): Promise<SchoolGuardian> {
  const user = await tx.user.findUnique({ where: { id: userId }, select: { name: true, phone: true } });
  return tx.schoolGuardian.create({
    data: {
      schoolId: student.schoolId,
      fullName: (user?.name?.trim() || DEFAULT_GUARDIAN_NAME).slice(0, GUARDIAN_NAME_MAX),
      phone: realPhone(user?.phone),
      relation: 'OTHER',
      ...linkedNow(now),
      userId,
      students: { create: [{ studentId: student.id }] },
    },
  });
}

/**
 * 6 raqamli kodni ota-ona o'rniga kiritish. Noto'g'ri / muddati o'tgan / yopilgan / ota-ona o'rni BOSHQA ota-onada
 * band kod, yoki shu ota-ona avval rad etilgan kod — `INVITE_INVALID` (chaqiruvchi xato urinishlarni sanaydi).
 * O'z kodini qayta kiritish (vasiy yoki kutayotgan so'rov bor) — o'zgarishsiz. Qaytadi: shu bilan tasdiqlangan
 * bolalar (tranzaksiyadan keyin ularga push).
 */
export async function redeemParentSlot(tx: Tx, audit: SchoolAuditService, userId: string, code: string): Promise<string[]> {
  const now = new Date();
  const children = await tx.child.findMany({ where: { parentId: userId }, select: { id: true, parentId: true } });
  await acquireLinkLocks(tx, children.map((c) => childLock(c.id)));

  const own = await tx.schoolStudentInvite.findFirst({
    where: { code, parentUserId: userId, expiresAt: { gt: now } },
    select: { studentId: true },
  });
  // Takroriy so'rov (javob yo'qolgan): ota-ona hali vasiy yoki so'rovi xodim ko'rigida — kod yopilgan bo'lsa ham xato emas.
  // Aloqa keyin uzilgan / so'rov rad etilgan bo'lsa (eski o'rin ishonch bermaydi) kod faol bo'lsa qaytadan ko'rib chiqiladi.
  if (own && ((await isLinkedGuardian(tx, own.studentId, userId)) || (await hasOpenReview(tx, own.studentId, userId)))) return [];
  const found = await tx.schoolStudentInvite.findFirst({
    where: { code, closedAt: null, expiresAt: { gt: now } },
    select: { id: true, studentId: true },
  });
  if (!found) throw inviteInvalid();

  await acquireLinkLocks(tx, [studentLock(found.studentId)]);
  const invite = await tx.schoolStudentInvite.findFirst({
    where: { id: found.id, closedAt: null, expiresAt: { gt: now } },
    include: { student: { select: parentStudentSelect } },
  });
  if (!invite || invite.student.archived || invite.student.school.status !== 'ACTIVE') throw inviteInvalid();
  if (invite.parentUserId && invite.parentUserId !== userId) throw inviteInvalid(); // ota-ona o'rni boshqa ota-onada
  // Shu kod bo'yicha xodim bu ota-onaning so'rovini rad etgan: qayta-qayta so'rov bilan xodimni bezovta qilmaydi.
  if ((await tx.schoolGuardianReview.count({ where: { userId, inviteId: invite.id, status: 'REJECTED' } })) > 0) throw inviteInvalid();

  const student = invite.student;
  const known = await linkKnownGuardian(tx, userId, student, now);
  await tx.schoolStudentInvite.update({
    where: { id: invite.id },
    data: { parentUserId: userId, parentUsedAt: now, closedAt: invite.studentChildId ? now : null },
  });
  if (!known) {
    await requestGuardianReview(tx, audit, { userId, student, inviteId: invite.id, now });
    return [];
  }
  await audit.writeExternal(
    student.schoolId,
    `Ota-ona: ${known.fullName}`,
    {
      module: 'GUARDIANS',
      action: 'guardian.linked',
      summary: `${known.fullName} Parvoz Parents'ga ulandi`,
      entityId: known.id,
      params: { name: known.fullName },
    },
    tx,
  );
  const confirmed = await confirmOwnPendingChild(tx, { student, children, now });
  if (!confirmed) return [];
  await auditChildLinked(audit, `Ota-ona: ${known.fullName}`, student, tx);
  return [confirmed];
}

/** (c) Vasiy ulanmaydi: xodim ko'rigi so'rovi (bir ota-onada bitta o'quvchi uchun bitta ochiq) va bildirishnoma. */
async function requestGuardianReview(
  tx: Tx,
  audit: SchoolAuditService,
  input: { userId: string; student: ParentStudent; inviteId: string; now: Date },
): Promise<void> {
  const { userId, student, inviteId, now } = input;
  const open = await tx.schoolGuardianReview.findFirst({ where: { userId, studentId: student.id, status: 'OPEN' } });
  if (open) {
    // Xodim kodni qayta yaratgan bo'lsa: so'rov yangi kodning ota-ona o'rniga bog'lanadi (rad etilsa shu o'rin bo'shaydi).
    if (open.inviteId !== inviteId) await tx.schoolGuardianReview.update({ where: { id: open.id }, data: { inviteId } });
    return;
  }
  const review = await tx.schoolGuardianReview.create({
    data: { schoolId: student.schoolId, studentId: student.id, inviteId, userId },
  });
  await upsertLinkNotification(tx, { id: guardianReviewNotificationId(review.id), kind: GUARDIAN_REVIEW_KIND, student, at: now });
  await audit.writeExternal(
    student.schoolId,
    EXTERNAL_ACTOR,
    {
      module: 'GUARDIANS',
      action: 'guardian.reviewRequested',
      summary: `${studentName(student)}: ota-ona kod kiritdi, vasiylik tasdig'i kutilmoqda`,
      entityId: student.id,
      params: { name: studentName(student) },
    },
    tx,
  );
}

/**
 * Shu o'quvchida UNDER_REVIEW da kutayotgan bola SHU ota-onaning farzandi bo'lsa — bog'lanish tasdiqlanadi
 * (qaysi kod bilan kiritgani muhim emas: xodim kodni qayta yaratgan bo'lsa ham). Ota-ona vasiy bo'lgandan keyin
 * chaqiriladi. To'siq (o'quvchi boshqa oilaga ulangan, bola boshqa o'quvchida) — bog'lanish UNDER_REVIEW da qoladi,
 * xodim hal qiladi. Ulangan bo'lsa — tasdiqlangan bola id'si, aks holda `null`.
 */
export async function confirmOwnPendingChild(
  tx: Tx,
  ctx: { student: ParentStudent; children: Array<{ id: string; parentId: string }>; now: Date },
): Promise<string | null> {
  const { student, children, now } = ctx;
  if (children.length === 0) return null;
  const pending = await tx.schoolStudentInvite.findFirst({
    where: { studentId: student.id, studentConfirmedAt: null, studentChildId: { in: children.map((c) => c.id) } },
    orderBy: { studentUsedAt: 'asc' },
    select: { studentChildId: true },
  });
  const child = children.find((c) => c.id === pending?.studentChildId);
  if (!child) return null;
  const outcome = await tryLinkChildToStudent(tx, student, child);
  if (outcome === 'STUDENT_LINKED_ELSEWHERE' || outcome === 'ALREADY_ENROLLED') return null;
  await settleConfirmedLink(tx, student.id, child.id, now);
  return child.id;
}

export async function auditChildLinked(audit: SchoolAuditService, actorName: string, student: ParentStudent, tx: Tx): Promise<void> {
  await audit.writeExternal(
    student.schoolId,
    actorName,
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
