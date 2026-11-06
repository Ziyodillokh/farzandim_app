// Xodim "ulanish so'rovlari" navbatining umumiy ko'rinishlari: so'rov turlari, element shakli, REVIEW id'si.
// Bola ismi va ota-ona ma'lumoti FAQAT shu navbatda (xodimga qaror uchun kerak); bildirishnoma va auditda yo'q.

import { Prisma } from '@prisma/client';
import { studentFullName } from './student-view';

export type LinkRequestKind = 'REVIEW' | 'CORRECTION' | 'GUARDIAN';
export type LinkDecision = 'CONFIRMED' | 'REJECTED';

/** Navbat uzunligi chegarasi (eng eskilari birinchi). */
export const LINK_REQUESTS_LIMIT = 200;

export interface LinkRequestView {
  id: string;
  kind: LinkRequestKind;
  createdAt: string;
  /** Sinfi yo'q o'quvchi (sinf o'chirilgan): `classId` ham, `className` ham `null`. */
  student: { id: string; fullName: string; classId: string | null; className: string | null };
  /** REVIEW / CORRECTION — bola; GUARDIAN — ota-onaning shu o'quvchida tasdiq kutayotgan farzandi (bo'lsa); aks holda `null`. */
  child: { name: string } | null;
  /** Faqat GUARDIAN: so'rov yuborgan ota-ona (telefon niqoblangan); boshqa turlarda `null`. */
  parent: { name: string; maskedPhone: string | null } | null;
  /** Bolaning o'z ota-onasi o'quvchining ulangan vasiysi (xodimga ishonch belgisi); GUARDIAN uchun doim `false`. */
  parentLinked: boolean;
  reason: string | null;
  note: string | null;
}

export const requestStudentSelect = {
  id: true,
  schoolId: true,
  lastName: true,
  firstName: true,
  middleName: true,
  classId: true,
  childId: true,
  archived: true,
  class: { select: { name: true } },
} satisfies Prisma.SchoolStudentSelect;

export const requestChildSelect = { id: true, name: true, parentId: true } satisfies Prisma.ChildSelect;

export type RequestStudent = Prisma.SchoolStudentGetPayload<{ select: typeof requestStudentSelect }>;
export type RequestChild = Prisma.ChildGetPayload<{ select: typeof requestChildSelect }>;

/** Navbat elementi (`parentId` — "ota-ona vasiymi" belgisini hisoblash uchun, javobga chiqmaydi). */
export type RequestEntry = Omit<LinkRequestView, 'parentLinked'> & { parentId: string | null };

export function toEntry(input: {
  kind: LinkRequestKind;
  id: string;
  at: Date;
  student: RequestStudent;
  child: RequestChild | null;
  parent?: { name: string; maskedPhone: string | null } | null;
  parentId: string | null;
  reason?: string | null;
  note?: string | null;
}): RequestEntry {
  const { kind, id, at, student, child, parent = null, parentId, reason = null, note = null } = input;
  return {
    id,
    kind,
    createdAt: at.toISOString(),
    student: { id: student.id, fullName: studentFullName(student), classId: student.classId, className: student.class?.name ?? null },
    child: child ? { name: child.name } : null,
    parent,
    parentId,
    reason,
    note: note === null || note === '' ? null : note,
  };
}

export const decisionView = (id: string, kind: LinkRequestKind, status: LinkDecision) => ({ id, kind, status });

const REVIEW_ID_SEPARATOR = ':';

/** REVIEW so'rovining id'si: kod yozuvi + bola (qaror shu bolaga bog'lanadi). */
export const reviewRequestId = (inviteId: string, childId: string) => `${inviteId}${REVIEW_ID_SEPARATOR}${childId}`;

export function parseReviewId(id: string): { inviteId: string; childId: string } | null {
  const at = id.indexOf(REVIEW_ID_SEPARATOR);
  if (at <= 0 || at === id.length - 1) return null;
  return { inviteId: id.slice(0, at), childId: id.slice(at + 1) };
}
