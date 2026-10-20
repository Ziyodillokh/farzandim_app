'use client';

import { useQuery } from '@tanstack/react-query';
import { useCallback, useEffect, useMemo, useState } from 'react';

import { useSession } from '@/auth/use-session';
import { api } from '@/data/api';
import { useClockState } from '@/features/engine/use-clock';
import { readPref, writePref } from '@/lib/prefs';
import { normalizeReadState, type ReadState, readStateKey } from './read-state';

export const NOTIFICATIONS_KEY = ['notifications'] as const;
const REFETCH_MS = 30_000;

export function useNotificationFeed() {
  const session = useSession();
  return useQuery({
    queryKey: NOTIFICATIONS_KEY,
    queryFn: () => api.notifications.feed(),
    enabled: Boolean(session),
    refetchInterval: REFETCH_MS,
  });
}

/** Xodimning "o'qildi" holati (sozlamalarda); demo soati epoch'iga moslangan. */
export function useReadState(staffId: string | null | undefined): [ReadState, (update: (state: ReadState) => ReadState) => void] {
  const { epoch } = useClockState();
  const key = staffId ? readStateKey(staffId) : null;
  const [raw, setRaw] = useState<unknown>(() => (key ? readPref<unknown>(key) : null));

  useEffect(() => {
    setRaw(key ? readPref<unknown>(key) : null);
  }, [key]);

  const state = useMemo(() => normalizeReadState(raw, epoch), [raw, epoch]);

  const update = useCallback(
    (fn: (state: ReadState) => ReadState) => {
      if (!key) return;
      const next = fn(state);
      writePref(key, next);
      setRaw(next);
    },
    [key, state],
  );

  return [state, update];
}
