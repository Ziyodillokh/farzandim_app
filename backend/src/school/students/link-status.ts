// Bolaning maktab bilan bog'lanish holati (`GET /child/school/link-status` va kod kiritish javobi).
// Maktab va sinf nomi FAQAT CONFIRMED holatda qaytadi — UNDER_REVIEW / CORRECTION / NONE da bola kod egasi
// qaysi maktab ekanini bilmaydi (kodni tanlab topgan begona bola maktab ma'lumotini ko'rmasin).

import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';

type Db = PrismaService | Prisma.TransactionClient;

export type StudentLinkState = 'NONE' | 'UNDER_REVIEW' | 'CONFIRMED' | 'CORRECTION';
export type ParentLinkState = 'PENDING' | 'UNDER_REVIEW' | 'CONFIRMED' | 'EXPIRED' | 'NONE';

export interface LinkStatusBody {
  student: { status: StudentLinkState; schoolName: string | null; className: string | null };
  parent: { status: ParentLinkState };
  expiresAt: string | null;
}

export interface StatusChild {
  id: string;
  parentId: string;
}

interface RelevantInvite {
  studentId: string;
  expiresAt: Date;
  closedAt: Date | null;
}

const noneBody = (): LinkStatusBody => ({
  student: { status: 'NONE', schoolName: null, className: null },
  parent: { status: 'NONE' },
  expiresAt: null,
});

/** Kod hali ishlatilishi mumkinmi: yopilmagan va muddati o'tmagan. */
export const isActive = (invite: { expiresAt: Date; closedAt: Date | null }, now: Date): boolean =>
  invite.closedAt === null && invite.expiresAt.getTime() > now.getTime();

export async function linkStatusOf(db: Db, child: StatusChild, now = new Date()): Promise<LinkStatusBody> {
  const confirmed = await db.schoolStudent.findFirst({
    where: { childId: child.id, archived: false, school: { status: 'ACTIVE' } },
    select: { id: true, class: { select: { name: true } }, school: { select: { name: true } } },
  });
  // Bola o'zi kiritgan kod: tasdiqlangan bo'lsa shu o'quvchidagi, aks holda kutayotgan (UNDER_REVIEW) yozuv.
  const invite: RelevantInvite | null = await db.schoolStudentInvite.findFirst({
    where: confirmed
      ? { studentId: confirmed.id, studentChildId: child.id }
      : { studentChildId: child.id, studentConfirmedAt: null, student: { archived: false, school: { status: 'ACTIVE' } } },
    orderBy: { studentUsedAt: 'desc' },
    select: { studentId: true, expiresAt: true, closedAt: true },
  });
  const studentId = confirmed?.id ?? invite?.studentId ?? null;
  if (!studentId) return noneBody();

  const correction = confirmed
    ? await db.schoolLinkCorrection.findFirst({
        where: { childId: child.id, studentId: confirmed.id, status: 'OPEN' },
        select: { id: true },
      })
    : null;
  const status: StudentLinkState = confirmed ? (correction ? 'CORRECTION' : 'CONFIRMED') : 'UNDER_REVIEW';
  const named = status === 'CONFIRMED' ? confirmed : null;
  const parent = await parentState(db, child, studentId, invite, now);
  return {
    student: { status, schoolName: named?.school.name ?? null, className: named?.class?.name ?? null },
    parent: { status: parent },
    expiresAt: invite && (parent === 'PENDING' || parent === 'EXPIRED') ? invite.expiresAt.toISOString() : null,
  };
}

/**
 * Ota-ona tomoni: bolaning O'Z ota-onasi hozir o'quvchining ulangan vasiysi — CONFIRMED (eski "ota-ona o'rni" ishonch
 * bermaydi: 6 raqamli kod o'zi vasiylik bermaydi); ota-ona o'rnini band qilgan, lekin vasiylik xodim ko'rigida —
 * UNDER_REVIEW; kod hali ishlatilishi mumkin — PENDING; muddati o'tgan / yopilgan — EXPIRED; kodsiz — NONE.
 */
async function parentState(
  db: Db,
  child: StatusChild,
  studentId: string,
  invite: RelevantInvite | null,
  now: Date,
): Promise<ParentLinkState> {
  const guardians = await db.schoolStudentGuardian.count({
    where: { studentId, guardian: { userId: child.parentId, linkStatus: 'LINKED' } },
  });
  if (guardians > 0) return 'CONFIRMED';
  const review = await db.schoolGuardianReview.count({ where: { userId: child.parentId, studentId, status: 'OPEN' } });
  if (review > 0) return 'UNDER_REVIEW';
  if (!invite) return 'NONE';
  return isActive(invite, now) ? 'PENDING' : 'EXPIRED';
}
