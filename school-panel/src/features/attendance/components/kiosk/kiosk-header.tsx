'use client';

import { LayoutDashboard, Maximize, Minimize } from 'lucide-react';
import Link from 'next/link';
import { useEffect, useState } from 'react';

import { SchoolLogo } from '@/components/common/school-logo';
import { ParvozLogo } from '@/components/layout/parvoz-logo';
import { useClockNow } from '@/features/engine/use-clock';
import { useSchool } from '@/features/school/hooks';
import { LOCALES, useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

function useFullscreen(): [boolean, () => void] {
  const [active, setActive] = useState(false);
  useEffect(() => {
    const sync = () => setActive(Boolean(document.fullscreenElement));
    sync();
    document.addEventListener('fullscreenchange', sync);
    return () => document.removeEventListener('fullscreenchange', sync);
  }, []);
  const toggle = () => {
    const request = document.fullscreenElement ? document.exitFullscreen() : document.documentElement.requestFullscreen();
    // Brauzer rad etsa (masalan, iframe) — oddiy rejimda qolamiz.
    request.catch(() => setActive(Boolean(document.fullscreenElement)));
  };
  return [active, toggle];
}

/** Kiosk sarlavhasi: maktab, katta jonli soat, til va to'liq ekran. */
export function KioskHeader() {
  const { t, locale, setLocale, formatDate } = useI18n();
  const { data } = useSchool();
  const now = useClockNow(1000);
  const [fullscreen, toggleFullscreen] = useFullscreen();
  const control = 'flex h-11 w-11 items-center justify-center rounded-xl border border-white/10 bg-white/[0.06] text-white/75 transition-colors hover:bg-white/[0.12] hover:text-white';

  return (
    <header className="flex flex-wrap items-center justify-between gap-6">
      <div className="flex min-w-0 items-center gap-4">
        <SchoolLogo school={data?.school} className="h-14 w-14 rounded-2xl" />
        <div className="min-w-0">
          <p className="truncate font-display text-xl font-semibold md:text-2xl">{data?.school.name ?? '…'}</p>
          <p className="flex items-center gap-2 text-sm text-white/60">
            <ParvozLogo className="h-4 w-4 rounded" />
            {t('attendance.kiosk.title')}
            {data?.school.city && ` · ${data.school.city}`}
          </p>
        </div>
      </div>

      <div className="text-right">
        <p className="font-display text-5xl font-semibold leading-none tabular-nums md:text-6xl">
          {formatDate(now, 'HH:mm')}
          <span className="ml-1 text-2xl text-white/40 md:text-3xl">{formatDate(now, 'ss')}</span>
        </p>
        <p className="mt-1.5 text-sm capitalize text-white/60">{formatDate(now, 'd MMMM, EEEE')}</p>
      </div>

      <div className="flex items-center gap-2">
        <div className="flex h-11 items-center rounded-xl border border-white/10 bg-white/[0.06] p-1">
          {LOCALES.map((l) => (
            <button
              key={l}
              type="button"
              onClick={() => setLocale(l)}
              className={cn('h-9 rounded-lg px-3 text-sm font-semibold uppercase transition-colors', locale === l ? 'bg-white text-[#060B16]' : 'text-white/65 hover:text-white')}
            >
              {l}
            </button>
          ))}
        </div>
        <button type="button" onClick={toggleFullscreen} className={control} aria-label={t(fullscreen ? 'attendance.kiosk.exitFullscreen' : 'attendance.kiosk.fullscreen')}>
          {fullscreen ? <Minimize className="h-5 w-5" /> : <Maximize className="h-5 w-5" />}
        </button>
        <Link href="/dashboard" className={control} aria-label={t('attendance.kiosk.backToPanel')} title={t('attendance.kiosk.backToPanel')}>
          <LayoutDashboard className="h-5 w-5" />
        </Link>
      </div>
    </header>
  );
}
