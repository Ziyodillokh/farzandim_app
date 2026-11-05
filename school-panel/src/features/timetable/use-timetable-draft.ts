'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';

import type { ClassTimetable } from '@/data/contracts';
import { type DraftModel, EMPTY_DRAFT_MODEL, isDraftDirty, reconcileDraft } from './lib/draft-model';
import type { Grid } from './lib/grid';
import { toVisibleGrid } from './lib/grid';

/** Tahrir qoralamasi (mantiq — `lib/draft-model.ts`, testlangan). */
export function useTimetableDraft(classKey: string | null, timetable: Pick<ClassTimetable, 'lessons' | 'shift'> | undefined) {
  const [model, setModel] = useState<DraftModel>(EMPTY_DRAFT_MODEL);
  const lessons = timetable?.lessons;
  const periods = timetable?.shift.periods;

  useEffect(() => {
    const incoming = lessons && periods ? toVisibleGrid(lessons, periods) : null;
    setModel((current) => reconcileDraft(current, classKey, incoming));
  }, [classKey, lessons, periods]);

  const update = useCallback((updater: (draft: Grid) => Grid) => setModel((current) => ({ ...current, draft: updater(current.draft) })), []);
  const discard = useCallback(() => setModel((current) => ({ ...current, draft: current.base })), []);

  const isReady = model.classKey === classKey && classKey !== null;
  const isDirty = useMemo(() => isDraftDirty(model, classKey), [model, classKey]);

  return { isReady, isDirty, draft: model.draft, update, discard };
}
