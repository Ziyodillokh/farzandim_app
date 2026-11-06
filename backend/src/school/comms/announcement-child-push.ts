// Maktab e'loni -> bolalarga push: kim oladi va push matni — sof mantiq (DB'siz).
// Bola faqat o'z maktabi / HOZIRGI sinfiga yuborilgan VA xodim "o'quvchilarga ham" belgilagan e'lonni ko'radi
// (`childVisibleWhere` bilan bir xil qoida); push ham aynan shu bolalarga ketadi — ilovasi ulangan o'quvchilarga xolos.

import { Prisma } from '@prisma/client';
import type { PushPayload } from '../../common/fcm/fcm.service';
import { NotifLang, tr } from '../../common/i18n/notification-i18n';
import type { Audience } from './comms.schemas';

/** `child_push_dedupe.kind` — kalit: e'lon id. */
export const SCHOOL_ANNOUNCEMENT_DEDUPE_KIND = 'SCHOOL_ANNOUNCEMENT';
export const SCHOOL_ANNOUNCEMENT_PUSH_TYPE = 'SCHOOL_ANNOUNCEMENT';

/**
 * E'longa tushadigan o'quvchilar sharti; `null` — bolalarga umuman yuborilmaydi (`includeStudents` yo'q,
 * vasiylar auditoriyasi yoki sinflar ro'yxati bo'sh). Faqat arxivlanmagan, sinfi bor, bola ilovasi ulangan o'quvchilar.
 */
export function childRecipientsWhere(schoolId: string, audience: Audience): Prisma.SchoolStudentWhereInput | null {
  if (!audience.includeStudents || audience.kind === 'GUARDIANS') return null;
  if (audience.kind === 'CLASSES' && audience.classIds.length === 0) return null;
  return {
    schoolId,
    archived: false,
    classId: audience.kind === 'CLASSES' ? { in: [...audience.classIds] } : { not: null },
    childId: { not: null },
    child: { childUserId: { not: null } },
    school: { status: 'ACTIVE' },
  };
}

export interface RecipientRow {
  childId: string | null;
  child: {
    childUserId: string | null;
    notificationPreference: { schoolAnnouncements: boolean } | null;
  } | null;
}

export interface ChildRecipient {
  childId: string;
  childUserId: string;
}

/** Sozlamasi "maktab e'lonlari" ni o'chirmagan bolalar (yozuv yo'q — standart: yoqilgan). Takrorlar olib tashlanadi. */
export function selectRecipients(rows: readonly RecipientRow[]): ChildRecipient[] {
  const seen = new Set<string>();
  const result: ChildRecipient[] = [];
  for (const row of rows) {
    const childUserId = row.child?.childUserId;
    if (!row.childId || !childUserId || seen.has(row.childId)) continue;
    if (row.child?.notificationPreference?.schoolAnnouncements === false) continue;
    seen.add(row.childId);
    result.push({ childId: row.childId, childUserId });
  }
  return result;
}

/**
 * Bolaga e'lon push'i HAR DOIM neytral: "Parvoz" / "Maktabdan yangi eʼlon" — e'lon sarlavhasi, matni va maktab nomisiz
 * (`hideText` hozircha e'tiborga olinmaydi: lock-screen'da maktab xabari ko'rinmasin). Mazmun ilova ichida, e'lonlar lentasida.
 */
export function announcementChildPush(lang: NotifLang, a: { id: string }): PushPayload {
  return {
    title: tr(lang, 'push.neutralTitle'),
    body: tr(lang, 'schoolAnnouncement.hiddenBody'),
    data: { type: SCHOOL_ANNOUNCEMENT_PUSH_TYPE, id: a.id },
  };
}
