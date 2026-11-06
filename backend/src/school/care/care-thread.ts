// Murojaat yozishmasi (bola <-> xodim): bosqich, xabar ko'rinishi va eski
// (xabarsiz) murojaatlar uchun sintetik boshlang'ich xabar — sof funksiyalar.
// Ichki eslatmalar (`notesEnc`) bu yerga HECH QACHON kirmaydi.

import { SchoolCareMessage, SchoolCareRequest } from '@prisma/client';

export type CareStage = 'RECEIVED' | 'OPENED' | 'REPLIED' | 'CLOSED';
export type MessageAuthor = 'CHILD' | 'STAFF';

/** Eski murojaatlar (xabarlar jadvalidan oldingi) uchun sintetik boshlang'ich xabar id'si. */
export const INITIAL_MESSAGE_ID = 'initial';

export interface ThreadMessage {
  id: string;
  author: MessageAuthor;
  authorName: string | null;
  text: string;
  createdAt: string;
}

type StageSource = Pick<SchoolCareRequest, 'status' | 'openedAt' | 'repliedAt'>;

/**
 * RECEIVED (hali ochilmagan) → OPENED (ochilgan, xodim xabari yo'q) → REPLIED (kamida bitta xodim
 * xabari) → CLOSED (hal qilingan). Xodim holatni (`NEW` dan boshqa) o'zgartirgan eski murojaat
 * `openedAt`siz ham ochilgan hisoblanadi.
 */
export function stageOf(r: StageSource): CareStage {
  if (r.status === 'RESOLVED') return 'CLOSED';
  if (r.repliedAt) return 'REPLIED';
  if (r.openedAt || r.status !== 'NEW') return 'OPENED';
  return 'RECEIVED';
}

export type MessageRow = Pick<SchoolCareMessage, 'id' | 'author' | 'staffId' | 'bodyEnc' | 'createdAt'>;

export interface ThreadDeps {
  decrypt: (token: string) => string;
  /** Xodim → ko'rsatiladigan ism (bola tomonda — ko'rsatiladigan ism, xodim tomonda — F.I.Sh.). */
  nameOf: (staffId: string | null) => string | null;
}

export function toMessageView(m: MessageRow, deps: ThreadDeps): ThreadMessage {
  const author: MessageAuthor = m.author === 'STAFF' ? 'STAFF' : 'CHILD';
  return {
    id: m.id,
    author,
    authorName: author === 'STAFF' ? deps.nameOf(m.staffId) : null,
    text: deps.decrypt(m.bodyEnc),
    createdAt: m.createdAt.toISOString(),
  };
}

/** Xabarlar (eskidan yangiga). Xabari yo'q eski murojaat — `messageEnc`dan sintetik bitta xabar. */
export function threadOf(
  request: Pick<SchoolCareRequest, 'messageEnc' | 'createdAt'>,
  rows: readonly MessageRow[],
  deps: ThreadDeps,
): ThreadMessage[] {
  if (rows.length === 0) {
    return [{ id: INITIAL_MESSAGE_ID, author: 'CHILD', authorName: null, text: deps.decrypt(request.messageEnc), createdAt: request.createdAt.toISOString() }];
  }
  return [...rows]
    .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime() || a.id.localeCompare(b.id))
    .map((m) => toMessageView(m, deps));
}
