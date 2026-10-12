import type { NotificationItem } from '@/data/contracts';
import { toIsoDate } from '@/data/mock/calendar';

/**
 * "O'qildi" holati — brauzer sozlamalarida `notif:<staffId>` kaliti ostida.
 * `seenAt` — shu vaqtgacha bo'lgan hammasi o'qilgan ("Hammasini o'qildi");
 * `read` — alohida o'qilganlar, `id@at` (ko'pi bilan 300 ta). Demo soati epoch'i
 * o'zgarsa (ertalab qayta boshlandi — vaqt orqaga ketdi) `seenAt` tashlanadi.
 */
export type ReadState = { epoch: number; seenAt: string | null; read: string[] };

export const READ_CAP = 300;

export function readStateKey(staffId: string): string {
  return `notif:${staffId}`;
}

export function emptyReadState(epoch: number): ReadState {
  return { epoch, seenAt: null, read: [] };
}

/** Saqlangan qiymatni tekshiradi; epoch boshqa bo'lsa `seenAt` tashlanadi, `read` qoladi. */
export function normalizeReadState(raw: unknown, epoch: number): ReadState {
  if (!raw || typeof raw !== 'object') return emptyReadState(epoch);
  const v = raw as Partial<ReadState>;
  const read = Array.isArray(v.read) ? v.read.filter((x): x is string => typeof x === 'string').slice(-READ_CAP) : [];
  const seenAt = typeof v.seenAt === 'string' && v.epoch === epoch ? v.seenAt : null;
  return { epoch, seenAt, read };
}

function atMs(value: string | null): number {
  return value ? Date.parse(value) : Number.NaN;
}

type ReadableItem = Pick<NotificationItem, 'id' | 'at'>;

/**
 * O'qilganlik kaliti: id + vaqt. Joyida yangilanadigan bildirishnoma (masalan,
 * "test yakunlandi" — shu tayinlash bo'yicha yangi natijalar) yana o'qilmagan bo'ladi.
 */
export function readKey(item: ReadableItem): string {
  return `${item.id}@${item.at}`;
}

/**
 * O'qilmagan: alohida o'qilmagan va `seenAt` dan oldin emas. `seenAt` bilan bir
 * soniyadagi yangi hodisa ham o'qilmagan ("Hammasini o'qildi" paytidagilar `read` da).
 */
export function isUnread(item: ReadableItem, state: ReadState): boolean {
  if (state.read.includes(readKey(item))) return false;
  const seen = atMs(state.seenAt);
  const at = atMs(item.at);
  return Number.isNaN(seen) || Number.isNaN(at) || at >= seen;
}

export function unreadCount(items: readonly ReadableItem[], state: ReadState): number {
  return items.filter((item) => isUnread(item, state)).length;
}

function withRead(read: readonly string[], keys: readonly string[]): string[] {
  const added = new Set(keys);
  return [...read.filter((x) => !added.has(x)), ...keys].slice(-READ_CAP);
}

export function markRead(state: ReadState, item: ReadableItem): ReadState {
  return { ...state, read: withRead(state.read, [readKey(item)]) };
}

/** Hammasi: `seenAt` = hozir va ko'rinayotganlar (kelajak vaqtli ochiq so'rovlar ham) o'qilgan. */
export function markAllRead(state: ReadState, items: readonly ReadableItem[], nowIso: string): ReadState {
  return { ...state, seenAt: nowIso, read: withRead(state.read, items.map(readKey)) };
}

/** "Bugun" / "Oldinroq" guruhlari (demo soati kuni bo'yicha), tartib saqlanadi. */
export function groupByDay<T extends Pick<NotificationItem, 'at'>>(items: readonly T[], today: string): { today: T[]; earlier: T[] } {
  const isToday = (item: T) => {
    const d = new Date(item.at);
    return !Number.isNaN(d.getTime()) && toIsoDate(d) === today;
  };
  return { today: items.filter(isToday), earlier: items.filter((i) => !isToday(i)) };
}
