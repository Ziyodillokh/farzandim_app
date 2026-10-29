import type { SubjectStat } from '@/data/contracts';
import type { Subject } from '@/data/reference/domains';
import { gap } from './kit/num';

export type SubjectTag = 'top' | 'bottom' | null;

export type RankedSubject = SubjectStat & {
  rank: number | null;
  /** Doira qiymati − respublika qiymati (p.p.). */
  vsNational: number | null;
  tag: SubjectTag;
};

/** Fanlarni o'zlashtirish bo'yicha tartiblash; eng yuqori va eng past — belgilanadi. Qiymatsizlar oxirida. */
export function rankSubjects(rows: readonly SubjectStat[]): RankedSubject[] {
  const valid = rows.filter((r) => r.value !== null).sort((a, b) => (b.value as number) - (a.value as number));
  const last = valid.length - 1;
  const tagOf = (i: number): SubjectTag => (last < 1 ? null : i === 0 ? 'top' : i === last ? 'bottom' : null);
  const ranked = valid.map((r, i) => ({ ...r, rank: i + 1, vsNational: gap(r.value, r.national), tag: tagOf(i) }));
  const missing = rows.filter((r) => r.value === null).map((r) => ({ ...r, rank: null, vsNational: null, tag: null }));
  return [...ranked, ...missing];
}

export type SubjectHighlights = {
  strongest?: RankedSubject;
  weakest?: RankedSubject;
  fastest?: RankedSubject;
  /** Respublikadan eng ko'p ortda qolgan fan (faqat salbiy farq bo'lsa). */
  lagging?: RankedSubject;
};

export function subjectHighlights(ranked: readonly RankedSubject[]): SubjectHighlights {
  const valid = ranked.filter((r) => r.rank !== null);
  const byDelta = valid.filter((r) => r.delta !== null && r.delta > 0).sort((a, b) => (b.delta as number) - (a.delta as number));
  const byGap = valid.filter((r) => r.vsNational !== null && r.vsNational < 0).sort((a, b) => (a.vsNational as number) - (b.vsNational as number));
  return {
    strongest: valid[0],
    weakest: valid.length > 1 ? valid[valid.length - 1] : undefined,
    fastest: byDelta[0],
    lagging: byGap[0],
  };
}

/**
 * Tanlangan sinflarda o'qitilmaydigan fanlar (qiymat ham, tanlov ham yo'q) —
 * ro'yxatdan chiqariladi, nomlari izohda beriladi.
 */
export function splitTaught(rows: readonly SubjectStat[]): { taught: SubjectStat[]; untaught: Subject[] } {
  const isUntaught = (r: SubjectStat) => r.value === null && (r.interest === null || r.interest === 0);
  return { taught: rows.filter((r) => !isUntaught(r)), untaught: rows.filter(isUntaught).map((r) => r.subject) };
}
