'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useEffect, useState, type ReactNode } from 'react';

import { getSession, subscribeSession } from '@/auth/session';

/** React Query: ma'lumot faqat o'qiladi; foydalanuvchi almashsa kesh tozalanadi. */
export function QueryProvider({ children }: { children: ReactNode }) {
  const [client] = useState(
    () =>
      new QueryClient({
        defaultOptions: { queries: { staleTime: 5 * 60_000, refetchOnWindowFocus: false, retry: false } },
      }),
  );
  useEffect(() => {
    let user = getSession()?.username ?? null;
    return subscribeSession(() => {
      const next = getSession()?.username ?? null;
      if (next !== user) client.clear();
      user = next;
    });
  }, [client]);
  return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
}
