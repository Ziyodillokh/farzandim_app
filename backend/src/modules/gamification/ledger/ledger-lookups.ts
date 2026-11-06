// Daftar elementlarini boyitish: fan / sarlavha. Sahifadagi barcha id'lar uchun
// har manbaga BITTA so'rov (N+1 yo'q). Faqat bolaning o'z urinishlari o'qiladi.

import { XpEventType } from '@prisma/client';
import { PrismaService } from '../../../common/database/prisma.service';
import { toApiSubject } from '../../learning/domain/subjects';
import { baseKindFor, LedgerItem, LedgerKind } from './don-ledger';
import { LedgerEntry } from './ledger-collector';

export interface LedgerLookups {
  /** attemptId → fan kaliti (`math`). */
  subjects: ReadonlyMap<string, string>;
  /** olimpiada id YOKI urinish id → olimpiada sarlavhasi. */
  contests: ReadonlyMap<string, string>;
  /** audiokitob / kitob id → sarlavha. */
  books: ReadonlyMap<string, string>;
  /** video id → sarlavha. */
  videos: ReadonlyMap<string, string>;
}

type Db = Pick<
  PrismaService,
  'learningAttempt' | 'olympiad' | 'olympiadAttempt' | 'audiobook' | 'book' | 'video'
>;

const relatedIds = (entries: readonly LedgerEntry[], kind: LedgerKind): string[] => [
  ...new Set(
    entries.flatMap((e) =>
      !e.isSteps && baseKindFor(e.row.type) === kind && e.row.relatedId ? [e.row.relatedId] : [],
    ),
  ),
];

/** Video tugatish `OTHER` turi bilan yoziladi (boshqa turlar VIDEO bo'lmaydi). */
const isVideoCandidate = (e: LedgerEntry): boolean =>
  !e.isSteps && e.row.type === XpEventType.OTHER && e.row.relatedId !== null;

const byId = <T extends { id: string }>(rows: readonly T[], value: (row: T) => string) =>
  new Map(rows.map((r) => [r.id, value(r)] as const));

export async function loadLedgerLookups(
  db: Db,
  childId: string,
  entries: readonly LedgerEntry[],
): Promise<LedgerLookups> {
  const attemptIds = relatedIds(entries, 'LEARNING');
  const contestIds = relatedIds(entries, 'OLYMPIAD');
  const bookIds = relatedIds(entries, 'BOOK');
  const videoIds = [
    ...new Set(entries.filter(isVideoCandidate).map((e) => e.row.relatedId as string)),
  ];
  const idsIn = (ids: string[]) => ({ id: { in: ids } });

  const [attempts, olympiads, contestAttempts, audiobooks, books, videos] = await Promise.all([
    attemptIds.length
      ? db.learningAttempt.findMany({
          where: { ...idsIn(attemptIds), childId },
          select: { id: true, subject: true },
        })
      : [],
    contestIds.length
      ? db.olympiad.findMany({ where: idsIn(contestIds), select: { id: true, title: true } })
      : [],
    contestIds.length
      ? db.olympiadAttempt.findMany({
          where: { ...idsIn(contestIds), childId },
          select: { id: true, olympiad: { select: { title: true } } },
        })
      : [],
    bookIds.length
      ? db.audiobook.findMany({ where: idsIn(bookIds), select: { id: true, title: true } })
      : [],
    bookIds.length
      ? db.book.findMany({ where: idsIn(bookIds), select: { id: true, title: true } })
      : [],
    videoIds.length
      ? db.video.findMany({ where: idsIn(videoIds), select: { id: true, title: true } })
      : [],
  ]);

  return {
    subjects: byId(attempts, (a) => toApiSubject(a.subject)),
    contests: new Map([
      ...byId(olympiads, (o) => o.title),
      ...byId(contestAttempts, (a) => a.olympiad.title),
    ]),
    // Audiokitob birinchi (kitob o'qish mukofoti audiokitob tugatganda yoziladi).
    books: new Map([...byId(books, (b) => b.title), ...byId(audiobooks, (b) => b.title)]),
    videos: byId(videos, (v) => v.title),
  };
}

/** Bitta element: tur, fan, sarlavha (topilmasa `null`). */
export function resolveEntry(entry: LedgerEntry, lookups: LedgerLookups): LedgerItem {
  const { row } = entry;
  const related = row.relatedId;
  const base: LedgerItem = {
    id: entry.id,
    kind: entry.isSteps ? 'STEPS' : baseKindFor(row.type),
    amount: entry.amount,
    status: 'CONFIRMED',
    at: row.createdAt.toISOString(),
    subject: null,
    title: null,
    relatedId: entry.isSteps ? null : related,
  };
  if (entry.isSteps || !related) return base;

  switch (base.kind) {
    case 'LEARNING':
      return { ...base, subject: lookups.subjects.get(related) ?? null };
    case 'OLYMPIAD':
      return { ...base, title: lookups.contests.get(related) ?? null };
    case 'BOOK':
      return { ...base, title: lookups.books.get(related) ?? null };
    default: {
      const video = row.type === XpEventType.OTHER ? lookups.videos.get(related) : undefined;
      return video === undefined ? base : { ...base, kind: 'VIDEO', title: video };
    }
  }
}
