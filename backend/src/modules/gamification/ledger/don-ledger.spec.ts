import { XpEventType } from '@prisma/client';
import { baseKindFor, decodeLedgerCursor, encodeLedgerCursor, stepsItemId } from './don-ledger';
import { loadLedgerLookups, LedgerLookups, resolveEntry } from './ledger-lookups';
import { LedgerEntry, LedgerRow } from './ledger-collector';

describe('baseKindFor', () => {
  it.each([
    [XpEventType.DAILY_LEARNING, 'LEARNING'],
    [XpEventType.DAILY_GOAL, 'STEPS'],
    [XpEventType.CONTEST_JOIN, 'OLYMPIAD'],
    [XpEventType.CONTEST_WIN, 'OLYMPIAD'],
    [XpEventType.BOOK_READ, 'BOOK'],
    [XpEventType.OTHER, 'OTHER'],
    [XpEventType.CREATIVE_JOIN, 'OTHER'],
    [XpEventType.CREATIVE_WIN, 'OTHER'],
    [XpEventType.COURSE_LESSON, 'OTHER'],
    [XpEventType.STREAK_WEEKLY, 'OTHER'],
    [XpEventType.CONTENT_POST, 'OTHER'],
  ] as const)('%s → %s', (type, kind) => {
    expect(baseKindFor(type)).toBe(kind);
  });

  it('qadam kuni id\'si', () => {
    expect(stepsItemId('2026-11-05')).toBe('steps:2026-11-05');
  });
});

describe('ledger cursor', () => {
  const position = { at: new Date('2026-11-05T09:12:00.123Z'), id: 'row-1' };

  it('kodlash → dekodlash aylanishi (millisekundgacha)', () => {
    expect(decodeLedgerCursor(encodeLedgerCursor(position))).toEqual(position);
  });

  it.each([
    ['bo\'sh', ''],
    ['base64 emas', '%%%'],
    ['JSON emas', Buffer.from('nope').toString('base64url')],
    ['maydonlar yo\'q', Buffer.from('{}').toString('base64url')],
    ['sana buzuq', Buffer.from('{"t":"yaqinda","i":"x"}').toString('base64url')],
    ['sana ISO emas', Buffer.from('{"t":"2026-11-05","i":"x"}').toString('base64url')],
    ['id bo\'sh', Buffer.from('{"t":"2026-11-05T09:12:00.000Z","i":""}').toString('base64url')],
    ['id son', Buffer.from('{"t":"2026-11-05T09:12:00.000Z","i":5}').toString('base64url')],
    ['juda uzun', 'a'.repeat(201)],
  ])('buzilgan kursor (%s) — null', (_name, raw) => {
    expect(decodeLedgerCursor(raw)).toBeNull();
  });
});

