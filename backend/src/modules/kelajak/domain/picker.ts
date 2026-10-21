// Kelajak sessiyasi uchun savol tanlash (docs/KELAJAK-REJA.md §3):
// - nomzodlar: faol, sessiya yosh guruhidan, test turiga mos kategoriyadan;
// - tartib: hech javob berilmaganlar, keyin eng uzoq vaqt oldin javob
//   berilganlar; tenglikda urug'li aralashtirish (kun + tur + bola);
// - "hammasi" kategoriyalari birinchi, kategoriya chegarasi saqlanadi;
// - yakuniy tartib: kategoriya tartibi, ichida tanlov tartibi, `text` oxirida.

import { DayKey } from '../../../common/time/tashkent';
import { shuffled } from '../../learning/domain/question-picker';
import { KelajakAgeGroup } from './age';
import { categoryOrder, KelajakTestConfig, testCategories } from './catalog';

export interface PickerQuestion {
  id: string;
  category: string;
  ageGroup: string;
  answerType: string;
  active: boolean;
}

export interface PickParams<T extends PickerQuestion> {
  config: KelajakTestConfig;
  ageGroup: KelajakAgeGroup;
  pool: readonly T[];
  /** Savol id → oxirgi javob vaqti (ms). Yo'q — hech javob berilmagan. */
  lastAnsweredAt: ReadonlyMap<string, number>;
  seed: number;
}

/** Kun + tur + bola uchun barqaror urug' (FNV-1a, 32 bit). */
export function kelajakSeed(day: DayKey, type: string, childId: string): number {
  let hash = 0x811c9dc5;
  for (const ch of `${day}|${type}|${childId}`) {
    hash ^= ch.codePointAt(0)!;
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash;
}

/** Faqat shu yosh guruhi va test kategoriyalaridagi faol savollar. */
export function kelajakCandidates<T extends PickerQuestion>(
  pool: readonly T[],
  config: KelajakTestConfig,
  ageGroup: KelajakAgeGroup,
): T[] {
  const allowed = new Set<string>(testCategories(config));
  return pool.filter((q) => q.active && q.ageGroup === ageGroup && allowed.has(q.category));
}

export function pickKelajakQuestions<T extends PickerQuestion>(params: PickParams<T>): T[] {
  const { config, ageGroup, pool, lastAnsweredAt, seed } = params;
  const candidates = kelajakCandidates(pool, config, ageGroup);
  if (candidates.length === 0 || config.count <= 0) return [];

  // Ustuvorlik: javobsiz → eski javob → aralash tartib (sort barqaror).
  const ranked = shuffled(candidates, seed)
    .map((q) => ({ q, last: lastAnsweredAt.get(q.id) ?? null }))
    .sort((a, b) => {
      if (a.last === null || b.last === null) {
        return (a.last === null ? 0 : 1) - (b.last === null ? 0 : 1);
      }
      return a.last - b.last;
    })
    .map((x) => x.q);

  const full = new Set<string>(config.full);
  const passes = [ranked.filter((q) => full.has(q.category)), ranked.filter((q) => !full.has(q.category))];
  const picked = passes.reduce<T[]>((acc, pass) => {
    return pass.reduce<T[]>((list, q) => {
      if (list.length >= config.count) return list;
      const inCategory = list.filter((p) => p.category === q.category).length;
      if (config.perCategoryMax !== null && inCategory >= config.perCategoryMax) return list;
      return [...list, q];
    }, acc);
  }, []);

  const textLast = (q: T) => (q.answerType === 'text' ? 1 : 0);
  return picked
    .map((q, index) => ({ q, index }))
    .sort(
      (a, b) =>
        textLast(a.q) - textLast(b.q) ||
        categoryOrder(a.q.category) - categoryOrder(b.q.category) ||
        a.index - b.index,
    )
    .map((x) => x.q);
}
