'use client';

import type { ReactNode } from 'react';

import { ProfileDialogProvider } from '@/features/profile/components/profile-dialog-context';
import { Sidebar } from './sidebar';
import { Topbar } from './topbar';

/** Aurora fon (fiksirlangan, blursiz) + suzuvchi shisha sidebar va topbar. */
export function AppShell({ children }: { children: ReactNode }) {
  return (
    <ProfileDialogProvider>
      <div className="relative isolate flex min-h-screen">
        <div aria-hidden className="aurora-bg no-print" />
        <Sidebar />
        <div className="flex min-w-0 flex-1 flex-col">
          <Topbar />
          <main className="mx-auto w-full max-w-[1440px] flex-1 px-4 pb-10 pt-6 md:px-6 lg:px-8">{children}</main>
        </div>
      </div>
    </ProfileDialogProvider>
  );
}
