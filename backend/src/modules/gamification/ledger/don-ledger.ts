// DON daftari (ledger): tur xaritasi va kursor — sof funksiyalar (DB'siz).

import { XpEventType } from '@prisma/client';

export type LedgerKind = 'LEARNING' | 'STEPS' | 'OLYMPIAD' | 'BOOK' | 'VIDEO' | 'OTHER';

export interface LedgerItem {
  id: string;
  kind: LedgerKind;
  amount: number;
  /** Hozircha doim CONFIRMED (kutilayotgan DON qoidalari qarori uchun zaxira). */
  status: 'CONFIRMED';
  at: string;
  subject: string | null;
  title: string | null;
  relatedId: string | null;
}

/**
 * Ledger yozuvining turi. Video tugatish `OTHER` bilan yoziladi — uni
 * `relatedId` videoga mos kelishi bilan ajratadi chaqiruvchi (`VIDEO`).
 */
export function baseKindFor(type: XpEventType): LedgerKind {
  switch (type) {
    case XpEventType.DAILY_LEARNING:
      return 'LEARNING';
    case XpEventType.DAILY_GOAL:
      return 'STEPS';
    case XpEventType.CONTEST_JOIN:
    case XpEventType.CONTEST_WIN:
      return 'OLYMPIAD';
    case XpEventType.BOOK_READ:
      return 'BOOK';
    default:
      return 'OTHER';
  }
}

/** Qadam kuni guruhi elementi id'si (`steps:YYYY-MM-DD`, Toshkent kuni). */
export const stepsItemId = (day: string): string => `steps:${day}`;

/**
 * Sahifa o'rni: oxirgi elementning "langar" qatori (`createdAt`, `id`). Tartib —
 * (createdAt, id) kamayish. Qadam guruhining langari — shu kunning ENG SO'NGGI qadam qatori.
 */
export interface LedgerPosition {
  at: Date;
  id: string;
}

const MAX_CURSOR_LENGTH = 200;
const MAX_ID_LENGTH = 64;

export function encodeLedgerCursor(position: LedgerPosition): string {
  return Buffer.from(JSON.stringify({ t: position.at.toISOString(), i: position.id })).toString(
    'base64url',
  );
}

/** Buzilgan / begona kursor — `null`. */
export function decodeLedgerCursor(raw: string): LedgerPosition | null {
  if (raw.length === 0 || raw.length > MAX_CURSOR_LENGTH) return null;
  try {
    const parsed: unknown = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
    if (!parsed || typeof parsed !== 'object') return null;
    const { t, i } = parsed as { t?: unknown; i?: unknown };
    if (typeof t !== 'string' || typeof i !== 'string') return null;
    if (i.length === 0 || i.length > MAX_ID_LENGTH) return null;
    const at = new Date(t);
    if (Number.isNaN(at.getTime()) || at.toISOString() !== t) return null;
    return { at, id: i };
  } catch {
    return null;
  }
}
