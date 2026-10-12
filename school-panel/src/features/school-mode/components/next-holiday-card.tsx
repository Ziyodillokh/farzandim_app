'use client';

import { CalendarOff, PartyPopper } from 'lucide-react';

import { Card } from '@/components/ui/card';
import type { Holiday } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { localDate, TONE_ORB } from '../lib';

const DAY_MS = 86_400_000;

/** Keyingi dam olish kuni — shisha banner: kalendar varag'i, nomi va qolgan kunlar. */
export function NextHolidayCard({ next, today }: { next: Holiday | undefined; today: string }) {
  const { t, tc, formatDate } = useI18n();
  if (!next) {
    return (
      <Card className="mb-6 flex items-center gap-3 p-5 text-sm text-muted-foreground">
        <span className={cn('flex h-9 w-9 items-center justify-center rounded-xl ring-1 ring-inset', TONE_ORB.muted)}>
          <CalendarOff className="h-4 w-4" aria-hidden />
        </span>
        {t('schoolMode.holidays.noUpcoming')}
      </Card>
    );
  }
  const date = localDate(next.date);
  const days = Math.round((date.getTime() - localDate(today).getTime()) / DAY_MS);
  return (
    <Card className="relative mb-6 overflow-hidden animate-fade-in">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 bg-[radial-gradient(55%_140%_at_0%_0%,hsl(var(--primary)/0.16),transparent_62%),radial-gradient(40%_120%_at_100%_100%,hsl(192_90%_50%/0.12),transparent_70%)]"
      />
      <PartyPopper aria-hidden className="pointer-events-none absolute -right-6 -top-8 h-44 w-44 text-primary opacity-[0.05]" />
      <div className="relative flex flex-wrap items-center gap-5 p-6">
        <div className="flex w-20 shrink-0 flex-col overflow-hidden rounded-2xl bg-card text-center shadow-soft ring-1 ring-border/60">
          <span className="bg-primary/10 py-1 text-2xs font-semibold uppercase tracking-wider text-primary">{formatDate(date, 'LLL')}</span>
          <span className="py-1.5 font-display text-3xl font-semibold leading-none tabular-nums">{formatDate(date, 'd')}</span>
          <span className="pb-1.5 text-2xs uppercase text-muted-foreground">{formatDate(date, 'EEEEEE')}</span>
        </div>
        <div className="min-w-0 flex-1">
          <p className="text-xs font-semibold uppercase tracking-[0.14em] text-muted-foreground">{t('schoolMode.holidays.next')}</p>
          <p className="mt-1.5 font-display text-2xl font-semibold tracking-[-0.02em] md:text-[1.75rem]">{next.name}</p>
          <p className="mt-1 text-sm text-muted-foreground">{formatDate(date, 'd MMMM yyyy, EEEE')}</p>
        </div>
        <span className="rounded-full bg-primary/10 px-4 py-1.5 text-sm font-semibold text-primary ring-1 ring-inset ring-primary/20">
          {days === 0 ? t('schoolMode.holidays.today') : tc('schoolMode.holidays.inDays', days)}
        </span>
      </div>
    </Card>
  );
}
