'use client';

import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { useCallback } from 'react';

/**
 * URL'dagi tab (`?tab=`) — sahifa yangilansa yoki havola ulashilsa ham shu tab ochiladi.
 * Chaqiruvchi sahifa `useSearchParams` sababli `<Suspense>` ichida bo'lishi kerak.
 */
export function useTabParam<T extends string>(values: readonly T[], fallback: T, key = 'tab'): [T, (next: T) => void] {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const raw = params.get(key);
  const current = raw && (values as readonly string[]).includes(raw) ? (raw as T) : fallback;
  const set = useCallback(
    (next: T) => {
      const q = new URLSearchParams(params.toString());
      if (next === fallback) q.delete(key);
      else q.set(key, next);
      const qs = q.toString();
      router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    },
    [fallback, key, params, pathname, router],
  );
  return [current, set];
}
