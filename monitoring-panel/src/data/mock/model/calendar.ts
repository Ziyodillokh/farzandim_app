/**
 * O'quv kalendari: oylar (sentyabr–may), choraklar va davrlar.
 * Oy indeksi `t` — 2024-yil sentyabridan boshlab o'quv oylari soni
 * (yozgi oylar hisobga olinmaydi): 2024-09 → 0, 2025-05 → 8, 2025-09 → 9, ...
 */

export const FIRST_AY = 2024;
/** O'quv yili ichidagi oylar tartibi. */
export const AY_MONTHS = [9, 10, 11, 12, 1, 2, 3, 4, 5] as const;
export type SchoolMonth = { ay: number; month: number; t: number; key: string };

/** Choraklar: I — sen/okt, II — noy/dek, III — yan/fev/mar, IV — apr/may. */
export const QUARTER_OF_MONTH: Readonly<Record<number, 1 | 2 | 3 | 4>> = {
  9: 1, 10: 1, 11: 2, 12: 2, 1: 3, 2: 3, 3: 3, 4: 4, 5: 4,
};

export function schoolMonth(ay: number, month: number): SchoolMonth {
  const idx = AY_MONTHS.indexOf(month as (typeof AY_MONTHS)[number]);
  if (idx < 0) throw new Error(`O'quv oyi emas: ${month}`);
  const year = month >= 9 ? ay : ay + 1;
  return { ay, month, t: (ay - FIRST_AY) * AY_MONTHS.length + idx, key: `${year}-${String(month).padStart(2, '0')}` };
}

/** Sana qaysi o'quv yiliga tegishli (sentyabrdan boshlanadi). */
export function academicYearOf(date: Date): number {
  const m = date.getMonth() + 1;
  return m >= 9 ? date.getFullYear() : date.getFullYear() - 1;
}

/**
 * Sanaga mos oxirgi o'quv oyi: yozda (iyun–avgust) — o'tgan o'quv yilining mayi.
 */
export function currentSchoolMonth(asOf: Date): SchoolMonth {
  const m = asOf.getMonth() + 1;
  if (m >= 6 && m <= 8) return schoolMonth(asOf.getFullYear() - 1, 5);
  return schoolMonth(academicYearOf(asOf), m);
}

/** O'quv yilining `upTo` gacha bo'lgan oylari. */
export function monthsOfYear(ay: number, upToT = Number.POSITIVE_INFINITY): SchoolMonth[] {
  return AY_MONTHS.map((m) => schoolMonth(ay, m)).filter((s) => s.t <= upToT);
}

export const PERIODS = ['QUARTER', 'AY', 'PREV_AY'] as const;
export type Period = (typeof PERIODS)[number];

export type PeriodWindow = {
  period: Period;
  /** Davr oylari (hisoblashda o'rtacha olinadi). */
  months: SchoolMonth[];
  /** Taqqoslash: o'tgan yilning shu davri. */
  baseline: SchoolMonth[];
  ay: number;
  quarter: 1 | 2 | 3 | 4 | null;
};

function shiftYear(months: SchoolMonth[], years: number): SchoolMonth[] {
  return months.filter((m) => m.ay - years >= FIRST_AY).map((m) => schoolMonth(m.ay - years, m.month));
}

export function resolvePeriod(period: Period, asOf: Date): PeriodWindow {
  const now = currentSchoolMonth(asOf);
  if (period === 'QUARTER') {
    const q = QUARTER_OF_MONTH[now.month] ?? 1;
    const months = monthsOfYear(now.ay, now.t).filter((m) => QUARTER_OF_MONTH[m.month] === q);
    return { period, months, baseline: shiftYear(months, 1), ay: now.ay, quarter: q };
  }
  if (period === 'AY') {
    const months = monthsOfYear(now.ay, now.t);
    return { period, months, baseline: shiftYear(months, 1), ay: now.ay, quarter: null };
  }
  const prev = now.ay - 1;
  const months = monthsOfYear(prev);
  return { period, months, baseline: shiftYear(months, 1), ay: prev, quarter: null };
}

/** Trend grafiklari uchun: oxirgi `count` o'quv oyi (joriy oy bilan). */
export function lastSchoolMonths(asOf: Date, count = 12): SchoolMonth[] {
  const now = currentSchoolMonth(asOf);
  const out: SchoolMonth[] = [];
  for (let t = now.t; t >= 0 && out.length < count; t--) {
    const ay = FIRST_AY + Math.floor(t / AY_MONTHS.length);
    out.unshift(schoolMonth(ay, AY_MONTHS[t % AY_MONTHS.length] as number));
  }
  return out;
}

/** O'quv yili nomi: 2026 → "2026/2027". */
export function ayLabel(ay: number): string {
  return `${ay}/${ay + 1}`;
}
