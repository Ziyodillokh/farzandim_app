'use client';

import { useCallback, useEffect, useState } from 'react';

import { api } from '@/data/api';
import { ServiceError } from '@/data/contracts';
import { enqueueTap, loadQueue, type QueuedTap, saveQueue } from './tap-queue';

/** Navbatni yuborishga urinish oralig'i. */
export const FLUSH_MS = 15_000;

/** Tarmoq xatosi (internet yo'q / server javob bermadi) — tegish navbatda qoladi. */
export const isRetryable = (error: unknown) => error instanceof ServiceError && error.code === 'UNKNOWN';

/**
 * Navbatdagi tegishlarni tartib bilan yuborish. Tarmoq xatosida to'xtaydi (keyingi urinishda davom);
 * boshqa xato (masalan 12 soatdan eski) — o'sha tegish tashlab yuboriladi, chunki u hech qachon o'tmaydi.
 */
export async function flushQueue(send: (tap: QueuedTap) => Promise<unknown>): Promise<QueuedTap[]> {
  let pending = loadQueue();
  while (pending.length > 0) {
    try {
      await send(pending[0]);
    } catch (error) {
      if (isRetryable(error)) break;
    }
    pending = pending.slice(1);
    saveQueue(pending);
  }
  return pending;
}

/** Kiosk oflayn navbati: `add` — tarmoq xatosida; navbat bo'lsa har 15 soniyada yuboriladi. */
export function useTapQueue() {
  const [size, setSize] = useState(0);

  useEffect(() => setSize(loadQueue().length), []);

  const add = useCallback((tap: QueuedTap) => setSize(enqueueTap(tap).length), []);

  useEffect(() => {
    if (size === 0) return;
    let running = false;
    const id = setInterval(() => {
      if (running) return;
      running = true;
      void flushQueue((tap) => api.cards.tap(tap))
        .then((rest) => setSize(rest.length))
        .finally(() => {
          running = false;
        });
    }, FLUSH_MS);
    return () => clearInterval(id);
  }, [size]);

  return { size, add };
}
