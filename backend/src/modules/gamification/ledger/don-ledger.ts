// DON daftari (ledger): tur xaritasi va kursor — sof funksiyalar (DB'siz).

import { Prisma, XpEventType } from '@prisma/client';

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
/** Server yozgan kursor: qat'iy ISO (4 xonali yil, millisekund, `Z`) — kengaytirilgan yillar (`+275760-`) rad etiladi. */
const CURSOR_TIME = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;
/** XpEvent.id — UUID (NUL va boshqa begona belgilar Postgres'ga yetib bormaydi). */
const CURSOR_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
/** Daftar bu yildan oldingi yozuvga ega bo'lolmaydi (Postgres'da 0000 yil yo'q). */
const MIN_CURSOR_YEAR = 2000;

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
    if (!CURSOR_TIME.test(t) || !CURSOR_ID.test(i)) return null;
    const at = new Date(t);
    if (Number.isNaN(at.getTime()) || at.toISOString() !== t) return null;
    if (at.getUTCFullYear() < MIN_CURSOR_YEAR) return null;
    return { at, id: i };
  } catch {
    return null;
  }
}

/** Prisma kursor qiymatini aylantira olmadi (so'rov xatosi, serverniki emas) — 400 ga o'tkaziladi. */
const CONVERSION_ERROR_CODES: ReadonlySet<string> = new Set(['P2023', 'P2020']);

export function isCursorConversionError(error: unknown): boolean {
  return (
    error instanceof Prisma.PrismaClientValidationError ||
    (error instanceof Prisma.PrismaClientKnownRequestError && CONVERSION_ERROR_CODES.has(error.code))
  );
}
