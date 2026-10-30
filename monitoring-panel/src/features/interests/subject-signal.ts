import type { Subject } from '@/data/reference/domains';

export type SubjectSignal = 'priority' | 'engage' | null;

/**
 * Fan tanlovi: ulush va shu fan bo'yicha o'zlashtirish. `share: null` — ulush
 * K-anonimlik bilan yashirilgan (o'qitilmaydigan fan emas).
 */
export type ChoiceInput = { key: Subject; share: number | null; mastery: number | null };
export type ChoiceRow = ChoiceInput & { rank: number | null; signal: SubjectSignal };

/** O'zlashtirish fanlar medianasidan shu chegaradan ko'proq (p.p.) past bo'lsa — "resurs ustuvorligi". */
export const PRIORITY_MARGIN = 0.5;
/** Kam tanlangan fan uchun — sezilarli past natija chegarasi (p.p.). */
export const ENGAGE_MARGIN = 3;

export function median(values: readonly number[]): number | null {
  if (values.length === 0) return null;
  const s = [...values].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? (s[mid] as number) : ((s[mid - 1] as number) + (s[mid] as number)) / 2;
}

/** Medianadan qancha past (p.p.); 0,01 gacha yaxlitlanadi — chegarada suzuvchi nuqta xatosi bo'lmasin. */
const shortfall = (mid: number, v: number) => Math.round((mid - v) * 100) / 100;

const isNumber = (v: number | null): v is number => v !== null;

/** Tanlangan sinflarda o'qitilmaydigan fan: tanlov 0 va natija yo'q. Yashirilgan ulush (`null`) bunga kirmaydi. */
export function isUntaughtChoice(s: ChoiceInput): boolean {
  return s.share === 0 && s.mastery === null;
}

/**
 * Fan signali: ko'p tanlanadi (ulush ≥ mediana), lekin o'zlashtirish medianadan
 * `PRIORITY_MARGIN` dan ko'proq past — resurs ustuvorligi; kam tanlanadi va
 * natija `ENGAGE_MARGIN` dan ko'proq past — qiziqtirish kerak. Ulushi yashirilgan
 * fanlar oxirida, o'rinsiz va signalsiz; o'qitilmaydiganlar medianaga kirmaydi.
 */
export function classifySubjects(all: readonly ChoiceInput[]): {
  rows: ChoiceRow[];
  untaught: Subject[];
  medianShare: number | null;
  medianMastery: number | null;
} {
  const subjects = all.filter((s) => !isUntaughtChoice(s));
  const shown = subjects.filter((s): s is ChoiceInput & { share: number } => s.share !== null).sort((a, b) => b.share - a.share);
  const medianShare = median(shown.map((s) => s.share));
  const medianMastery = median(subjects.map((s) => s.mastery).filter(isNumber));
  const signalOf = (s: ChoiceInput & { share: number }): SubjectSignal => {
    if (s.mastery === null || medianShare === null || medianMastery === null) return null;
    const below = shortfall(medianMastery, s.mastery);
    if (s.share >= medianShare) return below > PRIORITY_MARGIN ? 'priority' : null;
    return below > ENGAGE_MARGIN ? 'engage' : null;
  };
  const ranked = shown.map((s) => ({ ...s, rank: 1 + shown.findIndex((x) => x.share === s.share), signal: signalOf(s) }));
  const hidden = subjects.filter((s) => s.share === null).map((s) => ({ ...s, rank: null, signal: null }));
  return { rows: [...ranked, ...hidden], untaught: all.filter(isUntaughtChoice).map((s) => s.key), medianShare, medianMastery };
}
