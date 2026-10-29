'use client';

import { ThemeProvider } from 'next-themes';
import type { ReactNode } from 'react';
import { Toaster } from 'sonner';

import { TooltipProvider } from '@/components/ui/tooltip';
import { I18nProvider } from '@/i18n';
import { QueryProvider } from './query-provider';

/** Mavzu kaliti alohida: bir domendagi maktab paneli bilan aralashmasin. Standart — qorong'i ("buyruq markazi"). */
export const THEME_STORAGE_KEY = 'parvoz-monitoring:theme';

export function AppProviders({ children }: { children: ReactNode }) {
  return (
    <ThemeProvider attribute="class" defaultTheme="dark" enableSystem={false} storageKey={THEME_STORAGE_KEY} disableTransitionOnChange>
      <I18nProvider>
        <QueryProvider>
          <TooltipProvider delayDuration={150}>{children}</TooltipProvider>
          <Toaster richColors closeButton position="top-right" />
        </QueryProvider>
      </I18nProvider>
    </ThemeProvider>
  );
}
