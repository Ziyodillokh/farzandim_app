import { useEffect, useState } from 'react';

/** Qiymatni `delayMs` jim turgandan keyin qaytaradi (qidiruv so'rovlari uchun). */
export function useDebouncedValue<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(timer);
  }, [value, delayMs]);

  return debounced;
}
