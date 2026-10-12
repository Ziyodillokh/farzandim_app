'use client';

import { LayoutDashboard, Maximize, Minimize, UserCheck } from 'lucide-react';
import Link from 'next/link';
import { useEffect, useState } from 'react';

import { getSessionScope } from '@/auth/session';
import { useSession } from '@/auth/use-session';
import { SchoolLogo } from '@/components/common/school-logo';
import { ParvozWordmark } from '@/components/layout/parvoz-wordmark';
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
  const session = useSession();
  // Demo: kiosk shu tabning (navbatchi) sessiyasida ishlayapti.
  const asDuty = session?.role === 'DUTY' && getSessionScope() === 'tab';
  const control =
    'flex h-10 w-10 items-center justify-center rounded-xl border border-white/10 bg-white/[0.06] text-white/75 transition-colors hover:border-brand-400/40 hover:bg-white/[0.12] hover:text-white';

  return (
    <header className="flex shrink-0 flex-wrap items-center justify-between gap-x-6 gap-y-3">
      <div className="flex min-w-0 items-center gap-4">
        <SchoolLogo school={data?.school} className="h-12 w-12 rounded-2xl shadow-[0_8px_24px_-10px_rgba(60,130,255,0.6)] xl:h-14 xl:w-14" />
        <div className="min-w-0">
          <p className="truncate font-display text-lg font-semibold tracking-[-0.01em] md:text-xl xl:text-2xl">{data?.school.name ?? '…'}</p>
          <p className="mt-0.5 flex items-center gap-2 text-sm text-white/65">
            <span className="h-1.5 w-1.5 rounded-full bg-brand-400 shadow-[0_0_8px_2px_rgba(80,138,255,0.6)]" aria-hidden />
            {t('attendance.kiosk.title')}
            {data?.school.city && ` · ${data.school.city}`}
            {asDuty && (
              <span className="ml-1 inline-flex items-center gap-1 rounded-full bg-cyan-400/15 px-2 py-0.5 text-xs font-semibold text-cyan-200 ring-1 ring-inset ring-cyan-300/30">
                <UserCheck className="h-3 w-3" aria-hidden />
                {t('demo.kioskChip')}
              </span>
            )}
          </p>
        </div>
      </div>

      <div className="text-right md:text-center">
        <p className="font-display text-[clamp(2.5rem,7dvh,3.75rem)] font-semibold leading-none tracking-[-0.02em] tabular-nums">
          {formatDate(now, 'HH:mm')}
          <span className="ml-1 text-[0.5em] text-brand-300/60">{formatDate(now, 'ss')}</span>
        </p>
        <p className="mt-1.5 text-sm capitalize text-white/65">{formatDate(now, 'd MMMM, EEEE')}</p>
      </div>

      <div className="flex items-center gap-2">
        <ParvozWordmark size="sm" sub="School" tone="onDark" className="mr-2 hidden opacity-90 lg:inline-flex" />
        <span aria-hidden className="mr-1 hidden h-8 w-px bg-white/10 lg:block" />
        <div className="flex h-10 items-center rounded-xl border border-white/10 bg-white/[0.06] p-1">
          {LOCALES.map((l) => (
            <button
              key={l}
              type="button"
              onClick={() => setLocale(l)}
              className={cn('h-8 rounded-lg px-3 text-sm font-semibold uppercase transition-colors', locale === l ? 'bg-white text-brand-950' : 'text-white/65 hover:text-white')}
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
