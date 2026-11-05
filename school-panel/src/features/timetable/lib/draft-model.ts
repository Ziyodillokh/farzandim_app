import { type Grid, gridsEqual } from './grid';

/** Tahrir qoralamasi holati: qaysi sinf, serverdagi jadval (`base`) va foydalanuvchi o'zgartirgani (`draft`). */
export type DraftModel = { classKey: string | null; base: Grid; draft: Grid };

const EMPTY: Grid = {};
export const EMPTY_DRAFT_MODEL: DraftModel = { classKey: null, base: EMPTY, draft: EMPTY };

/**
 * Server ma'lumoti (`incoming`, yo'q bo'lsa `null`) kelganda qoralamani moslashtiradi:
 * - sinf almashgan — eski qoralama DARHOL tashlanadi (qaytib kelganda ham tiklanmaydi);
 * - yangi sinf — qoralama serverdagiga teng;
 * - fon yangilanishi: qoralama o'zgarmagan bo'lsa yangisi olinadi, o'zgargan bo'lsa ish saqlanadi, `base` yangilanadi.
 */
export function reconcileDraft(current: DraftModel, classKey: string | null, incoming: Grid | null): DraftModel {
  const live = current.classKey !== null && current.classKey !== classKey ? EMPTY_DRAFT_MODEL : current;
  if (!classKey || !incoming) return live;
  if (live.classKey !== classKey) return { classKey, base: incoming, draft: incoming };
  if (gridsEqual(live.base, incoming)) return live;
  return gridsEqual(live.draft, live.base) ? { classKey, base: incoming, draft: incoming } : { ...live, base: incoming };
}

export function isDraftDirty(model: DraftModel, classKey: string | null): boolean {
  return model.classKey === classKey && classKey !== null && !gridsEqual(model.draft, model.base);
}
