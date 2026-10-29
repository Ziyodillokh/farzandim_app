'use client';

import type { ReactNode } from 'react';

import { HydrationGate } from '@/auth/guards';
import { ParvozLogo } from '@/components/layout/parvoz-logo';
import { CosmicBackdrop } from '@/features/auth/components/cosmic-backdrop';

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <>
      {/* Gidratatsiyadan oldin ham ko'rinadi (statik HTML) */}
      <CosmicBackdrop />
      <HydrationGate
        fallback={
          <div className="flex min-h-screen items-center justify-center">
            <ParvozLogo decorative className="h-14 w-14 animate-pulse rounded-2xl shadow-primary-glow" />
          </div>
        }
      >
        {children}
      </HydrationGate>
    </>
  );
}
