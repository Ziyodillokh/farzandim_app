'use client';

import { useEffect, useState, useSyncExternalStore } from 'react';

import { clockNow, getClockState, subscribeClock } from '@/data/mock/clock';

/** Demo soati holati (rejim, tezlik). */
export function useClockState() {
  return useSyncExternalStore(subscribeClock, getClockState, getClockState);
}

/** Har `intervalMs` da yangilanadigan demo vaqti. */
export function useClockNow(intervalMs = 1000): Date {
  const [now, setNow] = useState(() => clockNow());
  const state = useClockState();
  useEffect(() => {
    setNow(clockNow());
    const id = setInterval(() => setNow(clockNow()), intervalMs);
    return () => clearInterval(id);
  }, [intervalMs, state]);
  return now;
}