describe('resolveEntry', () => {
  const lookups: LedgerLookups = {
    subjects: new Map([['att-1', 'math']]),
    contests: new Map([['oly-1', 'Bahor olimpiadasi']]),
    books: new Map([['book-1', 'Alisher Navoiy']]),
    videos: new Map([['vid-1', 'Quyosh tizimi']]),
  };
  const entry = (over: Partial<LedgerRow>, extra: Partial<LedgerEntry> = {}): LedgerEntry => {
    const row: LedgerRow = {
      id: 'r1',
      type: XpEventType.OTHER,
      donDelta: 5,
      relatedId: null,
      createdAt: new Date('2026-11-05T09:12:00.000Z'),
      ...over,
    };
    return { id: row.id, row, amount: row.donDelta, isSteps: false, ...extra };
  };

  it('LEARNING: fan kaliti va attemptId', () => {
    expect(resolveEntry(entry({ type: XpEventType.DAILY_LEARNING, donDelta: 16, relatedId: 'att-1' }), lookups)).toEqual({
      id: 'r1',
      kind: 'LEARNING',
      amount: 16,
      status: 'CONFIRMED',
      at: '2026-11-05T09:12:00.000Z',
      subject: 'math',
      title: null,
      relatedId: 'att-1',
    });
  });

  it('OLYMPIAD: sarlavha topilsa; topilmasa null', () => {
    expect(resolveEntry(entry({ type: XpEventType.CONTEST_JOIN, relatedId: 'oly-1' }), lookups).title).toBe(
      'Bahor olimpiadasi',
    );
    const missing = resolveEntry(entry({ type: XpEventType.CONTEST_WIN, relatedId: 'gone' }), lookups);
    expect(missing).toMatchObject({ kind: 'OLYMPIAD', title: null, relatedId: 'gone' });
  });

  it('BOOK: sarlavha', () => {
    expect(resolveEntry(entry({ type: XpEventType.BOOK_READ, relatedId: 'book-1' }), lookups)).toMatchObject({
      kind: 'BOOK',
      title: 'Alisher Navoiy',
    });
  });

  it('OTHER + video id → VIDEO; video emas → OTHER', () => {
    expect(resolveEntry(entry({ relatedId: 'vid-1' }), lookups)).toMatchObject({
      kind: 'VIDEO',
      title: 'Quyosh tizimi',
    });
    expect(resolveEntry(entry({ relatedId: 'something' }), lookups)).toMatchObject({ kind: 'OTHER', title: null });
    expect(resolveEntry(entry({ relatedId: null }), lookups)).toMatchObject({ kind: 'OTHER', title: null });
  });

  it('video id\'si OTHER bo\'lmagan turda VIDEO qilinmaydi', () => {
    expect(resolveEntry(entry({ type: XpEventType.CREATIVE_JOIN, relatedId: 'vid-1' }), lookups).kind).toBe('OTHER');
  });

  it('STEPS: guruh id\'si, relatedId yo\'q', () => {
    const item = resolveEntry(
      entry({ type: XpEventType.DAILY_GOAL, relatedId: 'ignored' }, { id: 'steps:2026-11-05', amount: 25, isSteps: true }),
      lookups,
    );
    expect(item).toMatchObject({ id: 'steps:2026-11-05', kind: 'STEPS', amount: 25, relatedId: null, subject: null });
  });
});

describe('loadLedgerLookups', () => {
  it('bo\'sh sahifa — hech qanday so\'rov yo\'q', async () => {
    const fail = jest.fn();
    const db = {
      learningAttempt: { findMany: fail },
      olympiad: { findMany: fail },
      olympiadAttempt: { findMany: fail },
      audiobook: { findMany: fail },
      book: { findMany: fail },
      video: { findMany: fail },
    };
    const lookups = await loadLedgerLookups(db as never, 'c1', []);
    expect(fail).not.toHaveBeenCalled();
    expect(lookups.subjects.size + lookups.contests.size + lookups.books.size + lookups.videos.size).toBe(0);
  });

  it('urinishlar faqat shu bolaning id\'si bilan so\'raladi (boshqa bola ma\'lumoti oqmaydi)', async () => {
    const attempts = jest.fn().mockResolvedValue([]);
    const contestAttempts = jest.fn().mockResolvedValue([]);
    const db = {
      learningAttempt: { findMany: attempts },
      olympiad: { findMany: jest.fn().mockResolvedValue([]) },
      olympiadAttempt: { findMany: contestAttempts },
      audiobook: { findMany: jest.fn() },
      book: { findMany: jest.fn() },
      video: { findMany: jest.fn() },
    };
    const row = (type: XpEventType, relatedId: string): LedgerEntry => ({
      id: relatedId,
      amount: 1,
      isSteps: false,
      row: { id: relatedId, type, donDelta: 1, relatedId, createdAt: new Date() },
    });
    await loadLedgerLookups(db as never, 'child-9', [
      row(XpEventType.DAILY_LEARNING, 'a1'),
      row(XpEventType.CONTEST_WIN, 'a2'),
    ]);
    expect(attempts).toHaveBeenCalledWith(expect.objectContaining({ where: { id: { in: ['a1'] }, childId: 'child-9' } }));
    expect(contestAttempts).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: { in: ['a2'] }, childId: 'child-9' } }),
    );
  });
});
