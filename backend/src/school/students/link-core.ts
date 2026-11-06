// Bola ↔ o'quvchi bog'lanishining umumiy tranzaksion amallari (bola kodi, ota-ona kodi, xodim tasdig'i).
// "Tasdiqlangan" bog'lanish = `SchoolStudent.childId` — ota-onaning `PUT /parent/school/students/:id/child` bilan
// BIR XIL invariantlar: bola yagona (bitta o'quvchiga), o'quvchi boshqa OILA farzandiga ulangan bo'lsa
// `STUDENT_LINKED_ELSEWHERE`. Chaqiruvchi tegishli qulflarni (`link-locks`) oldindan oladi.

import { Prisma } from '@prisma/client';
import { alreadyEnrolled, studentLinkedElsewhere } from './link-errors';
import { correctionNotificationId, reviewNotificationId } from './link-notification-ids';
import { clearLinkNotifications } from './link-notifications';

type Tx = Prisma.TransactionClient;

export interface LinkableStudent {
  id: string;
  childId: string | null;
}

export interface LinkableChild {
  id: string;
  parentId: string;
}

const FREE_STUDENT_SLOT = { studentChildId: null, studentUsedAt: null, studentConfirmedAt: null } as const;

export type LinkOutcome = 'LINKED' | 'SAME' | 'STUDENT_LINKED_ELSEWHERE' | 'ALREADY_ENROLLED';

/**
 * `SchoolStudent.childId` ni o'rnatadi; to'siq bo'lsa HECH NARSA yozmasdan sababini qaytaradi:
 * - `SAME` — allaqachon shu bola;
 * - `STUDENT_LINKED_ELSEWHERE` — o'quvchida boshqa OILA farzandi bor (shu oilaning aka-ukasi bo'lsa almashtiriladi, u uziladi);
 * - `ALREADY_ENROLLED` — bola boshqa FAOL o'quvchiga ulangan (arxivdagi / to'xtatilgan maktabdagi eski
 *   bog'lanishdan ko'chiriladi — ota-ona PUT'idagi kabi).
 */
export async function tryLinkChildToStudent(tx: Tx, student: LinkableStudent, child: LinkableChild): Promise<LinkOutcome> {
  if (student.childId === child.id) return 'SAME';
  if (student.childId) {
    const holder = await tx.child.findUnique({ where: { id: student.childId }, select: { parentId: true } });
    if (!holder || holder.parentId !== child.parentId) return 'STUDENT_LINKED_ELSEWHERE';
  }
  const current = await tx.schoolStudent.findFirst({
    where: { childId: child.id, id: { not: student.id } },
    select: { id: true, archived: true, school: { select: { status: true } } },
  });
  if (current && !current.archived && current.school.status === 'ACTIVE') return 'ALREADY_ENROLLED';
  if (current) await tx.schoolStudent.update({ where: { id: current.id }, data: { childId: null } });
  if (student.childId) {
    // Almashtirilgan aka-uka: uning kod o'rinlari va ochiq tuzatish so'rovi endi ma'nosiz.
    await releaseChildSlots(tx, student.childId);
    await cancelOpenCorrections(tx, student.childId);
  }
  await tx.schoolStudent.update({ where: { id: student.id }, data: { childId: child.id } });
  return 'LINKED';
}

/** `tryLinkChildToStudent`ning istisno tashlaydigan varianti (xodim tasdig'i, bola kodi). `false` — o'zgarish yo'q. */
export async function linkChildToStudent(tx: Tx, student: LinkableStudent, child: LinkableChild): Promise<boolean> {
  const outcome = await tryLinkChildToStudent(tx, student, child);
  if (outcome === 'STUDENT_LINKED_ELSEWHERE') throw studentLinkedElsewhere();
  if (outcome === 'ALREADY_ENROLLED') throw alreadyEnrolled();
  return outcome === 'LINKED';
}

/**
 * Bola `studentId` ga TASDIQLANDI (har qanday yo'l bilan: xodim, ota-ona kodi, ota-ona PUT'i) — kod yozuvlari
 * va so'rovlar tozalanadi, eskirgan "UNDER_REVIEW" qayta tirilmaydi:
 *  - shu o'quvchidagi shu bolaning yozuvi CONFIRMED;
 *  - bolaning boshqa o'quvchilardagi o'rinlari va shu o'quvchidagi BOSHQA bolalarning kutayotgan o'rinlari bo'shaydi;
 *  - bolaning ochiq tuzatish so'rovlari bekor (CANCELLED) — yangi bog'lanish eskisini almashtiradi.
 */
export async function settleConfirmedLink(tx: Tx, studentId: string, childId: string, now = new Date()): Promise<void> {
  const confirmed = await tx.schoolStudentInvite.findMany({
    where: { studentId, studentChildId: childId, studentConfirmedAt: null },
    select: { id: true },
  });
  if (confirmed.length > 0) {
    await tx.schoolStudentInvite.updateMany({
      where: { id: { in: confirmed.map((r) => r.id) } },
      data: { studentConfirmedAt: now },
    });
  }
  const stale = await tx.schoolStudentInvite.findMany({
    where: {
      OR: [
        { studentChildId: childId, studentId: { not: studentId } },
        { studentId, AND: [{ studentChildId: { not: null } }, { studentChildId: { not: childId } }], studentConfirmedAt: null },
      ],
    },
    select: { id: true },
  });
  if (stale.length > 0) {
    await tx.schoolStudentInvite.updateMany({ where: { id: { in: stale.map((r) => r.id) } }, data: FREE_STUDENT_SLOT });
  }
  await cancelOpenCorrections(tx, childId, now);
  await clearLinkNotifications(tx, [...confirmed, ...stale].map((r) => reviewNotificationId(r.id)));
}

/**
 * Bolalar o'quvchidan UZILDI (ota-ona yoki xodim): ularning kod o'rinlari bo'shaydi va ochiq tuzatish so'rovlari
 * (hamda bildirishnomalari) bekor qilinadi — eskirgan "tasdiqlangan" o'rin yoki ochiq so'rov qolib ketmasin.
 */
export async function settleUnlinkedChildren(tx: Tx, childIds: readonly string[], now = new Date()): Promise<void> {
  for (const childId of new Set(childIds)) {
    await releaseChildSlots(tx, childId);
    await cancelOpenCorrections(tx, childId, now);
  }
}

/** Bolaning barcha kod o'rinlarini bo'shatadi (bog'lanish uzilganda / rad etilganda / almashtirilganda). */
export async function releaseChildSlots(tx: Tx, childId: string): Promise<void> {
  const rows = await tx.schoolStudentInvite.findMany({ where: { studentChildId: childId }, select: { id: true } });
  if (rows.length === 0) return;
  await tx.schoolStudentInvite.updateMany({ where: { id: { in: rows.map((r) => r.id) } }, data: FREE_STUDENT_SLOT });
  await clearLinkNotifications(tx, rows.map((r) => reviewNotificationId(r.id)));
}

/** Bolaning ochiq tuzatish so'rovlari ma'nosiz bo'lib qoldi (bog'lanish o'zgardi) — CANCELLED. */
export async function cancelOpenCorrections(tx: Tx, childId: string, now = new Date()): Promise<void> {
  const open = await tx.schoolLinkCorrection.findMany({ where: { childId, status: 'OPEN' }, select: { id: true } });
  if (open.length === 0) return;
  await tx.schoolLinkCorrection.updateMany({
    where: { id: { in: open.map((r) => r.id) } },
    data: { status: 'CANCELLED', resolvedAt: now },
  });
  await clearLinkNotifications(tx, open.map((r) => correctionNotificationId(r.id)));
}
