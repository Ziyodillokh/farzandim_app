'use client';

import type { ReactNode } from 'react';

import { AuthGuard, HttpSessionGate, HydrationGate, RouteGuard } from '@/auth/guards';
import { AppShell } from '@/components/layout/app-shell';
import { BrandFromUrl } from '@/features/engine/brand-from-url';
import { DemoEngine } from '@/features/engine/demo-engine';
import { DemoPanel } from '@/features/engine/demo-panel';
import { isHttpMode } from '@/data/source';

export default function AppLayout({ children }: { children: ReactNode }) {
  return (
    <HydrationGate>
      {isHttpMode ? (
        <HttpSessionGate>
          <AuthGuard>
            <AppShell>
              <RouteGuard>{children}</RouteGuard>
            </AppShell>
          </AuthGuard>
        </HttpSessionGate>
      ) : (
        <>
          <BrandFromUrl />
          <AuthGuard>
            <DemoEngine />
            <DemoPanel />
            <AppShell>
              <RouteGuard>{children}</RouteGuard>
            </AppShell>
          </AuthGuard>
        </>
      )}
    </HydrationGate>
  );
}
