'use client';

import { Menu, Moon, Search, SlidersHorizontal, Sun } from 'lucide-react';
import { useTheme } from 'next-themes';
import { useState } from 'react';

import { DemoBadge } from '@/components/common/demo-badge';
import { Button } from '@/components/ui/button';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { Sheet, SheetContent, SheetTitle } from '@/components/ui/sheet';
import { FilterBar } from '@/features/filters/filter-bar';
import { useI18n, type Locale } from '@/i18n';
import { cn } from '@/lib/utils';
import { CommandPalette } from './command-palette';
import { ParvozWordmark } from './parvoz-wordmark';
import { SidebarContent } from './sidebar';
import { UserMenu } from './user-menu';

function LanguageSwitch() {
  const { locale, setLocale, t } = useI18n();
  const options: Locale[] = ['uz', 'ru'];
  return (
    <div className="flex h-9 items-center rounded-xl bg-primary/[0.05] p-1 ring-1 ring-inset ring-border/60 dark:bg-white/[0.04]" role="group" aria-label={t('shell.language')}>
      {options.map((l) => (
        <button
          key={l}
          type="button"
          onClick={() => setLocale(l)}
          className={cn(
            'h-7 rounded-lg px-2.5 text-xs font-semibold uppercase transition-all',
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
  const dark = resolvedTheme !== 'light';
  return (
    <Button variant="ghost" size="icon" className="h-9 w-9 rounded-xl" onClick={() => setTheme(dark ? 'light' : 'dark')} aria-label={t('shell.theme')} title={t('shell.theme')}>
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
        <FilterBar className="hidden min-[1360px]:flex" />
        <Popover>
          <PopoverTrigger asChild>
            <Button variant="ghost" size="sm" className="h-9 gap-1.5 rounded-xl px-3 ring-1 ring-inset ring-border/60 min-[1360px]:hidden">
              <SlidersHorizontal className="h-4 w-4" />
              <span className="hidden sm:inline">{t('shell.filters')}</span>
            </Button>
          </PopoverTrigger>
          <PopoverContent align="start" className="w-72 p-3">
            <FilterBar stacked />
          </PopoverContent>
        </Popover>
        <div className="ml-auto flex items-center gap-1.5">
          <DemoBadge compact className="hidden md:inline-flex" />
          <button
            type="button"
            onClick={() => setSearchOpen(true)}
            aria-label={t('shell.searchHint')}
            className="flex h-9 w-9 items-center justify-center rounded-xl text-muted-foreground ring-1 ring-inset ring-border/60 transition-colors hover:text-foreground hover:ring-primary/40"
          >
            <Search className="h-4 w-4" />
          </button>
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
