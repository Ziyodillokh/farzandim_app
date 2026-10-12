'use client';

import { useEffect, useState, type ReactNode } from 'react';

import { FullScreenLoader } from '@/auth/guards';
import { acceptKioskDemoParam } from './kiosk-launch';

/**
 * Kiosk sahifasi: `?as=navbatchi` (demo panel launcher) bo'lsa, AuthGuard'dan
 * OLDIN shu tabni navbatchi sifatida kiritadi va so'rov qatorini tozalaydi.
 */
export function KioskDemoEntry({ children }: { children: ReactNode }) {
  const [ready, setReady] = useState(false);
  useEffect(() => {
    // Takroriy chaqiruv xavfsiz: birinchisi `?as=` ni olib tashlaydi.
    acceptKioskDemoParam();
    setReady(true);
  }, []);
  if (!ready) return <FullScreenLoader />;
  return <>{children}</>;
}
