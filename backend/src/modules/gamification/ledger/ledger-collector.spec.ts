import { XpEventType } from '@prisma/client';
import { LedgerPosition } from './don-ledger';
import {
  collectLedgerEntries,
  entriesFromRows,
  LedgerRow,
  LedgerSource,
  StepDayStat,
} from './ledger-collector';
import { tashkentDay } from '../../../common/time/tashkent';

const T = XpEventType;
let counter = 0;
const row = (type: XpEventType, iso: string, donDelta: number, id?: string): LedgerRow => ({
  id: id ?? `r${String(++counter).padStart(3, '0')}`,
  type,
  donDelta,
  relatedId: null,
  createdAt: new Date(iso),
});

/** Xotiradagi manba: prod so'rovlari bilan bir xil tartib va mantiq. */
function memorySource(all: readonly LedgerRow[]): LedgerSource & { calls: number } {
  const sorted = [...all]
    .filter((r) => r.donDelta !== 0)
    .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime() || (a.id < b.id ? 1 : -1));
  const source = {
    calls: 0,
    async rowsBefore(position: LedgerPosition | null, take: number) {
      source.calls++;
      const below = position
        ? sorted.filter(
            (r) =>
              r.createdAt.getTime() < position.at.getTime() ||
              (r.createdAt.getTime() === position.at.getTime() && r.id < position.id),
          )
        : sorted;
      return below.slice(0, take);
    },
    async stepDays(days: readonly string[]) {
      const out = new Map<string, StepDayStat>();
      for (const day of days) {
        const rows = sorted.filter((r) => r.type === T.DAILY_GOAL && tashkentDay(r.createdAt) === day);
        if (rows.length === 0) continue;
        out.set(day, { amount: rows.reduce((s, r) => s + r.donDelta, 0), anchorId: rows[0].id });
      }
      return out;
    },
  };
  return source;
}

/** Barcha sahifalarni kursor bilan yurib chiqadi. */
async function paginate(source: LedgerSource, limit: number) {
  const pages: string[][] = [];
  let after: LedgerPosition | null = null;
  for (let guard = 0; guard < 100; guard++) {
    const found = await collectLedgerEntries(source, after, limit + 1);
    const page = found.slice(0, limit);
    pages.push(page.map((e) => e.id));
    if (found.length <= limit) return pages;
    const last = page[page.length - 1].row;
    after = { at: last.createdAt, id: last.id };
  }
  throw new Error('kursor tugamadi');
}

describe('entriesFromRows (qadam kunlari guruhi)', () => {
  it('qadam qatorlari bitta elementga: yig\'indi, id=steps:KUN, at=oxirgi qator', () => {
    const a = row(T.DAILY_GOAL, '2026-11-05T05:00:00.000Z', 5);
    const b = row(T.DAILY_GOAL, '2026-11-05T10:00:00.000Z', 10);
    const c = row(T.DAILY_GOAL, '2026-11-05T12:00:00.000Z', 5);
    const stats = new Map([['2026-11-05', { amount: 20, anchorId: c.id }]]);
    const entries = entriesFromRows([c, b, a], stats);
    expect(entries).toHaveLength(1);
    expect(entries[0]).toMatchObject({ id: 'steps:2026-11-05', amount: 20, isSteps: true });
    expect(entries[0].row.createdAt).toEqual(c.createdAt);
  });

  it('Toshkent kuni chegarasi: UTC 19:00 dan keyin ertangi kun', () => {
    const lateUtc = row(T.DAILY_GOAL, '2026-11-05T19:30:00.000Z', 5); // Toshkent 2026-11-06 00:30
    const earlyUtc = row(T.DAILY_GOAL, '2026-11-05T18:30:00.000Z', 5); // Toshkent 2026-11-05 23:30
    const stats = new Map([
      ['2026-11-06', { amount: 5, anchorId: lateUtc.id }],
      ['2026-11-05', { amount: 5, anchorId: earlyUtc.id }],
    ]);
    expect(entriesFromRows([lateUtc, earlyUtc], stats).map((e) => e.id)).toEqual([
      'steps:2026-11-06',
      'steps:2026-11-05',
    ]);
  });

  it('oddiy yozuvlar o\'zgarmaydi', () => {
    const book = row(T.BOOK_READ, '2026-11-05T09:00:00.000Z', 7);
    expect(entriesFromRows([book], new Map())).toEqual([
      { id: book.id, row: book, amount: 7, isSteps: false },
    ]);
  });
});

