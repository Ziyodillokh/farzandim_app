'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useEffect, useState, type ReactNode } from 'react';
import { toast } from 'sonner';

import { getSession, subscribeSession } from '@/auth/session';
import { bindClockSync } from '@/data/mock/clock';
import { bindCrossTabSync, onStorageFull, subscribe } from '@/data/mock/db';
import { useI18n } from '@/i18n';

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
      }, 800);
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
