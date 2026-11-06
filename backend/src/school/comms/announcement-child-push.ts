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
/** Yashirilmagan push'da e'lon sarlavhasi shuncha belgigacha ("…" bilan, jami ≤ 80). */
export const ANNOUNCEMENT_PUSH_TITLE_MAX = 80;

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
    notificationPreference: { schoolAnnouncements: boolean; hideText: boolean } | null;
  } | null;
}

export interface ChildRecipient {
  childId: string;
  childUserId: string;
  hideText: boolean;
}

/** Sozlamasi "maktab e'lonlari" ni o'chirmagan bolalar (yozuv yo'q — standart: yoqilgan, matn yashirin). Takrorlar olib tashlanadi. */
export function selectRecipients(rows: readonly RecipientRow[]): ChildRecipient[] {
  const seen = new Set<string>();
  const result: ChildRecipient[] = [];
  for (const row of rows) {
    const childUserId = row.child?.childUserId;
    if (!row.childId || !childUserId || seen.has(row.childId)) continue;
    const pref = row.child?.notificationPreference;
    if (pref && !pref.schoolAnnouncements) continue;
    seen.add(row.childId);
    result.push({ childId: row.childId, childUserId, hideText: pref?.hideText ?? true });
  }
  return result;
}

/** Kod nuqtalari bo'yicha qisqartirish (emoji o'rtasidan kesilmaydi); natija `max` belgidan oshmaydi. */
export function truncateTitle(title: string, max = ANNOUNCEMENT_PUSH_TITLE_MAX): string {
  const chars = [...title.replace(/\s+/g, ' ').trim()];
  return chars.length <= max ? chars.join('') : `${chars.slice(0, max - 1).join('').trimEnd()}…`;
}

/** `hideText` — "Parvoz" / "Maktabdan yangi eʼlon"; aks holda sarlavha: maktab nomi, matn: e'lon sarlavhasi (≤ 80). */
export function announcementChildPush(
  lang: NotifLang,
  a: { id: string; school: string; title: string; hideText: boolean },
): PushPayload {
  const data = { type: SCHOOL_ANNOUNCEMENT_PUSH_TYPE, id: a.id };
  if (a.hideText) {
    return { title: tr(lang, 'push.neutralTitle'), body: tr(lang, 'schoolAnnouncement.hiddenBody'), data };
  }
  return { title: a.school || tr(lang, 'push.neutralTitle'), body: truncateTitle(a.title), data };
}
