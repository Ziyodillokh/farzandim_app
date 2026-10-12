'use client';

import { Languages, Monitor, Moon, Palette, Sun } from 'lucide-react';
import { useTheme } from 'next-themes';
import { useEffect, useState, type ComponentType, type ReactNode } from 'react';

import { SectionCard } from '@/components/common/section-card';
import { type Locale, LOCALES, useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

type ThemeKey = 'light' | 'dark' | 'system';

const THEMES: Array<{ key: ThemeKey; icon: ComponentType<{ className?: string }> }> = [
  { key: 'light', icon: Sun },
  { key: 'dark', icon: Moon },
  { key: 'system', icon: Monitor },
];

const THEME_LABEL = { light: 'shell.themeLight', dark: 'shell.themeDark', system: 'shell.themeSystem' } as const;

function Segmented({ label, icon, children }: { label: string; icon: ReactNode; children: ReactNode }) {
  return (
    <div className="space-y-2">
      <p className="flex items-center gap-2 text-sm font-medium [&_svg]:h-4 [&_svg]:w-4 [&_svg]:text-muted-foreground">
        {icon}
        {label}
      </p>
      <div className="grid auto-cols-fr grid-flow-col gap-1 rounded-lg border bg-muted/40 p-1" role="group" aria-label={label}>
        {children}
      </div>
    </div>
  );
}

function Option({ active, onClick, children }: { active: boolean; onClick: () => void; children: ReactNode }) {
  return (
    <button
      type="button"
      aria-pressed={active}
      onClick={onClick}
      className={cn(
        'flex h-9 items-center justify-center gap-1.5 rounded-md px-2 text-sm font-medium transition-all [&_svg]:h-4 [&_svg]:w-4',
        active ? 'bg-card text-foreground shadow-soft' : 'text-muted-foreground hover:text-foreground',
      )}
    >
      {children}
    </button>
  );
}

/** Til va mavzu — shu brauzerda eslab qolinadi. */
export function PreferencesCard() {
  const { t, locale, setLocale } = useI18n();
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  return (
    <SectionCard title={t('settings.prefs.title')} description={t('settings.prefs.description')}>
      <div className="space-y-5">
        <Segmented label={t('settings.prefs.language')} icon={<Languages />}>
          {LOCALES.map((l: Locale) => (
            <Option key={l} active={locale === l} onClick={() => setLocale(l)}>
              {t(`settings.prefs.${l}`)}
            </Option>
          ))}
        </Segmented>
        <Segmented label={t('settings.prefs.theme')} icon={<Palette />}>
          {THEMES.map(({ key, icon: Icon }) => (
            <Option key={key} active={mounted && theme === key} onClick={() => setTheme(key)}>
              <Icon />
              {t(THEME_LABEL[key])}
            </Option>
          ))}
        </Segmented>
      </div>
    </SectionCard>
  );
}
