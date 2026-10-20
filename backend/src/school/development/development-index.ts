// Rivojlanish indeksi (sof funksiyalar; panel `development-aggregate.ts` `buildIndex`).
// Indeks 0..100 = persentil (xavotir kabi HIGHER_CONCERN shkalalarda teskari):
// yuqori — yaxshiroq. Chorak — natija kunining (Toshkent) o'quv choragi.
// Har o'quvchi-chorak yozuvi natijadagi SINF / DARAJA NUSXASINI saqlaydi —
// guruhlash jonli sinflar jadvaliga bog'liq emas (ayirish hujumidan himoya).

import { tashkentDay } from '../../common/time/tashkent';
import { domainIndex } from '../assessments/psych/scoring';
import { quarterRanges, termOf } from '../assessments/psych/terms';
import type { DevDomain, IsoDate, Localized, PsychScale, PsychTest, ScaleScore, ScoreBand } from '../assessments/psych/types';
import type { ScoredResult } from '../assessments/results-view';

export const DEV_DOMAINS: readonly DevDomain[] = ['REASONING', 'ATTENTION', 'MEMORY', 'EMOTIONAL', 'SELF_ESTEEM', 'SOCIAL'];
export const COGNITIVE: readonly DevDomain[] = ['REASONING', 'ATTENTION', 'MEMORY'];

export type DomainScore = { index: number | null; band: ScoreBand | null; standard: number | null };
export type DomainMap = Partial<Record<DevDomain, DomainScore>>;
export type Entry = { result: ScoredResult; testTitle: Localized; termKey: string; at: number; domains: DomainMap };
/** O'quvchining choraktagi holati: har soha bo'yicha eng so'nggi qiymat + oxirgi natijadagi sinf / daraja nusxasi. */
export type StudentTerm = { classId: string | null; grade: number; domains: DomainMap; lastTakenAt: string; lastAt: number };
export type DevIndex = {
  entries: Entry[];
  tests: ReadonlyMap<string, PsychTest>;
  byStudent: ReadonlyMap<string, Entry[]>;
  /** Natija bor choraklar (eskidan yangiga). */
  terms: string[];
  /** chorak → o'quvchi → shu chorakdagi holat. */
  snapshot: ReadonlyMap<string, ReadonlyMap<string, StudentTerm>>;
};

const mean = (xs: readonly number[]): number | null => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
export const roundOrNull = (x: number | null): number | null => (x === null ? null : Math.round(x));
export const meanOf = mean;

/** Bir sohaga bir nechta shkala (hissiy holat: xavotir + kayfiyat) — indekslar o'rtachasi. */
export function domainsOf(test: Pick<PsychTest, 'scales'>, scores: readonly ScaleScore[]): DomainMap {
  const groups = new Map<DevDomain, Array<{ scale: PsychScale; score: ScaleScore }>>();
  for (const scale of test.scales) {
    const score = scores.find((s) => s.key === scale.key);
    if (!scale.domain || !score) continue;
    groups.set(scale.domain, [...(groups.get(scale.domain) ?? []), { scale, score }]);
  }
  const out: DomainMap = {};
  for (const [domain, items] of groups) {
    const indexes = items.map((i) => domainIndex(i.score, i.scale.polarity)).filter((x): x is number => x !== null);
    const concern = items.find((i) => i.scale.polarity === 'HIGHER_CONCERN');
    const standards = items.map((i) => i.score.standard).filter((x): x is number => x !== null);
    out[domain] = {
      index: roundOrNull(mean(indexes)),
      band: (concern ?? items[0])?.score.band ?? null,
      standard: concern || standards.length !== items.length ? null : roundOrNull(mean(standards)),
    };
  }
  return out;
}

/** Natija lahzasi → Toshkent kuni. */
export const localDay = (stamp: string): IsoDate => tashkentDay(new Date(stamp));

/** Natijalar (`takenAt` bo'yicha eskidan yangiga) → indeks. Testi topilmagan natija tashlanadi. */
export function buildIndex(results: readonly ScoredResult[], tests: ReadonlyMap<string, PsychTest>): DevIndex {
  const entries: Entry[] = results.flatMap((r) => {
    const test = tests.get(r.testId);
    if (!test) return [];
    return [{ result: r, testTitle: test.title, termKey: termOf(localDay(r.takenAt)).key, at: Date.parse(r.takenAt), domains: domainsOf(test, r.scales) }];
  });
  const byStudent = new Map<string, Entry[]>();
  const snapshot = new Map<string, Map<string, StudentTerm>>();
  for (const e of entries) {
    byStudent.set(e.result.studentId, [...(byStudent.get(e.result.studentId) ?? []), e]);
    const term = snapshot.get(e.termKey) ?? new Map<string, StudentTerm>();
    const prev = term.get(e.result.studentId);
    term.set(e.result.studentId, {
      classId: e.result.classId,
      grade: e.result.grade,
      domains: { ...prev?.domains, ...e.domains },
      lastTakenAt: e.result.takenAt,
      lastAt: e.at,
    });
    snapshot.set(e.termKey, term);
  }
  return { entries, tests, byStudent, terms: [...snapshot.keys()].sort(), snapshot };
}

/** "2025-26:Q3" → 2025. */
export function termYear(termKey: string): number {
  return Number(termKey.slice(0, 4));
}

/** Chorak tugash sanasi ("2025-26:Q3" → 2026-03-20). */
export function termEnd(termKey: string): IsoDate {
  const no = Number(termKey.slice(-1));
  return quarterRanges(termYear(termKey))[no - 1]?.end ?? `${termYear(termKey) + 1}-05-31`;
}

/** Har soha bo'yicha eng so'nggi qiymat (yozuvlar eskidan yangiga). */
export function latestDomains(entries: readonly Entry[]): DomainMap {
  return entries.reduce<DomainMap>((acc, e) => ({ ...acc, ...e.domains }), {});
}
