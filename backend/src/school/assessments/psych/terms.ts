// O'quv yili choraklari — panel `school-panel/src/lib/psych/terms.ts` bilan bir
// xil qoidalar. O'quv yili sentabrda boshlanadi: 2026-10-12 → 2026–2027.
// (Rivojlanish dinamikasi — natijalar chorak bo'yicha guruhlanadi.)

import type { IsoDate } from './types';

export type QuarterNo = 1 | 2 | 3 | 4;
export type Term = { key: string; year: number; no: QuarterNo };

export function academicYearOf(date: IsoDate): number {
  const [y, m] = date.split('-').map(Number) as [number, number];
  return m >= 9 ? y : y - 1;
}

export function quarterRanges(year: number): Array<{ no: QuarterNo; start: IsoDate; end: IsoDate }> {
  return [
    { no: 1, start: `${year}-09-02`, end: `${year}-11-01` },
    { no: 2, start: `${year}-11-10`, end: `${year}-12-27` },
    { no: 3, start: `${year + 1}-01-12`, end: `${year + 1}-03-20` },
    { no: 4, start: `${year + 1}-03-30`, end: `${year + 1}-05-25` },
  ];
}

export function termKey(year: number, no: QuarterNo): string {
  return `${year}-${String((year + 1) % 100).padStart(2, '0')}:Q${no}`;
}

/** Sana qaysi chorakka tegishli: ta'tilda — oldingi chorak; yozda — o'tgan yilning 4-choragi. */
export function termOf(date: IsoDate): Term {
  const year = academicYearOf(date);
  const ranges = quarterRanges(year);
  let current: { year: number; no: QuarterNo } = { year: year - 1, no: 4 };
  for (const q of ranges) if (date >= q.start) current = { year, no: q.no };
  return { key: termKey(current.year, current.no), ...current };
}

/** Ikki sana o'rtasi (kalendar kunlari; UTC hisobida — server vaqt zonasiga bog'liq emas). */
function midpoint(start: IsoDate, end: IsoDate): IsoDate {
  const a = Date.parse(`${start}T12:00:00Z`);
  const b = Date.parse(`${end}T12:00:00Z`);
  return new Date((a + b) / 2).toISOString().slice(0, 10);
}

/** Joriy chorakdan OLDINGI `n` ta chorak (eskidan yangiga), har birining o'rta sanasi bilan. */
export function previousTerms(date: IsoDate, n: number): Array<{ key: string; mid: IsoDate }> {
  const current = termOf(date);
  const out: Array<{ key: string; mid: IsoDate }> = [];
  let year = current.year;
  let no: number = current.no;
  for (let i = 0; i < n; i++) {
    no -= 1;
    if (no < 1) {
      no = 4;
      year -= 1;
    }
    const q = quarterRanges(year)[no - 1];
    if (q) out.unshift({ key: termKey(year, no as QuarterNo), mid: midpoint(q.start, q.end) });
  }
  return out;
}
