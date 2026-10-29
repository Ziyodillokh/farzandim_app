'use client';

import type { ReactNode } from 'react';

import { Sidebar } from './sidebar';
import { Topbar } from './topbar';

/** Aurora + "buyruq markazi" to'ri (fiksirlangan, blursiz), suzuvchi shisha sidebar va topbar. */
export function AppShell({ children }: { children: ReactNode }) {
  return (
    <div className="relative isolate flex min-h-screen">
      <div aria-hidden className="aurora-bg no-print" />
      <div aria-hidden className="cc-grid no-print" />
      <Sidebar />
      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar />
        <main className="mx-auto w-full max-w-[1600px] flex-1 px-4 pb-12 pt-6 md:px-6 lg:px-8">{children}</main>
      </div>
    </div>
  );
}
