// Yozishma ko'rinishlari — ota-ona va xodim tomonlari uchun umumiy. Matn faqat
// shu yerda (javob qurishda) ochiladi; logga hech qachon yozilmaydi.

import { HttpException, HttpStatus } from '@nestjs/common';
import { Prisma, SchoolParentMessage, SchoolParentThread } from '@prisma/client';
import type { SchoolCryptoService } from '../common/school-crypto.service';
import { snippet } from './parent-contacts';
import { THREAD_MESSAGES_LIMIT } from './parent-connect.schemas';

type Db = Pick<Prisma.TransactionClient, 'schoolParentMessage'>;

export type Author = 'PARENT' | 'STAFF';

/** Kunlik chegara oshdi — 429 (ota-ona ilovasi `RATE_LIMITED` ni taniydi). */
export const rateLimited = (what: string) =>
  new HttpException({ code: 'RATE_LIMITED', message: what }, HttpStatus.TOO_MANY_REQUESTS);

export const studentLabel = (s: { lastName: string; firstName: string }) => `${s.lastName} ${s.firstName}`;

/** Har yozishmaning oxirgi xabari (oldindan ko'rish uchun). */
export async function lastMessages(db: Db, threadIds: readonly string[]): Promise<Map<string, SchoolParentMessage>> {
  if (threadIds.length === 0) return new Map();
  const rows = await db.schoolParentMessage.findMany({
    where: { threadId: { in: [...threadIds] } },
    orderBy: [{ threadId: 'asc' }, { createdAt: 'desc' }, { id: 'desc' }],
    distinct: ['threadId'],
  });
  return new Map(rows.map((m) => [m.threadId, m]));
}

/** Yozishma xabarlari (eng yangi `THREAD_MESSAGES_LIMIT` tasi, eskisi oldin). */
export async function threadMessages(db: Db, threadId: string): Promise<SchoolParentMessage[]> {
  const rows = await db.schoolParentMessage.findMany({
    where: { threadId },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: THREAD_MESSAGES_LIMIT,
  });
  return rows.reverse();
}

export function previewOf(crypto: SchoolCryptoService, m: SchoolParentMessage | undefined) {
  if (!m) return null;
  return { author: m.author as Author, text: snippet(crypto.decrypt(m.bodyEnc)), at: m.createdAt.toISOString() };
}

/**
 * Xabar ko'rinishi. `seen` — qarshi tomon o'qiganmi (ota-ona xabari uchun xodimning,
 * xodim xabari uchun ota-onaning `readAt`i shu xabardan keyin).
 */
export function messageView(crypto: SchoolCryptoService, m: SchoolParentMessage, thread: Pick<SchoolParentThread, 'parentReadAt' | 'staffReadAt'>) {
  const otherReadAt = m.author === 'PARENT' ? thread.staffReadAt : thread.parentReadAt;
  return {
    id: m.id,
    author: m.author as Author,
    topic: m.topic,
    body: crypto.decrypt(m.bodyEnc),
    createdAt: m.createdAt.toISOString(),
    seen: Boolean(otherReadAt && otherReadAt >= m.createdAt),
  };
}
