'use client';

import type { ReactNode } from 'react';

import { HydrationGate } from '@/auth/guards';
import { BrandFromUrl } from '@/features/engine/brand-from-url';

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <HydrationGate>
      <BrandFromUrl />
      {children}
    </HydrationGate>
  );
}
