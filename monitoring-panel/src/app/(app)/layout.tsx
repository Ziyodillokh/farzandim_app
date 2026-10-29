'use client';

import type { ReactNode } from 'react';

import { AuthGuard, HydrationGate, RouteGuard } from '@/auth/guards';
import { AppShell } from '@/components/layout/app-shell';

export default function AppLayout({ children }: { children: ReactNode }) {
  return (
    <HydrationGate>
      <AuthGuard>
        <AppShell>
          <RouteGuard>{children}</RouteGuard>
        </AppShell>
      </AuthGuard>
    </HydrationGate>
  );
}
