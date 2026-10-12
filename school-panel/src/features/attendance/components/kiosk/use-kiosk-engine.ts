'use client';

import { useEffect } from 'react';

import { clockMinute, clockToday, getClockState } from '@/data/mock/clock';
import { getTables, transact } from '@/data/mock/db';
import { simulate } from '@/data/mock/simulator';

const TICK_MS = 1000;

/**
 * Kiosk ilova qobig'idan tashqarida ochiladi, shuning uchun DemoEngine yo'q.
 * Rejadagi kirishlar shu yerda ham "o'ynaladi" (toast'siz) — hisoblagichlar
 * jonli bo'ladi. Panel boshqa tabda ochiq bo'lsa ham xavfsiz: simulyator
 * `processedUntilMinute` bo'yicha idempotent.
 */
export function useKioskEngine(): void {
  useEffect(() => {
    let lastKey = '';
    const tick = () => {
      const date = clockToday();
      const minute = Math.floor(clockMinute());
      const epoch = getClockState().epoch;
      const key = `${date}#${epoch}#${minute}`;
      if (key === lastKey) return;
      lastKey = key;
      const sim = getTables().sim;
      if (sim.date === `${date}#${epoch}` && sim.processedUntilMinute >= minute) return;
      transact((tables) => simulate(tables, date, minute, epoch));
    };
    tick();
    const id = setInterval(tick, TICK_MS);
    return () => clearInterval(id);
  }, []);
}
