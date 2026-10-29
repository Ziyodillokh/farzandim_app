'use client';

import { BookMarked, Database, Languages, LogOut, Moon, Palette, RotateCcw, ShieldCheck, SlidersHorizontal, Sun, UserRound } from 'lucide-react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useTheme } from 'next-themes';
import type { ReactNode } from 'react';

import { signOut } from '@/auth/sign-in';
import { useSession } from '@/auth/use-session';
import { Section } from '@/components/common/section';
import { Button } from '@/components/ui/button';
import { isRegionId, regionName } from '@/data/reference/regions';
import { isDefaultFilters, resetFilters, useFilters, useScopeRegion } from '@/features/filters/store';
import { type Locale, useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

function Segmented<V extends string>({ value, options, onChange, label }: { value: V; options: Array<{ value: V; label: string; icon?: ReactNode }>; onChange: (v: V) => void; label: string }) {
  return (
    <div role="radiogroup" aria-label={label} className="inline-flex rounded-xl bg-primary/[0.05] p-1 ring-1 ring-inset ring-border/60 dark:bg-white/[0.04]">
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          role="radio"
          aria-checked={value === o.value}
          onClick={() => onChange(o.value)}
          className={cn(
            'inline-flex h-8 items-center gap-1.5 rounded-lg px-3 text-[0.8rem] font-semibold transition-all [&>svg]:h-3.5 [&>svg]:w-3.5',
            value === o.value ? 'bg-card text-foreground shadow-soft ring-1 ring-border/60' : 'text-muted-foreground hover:text-foreground',
          )}
        >
          {o.icon}
          {o.label}
        </button>
      ))}
    </div>
  );
}

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex flex-wrap items-center justify-between gap-3 border-b border-border/50 py-3 last:border-0 dark:border-white/[0.06]">
      <span className="text-[0.84rem] text-muted-foreground">{label}</span>
      <span className="text-[0.86rem] font-medium">{children}</span>
    </div>
  );
}

/** Sozlamalar: til, mavzu, doira va filtrlar, hisob, xavfsizlik va ma'lumot manbai. */
export function SettingsView() {
  const { t, locale, setLocale, formatDate } = useI18n();
  const { resolvedTheme, setTheme } = useTheme();
  const session = useSession();
  const router = useRouter();
  const [filters] = useFilters();
  const [region, setRegion] = useScopeRegion();
  const national = session?.role === 'NATIONAL';
  const scopeText = !national && session?.regionId ? regionName(session.regionId, locale) : isRegionId(region) ? regionName(region, locale) : t('shell.scopeNational');
  const filterText = [t(`enums.period.${filters.period}`), t(`enums.gradeBand.${filters.grades}`), t(`enums.gender.${filters.gender}`), t(`enums.schoolType.${filters.schoolType}`)].join(' · ');

  return (
    <div className="grid gap-5 xl:grid-cols-2">
      <Section icon={<Palette />} title={t('settings.appearance')} subtitle={t('settings.appearanceSub')}>
        <div className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <span className="flex items-center gap-2 text-[0.86rem] font-medium">
              <Languages className="h-4 w-4 text-primary" />
              {t('settings.language')}
            </span>
            <Segmented<Locale>
              label={t('settings.language')}
              value={locale}
              onChange={setLocale}
              options={[
                { value: 'uz', label: 'O\'zbekcha' },
                { value: 'ru', label: 'Русский' },
              ]}
            />
          </div>
          <div className="flex flex-wrap items-center justify-between gap-3">
            <span className="flex items-center gap-2 text-[0.86rem] font-medium">
              <Palette className="h-4 w-4 text-primary" />
              {t('settings.theme')}
            </span>
            <Segmented
              label={t('settings.theme')}
              value={resolvedTheme === 'light' ? 'light' : 'dark'}
              onChange={setTheme}
              options={[
                { value: 'dark', label: t('settings.themeDark'), icon: <Moon /> },
                { value: 'light', label: t('settings.themeLight'), icon: <Sun /> },
              ]}
            />
          </div>
        </div>
      </Section>

      <Section icon={<SlidersHorizontal />} title={t('settings.view')} subtitle={t('settings.viewSub')}>
        <Row label={t('settings.scope')}>{scopeText}</Row>
        <Row label={t('settings.filters')}>{filterText}</Row>
        <div className="mt-4 flex flex-wrap gap-2">
          <Button variant="outline" size="sm" className="rounded-xl" onClick={resetFilters} disabled={isDefaultFilters(filters)}>
            <RotateCcw />
            {isDefaultFilters(filters) ? t('settings.defaults') : t('settings.resetFilters')}
          </Button>
          {national && isRegionId(region) && (
            <Button variant="outline" size="sm" className="rounded-xl" onClick={() => setRegion('ALL')}>
              <RotateCcw />
              {t('settings.resetScope')}
            </Button>
          )}
        </div>
      </Section>

      <Section icon={<UserRound />} title={t('settings.account')} subtitle={t('settings.accountSub')}>
        {session && (
          <>
            <Row label={t('settings.login')}>@{session.username}</Row>
            <Row label={t('settings.role')}>{t(`settings.roles.${session.role}`)}</Row>
            <Row label={t('settings.signedIn')}>{formatDate(session.loggedInAt, 'd MMMM yyyy, HH:mm')}</Row>
          </>
        )}
        <Button
          variant="outline"
          size="sm"
          className="mt-4 rounded-xl"
          onClick={() => {
            signOut();
            router.replace('/login');
          }}
        >
          <LogOut />
          {t('settings.logout')}
        </Button>
        <div className="mt-5 flex gap-3 rounded-2xl bg-primary/[0.05] p-4 ring-1 ring-inset ring-primary/15 dark:bg-white/[0.03]">
          <ShieldCheck className="mt-0.5 h-5 w-5 shrink-0 text-primary" />
          <div>
            <p className="text-[0.86rem] font-semibold">{t('settings.security')}</p>
            <p className="mt-1 text-[0.8rem] leading-relaxed text-muted-foreground">{t('settings.securityText')}</p>
          </div>
        </div>
      </Section>

      <Section icon={<Database />} title={t('settings.data')}>
        <Row label={t('settings.dataSource')}>{t('settings.dataDemo')}</Row>
        <Row label={t('settings.dataOfficial')}>{t('settings.dataOfficialValue')}</Row>
        <Button asChild variant="outline" size="sm" className="mt-4 rounded-xl">
          <Link href="/methodology">
            <BookMarked />
            {t('settings.methodologyLink')}
          </Link>
        </Button>
      </Section>
    </div>
  );
}
