'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { toast } from 'sonner';

import { getSession, subscribeSession } from '@/auth/session';
import { bindClockSync, clockToday, subscribeClock } from '@/data/mock/clock';
import { bindCrossTabSync, onStorageFull, subscribe } from '@/data/mock/db';
import { ensureDemoFresh } from '@/data/mock/freshness';
import { useI18n } from '@/i18n';

/** Yarim tun (haqiqiy vaqt rejimi) ham sezilsin — demo soati kunini shu oraliqda tekshiramiz. */
const DATE_CHECK_MS = 5_000;
const INVALIDATE_DEBOUNCE_MS = 800;
/** Ochilishdagi toast — saqlangan til (I18nProvider effekti) qo'llangandan keyin. */
const REGENERATED_TOAST_DELAY_MS = 500;

/**
 * Demo ma'lumotlari demo soati kuniga mos bo'lsin: ochilganda, soat rejimi/kuni
 * o'zgarganda (ertalab qayta boshlash, ssenariy) va yarim tunda.
 */
function useDemoFreshness(onRegenerated: () => void): void {
  useEffect(() => {
    let lastDate = '';
    const check = () => {
      const today = clockToday();
      if (today === lastDate) return;
      lastDate = today;
      if (ensureDemoFresh() === 'REGENERATED') onRegenerated();
    };
    check();
    const unsubscribe = subscribeClock(check);
    const id = setInterval(check, DATE_CHECK_MS);
    return () => {
      unsubscribe();
      clearInterval(id);
    };
  }, [onRegenerated]);
}

/**
 * React Query + mock baza: boshqa tab (kiosk) yoki simulyator o'zgartirganda
 * ma'lumot yangilanadi. Servis xatolari mutatsiya joyida ko'rsatiladi.
 */
export function QueryProvider({ children }: { children: ReactNode }) {
  const { t } = useI18n();
  const [client] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: { staleTime: 15_000, refetchOnWindowFocus: false, retry: false },
          mutations: { retry: false },
        },
      }),
  );
  const tRef = useRef(t);
  useEffect(() => {
    tRef.current = t;
  }, [t]);
  const onRegenerated = useCallback(() => {
    void client.invalidateQueries();
    setTimeout(() => toast.info(tRef.current('demo.dataRegenerated')), REGENERATED_TOAST_DELAY_MS);
  }, [client]);

  useDemoFreshness(onRegenerated);

  useEffect(() => {
    bindCrossTabSync();
    bindClockSync();
    onStorageFull(() => toast.warning(t('errors.storageFull')));
    // Simulyator va boshqa tab tez-tez yozadi — yangilashni birlashtiramiz.
    let timer: ReturnType<typeof setTimeout> | null = null;
    const unsubscribe = subscribe(() => {
      if (timer) return;
      timer = setTimeout(() => {
        timer = null;
        void client.invalidateQueries();
      }, INVALIDATE_DEBOUNCE_MS);
    });
    // Foydalanuvchi almashganda keshni tozalaymiz — oldingi rol ma'lumoti bir lahza ham ko'rinmasin.
    let staffId = getSession()?.staffId ?? null;
    const unsubscribeSession = subscribeSession(() => {
      const next = getSession()?.staffId ?? null;
      if (next !== staffId) client.clear();
      staffId = next;
    });
    return () => {
      unsubscribe();
      unsubscribeSession();
      if (timer) clearTimeout(timer);
    };
  }, [client, t]);

  return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
}
