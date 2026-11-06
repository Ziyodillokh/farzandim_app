import { useMemo } from 'react';

/**
 * Bir vaqtda bitta so'rov: oldingisi tugamaguncha qayta chaqirilsa — o'sha va'daning o'zi qaytadi (yangi so'rov YO'Q).
 * Tez-tez bosish (dblclick) `isPending` qayta chizilgunicha ikkinchi chaqiruvni o'tkazib yuborishi mumkin: TanStack
 * holat yangilanishini keyinga qoldiradi, tugma esa hali faol — natijada ikkita kod/qaror yaratilardi.
 */
export function singleFlight<A extends unknown[], R>(fn: (...args: A) => Promise<R>): (...args: A) => Promise<R> {
  let inFlight: Promise<R> | null = null;
  return (...args: A) => {
    if (inFlight) return inFlight;
    const run = fn(...args).finally(() => {
      inFlight = null;
    });
    inFlight = run;
    return run;
  };
}

/** `singleFlight`ning hook ko'rinishi: `fn` o'zgarmasa bir xil holat saqlanadi. */
export function useSingleFlight<A extends unknown[], R>(fn: (...args: A) => Promise<R>): (...args: A) => Promise<R> {
  return useMemo(() => singleFlight(fn), [fn]);
}