describe('collectLedgerEntries — kursor guruhlar bo\'ylab', () => {
  // Qadam kunlari boshqa yozuvlar bilan "aralash": 11-05 kuni qadamlar ertalab va kechqurun,
  // orasida o'qish va kitob. 11-04 kuni qadam bitta.
  const dataset = () => [
    row(T.DAILY_GOAL, '2026-11-05T04:00:00.000Z', 5, 'a-steps-1'),
    row(T.DAILY_LEARNING, '2026-11-05T05:00:00.000Z', 16, 'b-learn'),
    row(T.DAILY_GOAL, '2026-11-05T06:00:00.000Z', 10, 'c-steps-2'),
    row(T.BOOK_READ, '2026-11-05T07:00:00.000Z', 20, 'd-book'),
    row(T.DAILY_GOAL, '2026-11-05T08:00:00.000Z', 5, 'e-steps-3'),
    row(T.CONTEST_JOIN, '2026-11-05T09:00:00.000Z', 5, 'f-join'),
    row(T.DAILY_GOAL, '2026-11-04T08:00:00.000Z', 15, 'g-steps-prev'),
    row(T.OTHER, '2026-11-04T07:00:00.000Z', 3, 'h-video'),
    row(T.OTHER, '2026-11-04T06:00:00.000Z', 0, 'z-zero'), // donDelta = 0 — daftarda yo'q
  ];

  const expectedAll = ['f-join', 'steps:2026-11-05', 'd-book', 'b-learn', 'steps:2026-11-04', 'h-video'];

  it('bitta sahifada: qadam kuni guruhi o\'z langarida, nol yozuv yo\'q', async () => {
    const [page] = await paginate(memorySource(dataset()), 50);
    // 11-05 guruhining langari e-steps-3 (08:00) — f-join (09:00) dan keyin, d-book (07:00) dan oldin.
    expect(page).toEqual(expectedAll);
  });

  it.each([1, 2, 3, 4, 5, 6, 7])('limit=%i: sahifalar birlashmasi = to\'liq ro\'yxat, takror va yo\'qolish yo\'q', async (limit) => {
    const pages = await paginate(memorySource(dataset()), limit);
    expect(pages.flat()).toEqual(expectedAll);
    expect(pages.slice(0, -1).every((p) => p.length === limit)).toBe(true);
  });

  it('qadam guruhi sahifa chegarasida bo\'lsa ham ikki marta chiqmaydi (limit=2)', async () => {
    const pages = await paginate(memorySource(dataset()), 2);
    expect(pages).toEqual([
      ['f-join', 'steps:2026-11-05'],
      ['d-book', 'b-learn'],
      ['steps:2026-11-04', 'h-video'],
    ]);
  });

  it('qadam kunining eski qatorlari kursordan pastda bo\'lsa ham guruh qaytadan chiqmaydi', async () => {
    const source = memorySource(dataset());
    // Kursor = steps:2026-11-05 langari (e-steps-3). Keyingi sahifada c-steps-2 / a-steps-1
    // (xom qatorlar) uchrasa ham element bermasligi shart.
    const anchor = dataset().find((r) => r.id === 'e-steps-3')!;
    const next = await collectLedgerEntries(source, { at: anchor.createdAt, id: anchor.id }, 50);
    expect(next.map((e) => e.id)).toEqual(['d-book', 'b-learn', 'steps:2026-11-04', 'h-video']);
  });

  it('bir xil createdAt (teng vaqt) bo\'lsa id bo\'yicha aniq tartib, yo\'qolish yo\'q', async () => {
    const same = '2026-11-05T09:00:00.000Z';
    const data = ['a', 'b', 'c', 'd', 'e'].map((id) => row(T.BOOK_READ, same, 1, id));
    const pages = await paginate(memorySource(data), 2);
    expect(pages.flat()).toEqual(['e', 'd', 'c', 'b', 'a']);
  });

  it('juda ko\'p o\'tkazib yuboriladigan qadam qatorlari bo\'lsa ham to\'ldiradi (ko\'p partiya)', async () => {
    // 120 ta qadam qatori bir kunda (faqat 1 element) + 3 ta kitob.
    const steps = Array.from({ length: 120 }, (_, i) =>
      row(T.DAILY_GOAL, new Date(Date.parse('2026-11-05T01:00:00.000Z') + i * 60_000).toISOString(), 5),
    );
    const books = [1, 2, 3].map((i) => row(T.BOOK_READ, `2026-11-04T0${i}:00:00.000Z`, 2));
    const source = memorySource([...steps, ...books]);
    const found = await collectLedgerEntries(source, null, 4);
    expect(found.map((e) => e.id)).toEqual([
      'steps:2026-11-05',
      books[2].id,
      books[1].id,
      books[0].id,
    ]);
    expect(found[0].amount).toBe(600);
    expect(source.calls).toBeGreaterThan(1);
  });

  it('bo\'sh daftar', async () => {
    expect(await collectLedgerEntries(memorySource([]), null, 51)).toEqual([]);
  });
});
