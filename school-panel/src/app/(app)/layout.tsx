'use client';

import type { ReactNode } from 'react';

import { AuthGuard, HydrationGate, RouteGuard } from '@/auth/guards';
import { AppShell } from '@/components/layout/app-shell';
import { BrandFromUrl } from '@/features/engine/brand-from-url';
import { DemoEngine } from '@/features/engine/demo-engine';
import { DemoPanel } from '@/features/engine/demo-panel';

export default function AppLayout({ children }: { children: ReactNode }) {
  return (
    <HydrationGate>
      <BrandFromUrl />
      <AuthGuard>
        <DemoEngine />
        <DemoPanel />
        <AppShell>
          <RouteGuard>{children}</RouteGuard>
        </AppShell>
      </AuthGuard>
    </HydrationGate>
  );
}
