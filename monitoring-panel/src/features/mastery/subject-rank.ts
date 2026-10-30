import type { SubjectStat } from '@/data/contracts';
import type { Subject } from '@/data/reference/domains';
import { gap } from './kit/num';

export type SubjectTag = 'top' | 'bottom' | null;

export type RankedSubject = SubjectStat & {
  /** Teng qiymatlar — bir xil o'rin (1, 1, 3); qiymatsiz — null. */
  rank: number | null;
  /** Doira qiymati − respublika qiymati (p.p.). */
  vsNational: number | null;
  tag: SubjectTag;
};

type Valued = SubjectStat & { value: number };

const hasValue = (r: SubjectStat): r is Valued => r.value !== null;

/**
 * Fanlarni o'zlashtirish bo'yicha tartiblash. Eng yuqori va eng past qiymatli
 * fanlar (tenglari bilan) belgilanadi — faqat natijalar farq qilsa. Qiymatsizlar
 * (K-anonimlik) oxirida, o'rinsiz.
 */
export function rankSubjects(rows: readonly SubjectStat[]): RankedSubject[] {
  const valid = rows.filter(hasValue).sort((a, b) => b.value - a.value);
  const max = valid[0]?.value;
  const min = valid[valid.length - 1]?.value;
  const spread = max !== undefined && min !== undefined && max > min;
  const tagOf = (v: number): SubjectTag => (!spread ? null : v === max ? 'top' : v === min ? 'bottom' : null);
  const ranked = valid.map((r) => ({
    ...r,
    rank: 1 + valid.findIndex((x) => x.value === r.value),
    vsNational: gap(r.value, r.national),
    tag: tagOf(r.value),
  }));
  const missing = rows.filter((r) => !hasValue(r)).map((r) => ({ ...r, rank: null, vsNational: null, tag: null }));
  return [...ranked, ...missing];
}

export type SubjectHighlights = {
  strongest?: RankedSubject;
  /** Faqat natijalar farq qilsa (eng past qiymat eng yuqoridan kichik). */
  weakest?: RankedSubject;
  /** Eng katta ijobiy yillik o'zgarish (o'sish bo'lmasa — yo'q). */
  fastest?: RankedSubject;
  /** Respublikadan eng ko'p ortda qolgan fan (faqat salbiy farq bo'lsa). */
  lagging?: RankedSubject;
};

export function subjectHighlights(ranked: readonly RankedSubject[]): SubjectHighlights {
  const valid = ranked.filter((r) => r.rank !== null && r.value !== null);
  const strongest = valid[0];
  const last = valid[valid.length - 1];
  const weakest = strongest && last && (last.value as number) < (strongest.value as number) ? last : undefined;
  const byDelta = valid.filter((r) => r.delta !== null && r.delta > 0).sort((a, b) => (b.delta as number) - (a.delta as number));
  const byGap = valid.filter((r) => r.vsNational !== null && r.vsNational < 0).sort((a, b) => (a.vsNational as number) - (b.vsNational as number));
  return { strongest, weakest, fastest: byDelta[0], lagging: byGap[0] };
}

/**
 * Tanlangan sinflarda o'qitilmaydigan fan — natija ham, tanlov ham, bolalar ham
 * yo'q (`n = 0`). K-anonimlik bilan yashirilgan fan (`n > 0`, qiymat `null`)
 * o'qitilmaydigan hisoblanmaydi: ro'yxatda "—" bilan qoladi.
 */
export function isUntaught(r: SubjectStat): boolean {
  return r.value === null && r.n === 0 && (r.interest === null || r.interest === 0);
}

/** O'qitilmaydigan fanlar ro'yxatdan chiqariladi, nomlari izohda beriladi. */
export function splitTaught(rows: readonly SubjectStat[]): { taught: SubjectStat[]; untaught: Subject[] } {
  return { taught: rows.filter((r) => !isUntaught(r)), untaught: rows.filter(isUntaught).map((r) => r.subject) };
}
