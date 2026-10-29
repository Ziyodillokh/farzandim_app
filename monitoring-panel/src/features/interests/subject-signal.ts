import type { Interests } from '@/data/contracts';

export type SubjectSignal = 'priority' | 'engage' | null;
export type ChoiceRow = Interests['subjects'][number] & { rank: number; signal: SubjectSignal };

/** O'zlashtirish fanlar medianasidan shuncha p.p. past bo'lsa — "resurs ustuvorligi". */
const PRIORITY_MARGIN = 0.5;
/** Kam tanlangan fan uchun — sezilarli past natija chegarasi. */
const ENGAGE_MARGIN = 3;

export function median(values: readonly number[]): number | null {
  if (values.length === 0) return null;
  const s = [...values].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

/**
 * Fan signali: ko'p tanlanadi, lekin o'zlashtirish medianadan past — resurs
 * ustuvorligi; kam tanlanadi va natija ancha past — qiziqtirish kerak.
 */
export function classifySubjects(all: Interests['subjects']): {
  rows: ChoiceRow[];
  untaught: Array<Interests['subjects'][number]['key']>;
  medianShare: number | null;
  medianMastery: number | null;
} {
  // Tanlangan sinflarda o'qitilmaydigan fan: tanlov ham, natija ham yo'q — medianaga kirmaydi.
  const isUntaught = (s: Interests['subjects'][number]) => s.share === 0 && s.mastery === null;
  const subjects = all.filter((s) => !isUntaught(s));
  const medianShare = median(subjects.map((s) => s.share));
  const medianMastery = median(subjects.map((s) => s.mastery).filter((m): m is number => m !== null));
  const signalOf = (s: Interests['subjects'][number]): SubjectSignal => {
    if (s.mastery === null || medianShare === null || medianMastery === null) return null;
    if (s.share >= medianShare && s.mastery < medianMastery - PRIORITY_MARGIN) return 'priority';
    if (s.share < medianShare && s.mastery < medianMastery - ENGAGE_MARGIN) return 'engage';
    return null;
  };
  const rows = [...subjects].sort((a, b) => b.share - a.share).map((s, i) => ({ ...s, rank: i + 1, signal: signalOf(s) }));
  return { rows, untaught: all.filter(isUntaught).map((s) => s.key), medianShare, medianMastery };
}
