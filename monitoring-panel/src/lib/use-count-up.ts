'use client';

import { useEffect, useRef, useState } from 'react';

const DURATION_MS = 900;

/** Raqamning 0 dan (yoki oldingi qiymatdan) silliq o'sishi; `prefers-reduced-motion` da darhol. */
export function useCountUp(target: number | null | undefined): number | null {
  const [value, setValue] = useState<number | null>(target ?? null);
  const fromRef = useRef<number>(0);
  useEffect(() => {
    if (target === null || target === undefined) {
      setValue(null);
      return;
    }
    const reduce = typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    if (reduce) {
      setValue(target);
      fromRef.current = target;
      return;
    }
    const from = fromRef.current;
    const start = performance.now();
    let frame = 0;
    const tick = (now: number) => {
      const p = Math.min(1, (now - start) / DURATION_MS);
      const eased = 1 - (1 - p) ** 3;
      setValue(from + (target - from) * eased);
      if (p < 1) frame = requestAnimationFrame(tick);
      else fromRef.current = target;
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [target]);
  return value;
}
