'use client';

import { useEffect, useState } from 'react';

type WakeLockSentinel = { release(): Promise<void> };
type WakeLockApi = { request(type: 'screen'): Promise<WakeLockSentinel> };

/**
 * Kiosk ochiq turganda ekran o'chmasin (Screen Wake Lock, Chrome/Edge). Brauzer qulfni
 * sahifa yashirilganda bo'shatadi — qaytganda qayta so'raladi. Qo'llanmasa — kiosk
 * ishlayveradi, faqat ekran tizim sozlamasi bo'yicha o'chishi mumkin.
 */
export function useScreenWakeLock() {
  useEffect(() => {
    const api = (navigator as Navigator & { wakeLock?: WakeLockApi }).wakeLock;
    if (!api) return;
    let lock: WakeLockSentinel | null = null;
    let disposed = false;
    const acquire = async () => {
      if (document.visibilityState !== 'visible') return;
      try {
        const next = await api.request('screen');
        if (disposed) void next.release();
        else lock = next;
      } catch (error) {
        console.warn('[kiosk] wake lock rad etildi', error);
      }
    };
    void acquire();
    document.addEventListener('visibilitychange', acquire);
    return () => {
      disposed = true;
      document.removeEventListener('visibilitychange', acquire);
      void lock?.release();
    };
  }, []);
}

/** Brauzer oynasi faolmi: USB o'qigich faqat faol oynaga "yozadi". */
export function useWindowFocused(): boolean {
  const [focused, setFocused] = useState(true);
  useEffect(() => {
    const sync = () => setFocused(document.hasFocus());
    sync();
    window.addEventListener('focus', sync);
    window.addEventListener('blur', sync);
    return () => {
      window.removeEventListener('focus', sync);
      window.removeEventListener('blur', sync);
    };
  }, []);
  return focused;
}
