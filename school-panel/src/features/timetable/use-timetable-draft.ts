'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';

import type { TimetableLesson } from '@/data/contracts';
import { type Grid, gridsEqual, toGrid } from './lib/grid';

type Model = { classKey: string | null; base: Grid; draft: Grid };

const EMPTY: Grid = {};

/**
 * Tahrir qoralamasi: serverdagi jadval (`base`) va foydalanuvchi o'zgartirgani (`draft`).
 * Server ma'lumoti qayta kelsa (fon yangilanishi) — qoralama o'zgarmagan bo'lsa yangisi olinadi,
 * o'zgargan bo'lsa foydalanuvchi ishi saqlanadi va faqat `base` yangilanadi.
 */
export function useTimetableDraft(classKey: string | null, serverLessons: readonly TimetableLesson[] | undefined) {
  const [model, setModel] = useState<Model>({ classKey: null, base: EMPTY, draft: EMPTY });

  useEffect(() => {
    if (!classKey || !serverLessons) return;
    const incoming = toGrid(serverLessons);
    setModel((current) => {
      if (current.classKey !== classKey) return { classKey, base: incoming, draft: incoming };
      if (gridsEqual(current.base, incoming)) return current;
      return gridsEqual(current.draft, current.base) ? { classKey, base: incoming, draft: incoming } : { ...current, base: incoming };
    });
  }, [classKey, serverLessons]);

  const update = useCallback((updater: (draft: Grid) => Grid) => setModel((current) => ({ ...current, draft: updater(current.draft) })), []);
  const discard = useCallback(() => setModel((current) => ({ ...current, draft: current.base })), []);

  const isReady = model.classKey === classKey && classKey !== null;
  const isDirty = useMemo(() => isReady && !gridsEqual(model.draft, model.base), [isReady, model.draft, model.base]);

  return { isReady, isDirty, draft: model.draft, update, discard };
}
