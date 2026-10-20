'use client';

import { useEffect } from 'react';

import { runEngineTick } from '@/features/engine/tick';

const TICK_MS = 1000;

/**
 * Kiosk ilova qobig'idan tashqarida ochiladi, shuning uchun DemoEngine yo'q.
 * Rejadagi kirishlar shu yerda ham "o'ynaladi" (toast'siz) — hisoblagichlar
 * jonli bo'ladi. Panel boshqa tabda ochiq bo'lsa ham xavfsiz: simulyator
 * `processedUntilMinute` bo'yicha idempotent.
 */
export function useKioskEngine(): void {
  useEffect(() => {
    const lastKey = { current: '' };
    const tick = () => {
      runEngineTick(lastKey);
    };
    tick();
    const id = setInterval(tick, TICK_MS);
    return () => clearInterval(id);
  }, []);
}
