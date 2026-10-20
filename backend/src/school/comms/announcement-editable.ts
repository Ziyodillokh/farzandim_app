// Hali yuborilmagan e'lon ustidagi amallar uchun umumiy tekshiruvlar
// (panel `editable`): yo'q → 404, yuborilgan → 409, begona → 403, auditoriya
// doiradan tashqari → 403. Yozuv SHARTLI (`status != SENT`) — parallel cron
// yuborib qo'ygan bo'lsa, o'zgartirish 409 bilan rad etiladi.

import { Prisma, SchoolAnnouncement } from '@prisma/client';
import { SchoolActor } from '../auth/school-actor';
import { conflict, forbidden, invalid, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { isOwnOrSchool } from './announcement-views';
import { AnnouncementInput, sendOptionsSchema } from './comms.schemas';
import { assertAudienceAllowed, Roster, toAudience } from './comms-roster';
import { parseLocalDateTime } from './comms-time';

type Tx = Prisma.TransactionClient;

export async function findEditable(tx: Tx, actor: SchoolActor, roster: Roster, id: string): Promise<SchoolAnnouncement> {
  const current = await tx.schoolAnnouncement.findFirst({ where: { id, schoolId: actor.schoolId } });
  if (!current) throw notFound(id);
  if (current.status === 'SENT') throw conflict('already sent');
  if (!isOwnOrSchool(actor, current)) throw forbidden(id);
  assertAudienceAllowed(actor, roster, toAudience(current.audience));
  return current;
}

/** Rejalashtirish vaqti (`scheduledAt`): bo'sh — darhol; noto'g'ri yoki o'tgan — VALIDATION. */
export function parseSchedule(body: unknown, now: Date): Date | null {
  const { scheduledAt } = parseOrThrow(sendOptionsSchema, body ?? {});
  if (!scheduledAt) return null;
  const at = parseLocalDateTime(scheduledAt);
  if (!at || at.getTime() <= now.getTime()) throw invalid('scheduledAt: errors.form.invalidDate');
  return at;
}

/** Forma mazmuni → baza maydonlari. */
export function contentData(data: AnnouncementInput) {
  return {
    title: data.title,
    body: data.body,
    priority: data.priority,
    audience: data.audience as unknown as Prisma.InputJsonValue,
  };
}

/** Faqat hali yuborilmagan bo'lsa yangilash; aks holda 409. */
export async function updateUnsent(
  tx: Tx,
  id: string,
  schoolId: string,
  data: Prisma.SchoolAnnouncementUpdateManyMutationInput,
): Promise<SchoolAnnouncement> {
  const res = await tx.schoolAnnouncement.updateMany({ where: { id, schoolId, status: { not: 'SENT' } }, data });
  if (res.count !== 1) throw conflict('already sent');
  return tx.schoolAnnouncement.findUniqueOrThrow({ where: { id } });
}
