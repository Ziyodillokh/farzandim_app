// Bola ilovasi e'lonlari: ko'rinish sharti (faqat o'z maktabi / sinfi, `includeStudents`),
// kursor (sentAt, id) va javob elementi. Sof funksiyalar — servis faqat DB bilan ishlaydi.

import { Prisma } from '@prisma/client';

export type ChildAudienceLabel = 'SCHOOL' | 'CLASS';

export interface ChildAnnouncementItem {
  id: string;
  title: string;
  body: string;
  priority: 'NORMAL' | 'IMPORTANT';
  sentAt: string | null;
  author: { name: string; role: string | null };
  audienceLabel: ChildAudienceLabel;
  className?: string;
  read: boolean;
}

/**
 * Bolaga ko'rinadigan e'lonlar: o'z maktabining YUBORILGAN e'lonlari, auditoriyasida
 * `includeStudents = true` va u butun maktab yoki bolaning HOZIRGI sinfini qamrab oladi.
 * Boshqa sinf / vasiylar auditoriyasi hech qachon mos kelmaydi.
 */
export function childVisibleWhere(schoolId: string, classId: string): Prisma.SchoolAnnouncementWhereInput {
  return {
    schoolId,
    status: 'SENT',
    AND: [
      { audience: { path: ['includeStudents'], equals: true } },
      {
        OR: [
          { audience: { path: ['kind'], equals: 'SCHOOL' } },
          {
            AND: [
              { audience: { path: ['kind'], equals: 'CLASSES' } },
              { audience: { path: ['classIds'], array_contains: [classId] } },
            ],
          },
        ],
      },
    ],
  };
}

export interface FeedCursor {
  sentAt: Date;
  id: string;
}

export function encodeCursor(row: { sentAt: Date | null; id: string }): string | null {
  if (!row.sentAt) return null;
  return Buffer.from(JSON.stringify({ s: row.sentAt.toISOString(), i: row.id })).toString('base64url');
}

/** Buzilgan / begona kursor -> `null` (servis VALIDATION beradi). */
export function decodeCursor(raw: string): FeedCursor | null {
  try {
    const parsed: unknown = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
    if (!parsed || typeof parsed !== 'object') return null;
    const { s, i } = parsed as { s?: unknown; i?: unknown };
    if (typeof s !== 'string' || typeof i !== 'string' || i.length === 0 || i.length > 64) return null;
    const sentAt = new Date(s);
    return Number.isNaN(sentAt.getTime()) ? null : { sentAt, id: i };
  } catch {
    return null;
  }
}

/** Kursordan keyingi (sentAt, id) bo'yicha kamayuvchi tartibdagi qatorlar sharti. */
export function afterCursorWhere(cursor: FeedCursor): Prisma.SchoolAnnouncementWhereInput {
  return {
    OR: [{ sentAt: { lt: cursor.sentAt } }, { sentAt: cursor.sentAt, id: { lt: cursor.id } }],
  };
}
