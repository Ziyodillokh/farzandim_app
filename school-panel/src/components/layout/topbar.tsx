'use client';

import { Menu, Moon, Search, Sun } from 'lucide-react';
import { useTheme } from 'next-themes';
import { useState } from 'react';

import { Button } from '@/components/ui/button';
import { Sheet, SheetContent, SheetTitle } from '@/components/ui/sheet';
import { useI18n, type Locale } from '@/i18n';
import { cn } from '@/lib/utils';
import { isHttpMode } from '@/data/source';
import { DemoButton } from '@/features/engine/demo-button';
import { NotificationBell } from '@/features/notifications/components/notification-bell';
import { ClockWidget } from './clock-widget';
import { CommandPalette } from './command-palette';
import { ParvozWordmark } from './parvoz-wordmark';
import { SidebarContent } from './sidebar';
import { UserMenu } from './user-menu';

function LanguageSwitch() {
  const { locale, setLocale, t } = useI18n();
  const options: Locale[] = ['uz', 'ru'];
  return (
    <div className="flex h-10 items-center rounded-xl bg-primary/[0.05] p-1 ring-1 ring-inset ring-border/60 dark:bg-white/[0.04]" role="group" aria-label={t('shell.language')}>
      {options.map((l) => (
        <button
          key={l}
          type="button"
          onClick={() => setLocale(l)}
          className={cn(
            'h-8 rounded-lg px-2.5 text-xs font-semibold uppercase transition-all',
            locale === l ? 'bg-card text-foreground shadow-soft ring-1 ring-border/60' : 'text-muted-foreground hover:text-foreground',
          )}
          aria-pressed={locale === l}
        >
          {l === 'uz' ? 'UZ' : 'RU'}
        </button>
      ))}
    </div>
  );
}

function ThemeToggle() {
  const { resolvedTheme, setTheme } = useTheme();
  const { t } = useI18n();
  const dark = resolvedTheme === 'dark';
  return (
    <Button variant="ghost" size="icon" className="rounded-xl" onClick={() => setTheme(dark ? 'light' : 'dark')} aria-label={t('shell.theme')} title={t('shell.theme')}>
      {dark ? <Sun /> : <Moon />}
    </Button>
  );
}

export function Topbar() {
  const { t } = useI18n();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);

  return (
    <header className="sticky top-0 z-30 px-3 pt-3 md:px-6 lg:pl-4 lg:pr-8 no-print">
      <div className="glass-bar flex h-14 items-center gap-2 rounded-2xl px-2.5">
        <Button variant="ghost" size="icon" className="rounded-xl lg:hidden" onClick={() => setMobileOpen(true)} aria-label={t('shell.expand')}>
          <Menu />
        </Button>
        <ParvozWordmark size="xs" className="mr-1 hidden sm:inline-flex lg:hidden" />
        <button
          type="button"
          onClick={() => setSearchOpen(true)}
          aria-label={t('shell.searchHint')}
          className="flex h-10 w-10 shrink-0 items-center justify-center gap-2 rounded-xl bg-white/60 text-sm text-muted-foreground ring-1 ring-inset ring-border/60 transition-colors hover:ring-primary/40 dark:bg-white/[0.04] sm:w-auto sm:min-w-0 sm:flex-1 sm:shrink sm:justify-start sm:px-3 md:max-w-md"
        >
          <Search className="h-4 w-4 shrink-0" />
          <span className="hidden truncate sm:inline">{t('shell.searchHint')}</span>
          <kbd className="ml-auto hidden rounded-md bg-primary/[0.06] px-1.5 py-0.5 text-2xs font-semibold ring-1 ring-inset ring-border/60 dark:bg-white/[0.06] md:inline">{t('shell.searchShortcut')}</kbd>
        </button>
        <div className="ml-auto flex items-center gap-1.5">
          {!isHttpMode && <DemoButton />}
          <NotificationBell />
          {!isHttpMode && <ClockWidget />}
          <span className="hidden sm:block">
            <LanguageSwitch />
          </span>
          <ThemeToggle />
          <span className="mx-1 hidden h-6 w-px bg-border/70 sm:block" />
          <UserMenu variant="topbar" />
        </div>
      </div>
      <CommandPalette open={searchOpen} onOpenChange={setSearchOpen} />
      <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
        <SheetContent side="left" className="w-[296px] border-0 bg-transparent p-0 shadow-none backdrop-blur-none" closeClassName="text-white">
          <SheetTitle className="sr-only">{t('shell.expand')}</SheetTitle>
          <div className="glass-nav h-full overflow-hidden rounded-3xl">
            <SidebarContent onNavigate={() => setMobileOpen(false)} />
          </div>
        </SheetContent>
      </Sheet>
    </header>
  );
}
