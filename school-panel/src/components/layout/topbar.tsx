'use client';

import { Menu, Moon, Search, Sun } from 'lucide-react';
import { useTheme } from 'next-themes';
import { useState } from 'react';

import { Button } from '@/components/ui/button';
import { Sheet, SheetContent, SheetTitle } from '@/components/ui/sheet';
import { useI18n, type Locale } from '@/i18n';
import { cn } from '@/lib/utils';
import { ClockWidget } from './clock-widget';
import { CommandPalette } from './command-palette';
import { SidebarContent } from './sidebar';

function LanguageSwitch() {
  const { locale, setLocale, t } = useI18n();
  const options: Locale[] = ['uz', 'ru'];
  return (
    <div className="flex h-10 items-center rounded-lg border p-1" role="group" aria-label={t('shell.language')}>
      {options.map((l) => (
        <button
          key={l}
          type="button"
          onClick={() => setLocale(l)}
          className={cn(
            'h-8 rounded-md px-2.5 text-xs font-semibold uppercase transition-colors',
            locale === l ? 'bg-primary text-primary-foreground shadow-soft' : 'text-muted-foreground hover:text-foreground',
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
    <Button variant="outline" size="icon" onClick={() => setTheme(dark ? 'light' : 'dark')} aria-label={t('shell.theme')} title={t('shell.theme')}>
      {dark ? <Sun /> : <Moon />}
    </Button>
  );
}

export function Topbar() {
  const { t } = useI18n();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);

  return (
    <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b bg-background/80 px-4 backdrop-blur-xl md:px-6 no-print">
      <Button variant="outline" size="icon" className="lg:hidden" onClick={() => setMobileOpen(true)} aria-label={t('shell.expand')}>
        <Menu />
      </Button>
      <button
        type="button"
        onClick={() => setSearchOpen(true)}
        className="flex h-10 min-w-0 flex-1 items-center gap-2 rounded-lg border bg-card px-3 text-sm text-muted-foreground transition-colors hover:border-primary/40 md:max-w-md"
      >
        <Search className="h-4 w-4 shrink-0" />
        <span className="truncate">{t('shell.searchHint')}</span>
        <kbd className="ml-auto hidden rounded border bg-muted px-1.5 py-0.5 text-2xs font-semibold md:inline">{t('shell.searchShortcut')}</kbd>
      </button>
      <div className="ml-auto flex items-center gap-2">
        <span className="hidden rounded-full border border-warning/40 bg-warning/10 px-2.5 py-1 text-2xs font-semibold text-warning xl:inline">
          {t('common.demoBadge')}
        </span>
        <ClockWidget />
        <LanguageSwitch />
        <ThemeToggle />
      </div>
      <CommandPalette open={searchOpen} onOpenChange={setSearchOpen} />
      <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
        <SheetContent side="left" className="w-[280px] border-0 p-0">
          <SheetTitle className="sr-only">{t('shell.expand')}</SheetTitle>
          <SidebarContent onNavigate={() => setMobileOpen(false)} />
        </SheetContent>
      </Sheet>
    </header>
  );
}
