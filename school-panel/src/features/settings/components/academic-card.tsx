'use client';

import { differenceInCalendarDays } from 'date-fns';
import { Clock3 } from 'lucide-react';

import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import type { School, Shift } from '@/data/contracts';
import { fromIsoDate, toIsoDate } from '@/data/mock/calendar';
import { useClockNow } from '@/features/engine/use-clock';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

const CLOCK_TICK_MS = 60_000;

export function AcademicCard({ school, shifts }: { school: School; shifts: Shift[] }) {
  const { t, formatDate } = useI18n();
  const today = toIsoDate(useClockNow(CLOCK_TICK_MS));

  return (
    <SectionCard
      title={t('settings.academic.title')}
      description={t('settings.academic.description')}
      actions={<Badge variant="default">{t('settings.academic.year', { year: school.academicYear })}</Badge>}
    >
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {school.quarters.map((q) => {
          const current = today >= q.start && today <= q.end;
          return (
            <div key={q.no} className={cn('rounded-xl border p-4 transition-colors', current && 'border-primary/50 bg-primary/5 shadow-primary-glow')}>
              <div className="flex items-center justify-between gap-2">
                <p className="font-display text-sm font-semibold">{t('settings.academic.quarter', { no: q.no })}</p>
                {current && <Badge size="sm">{t('settings.academic.current')}</Badge>}
              </div>
              <p className="mt-2 text-sm tabular-nums">
                {formatDate(fromIsoDate(q.start), 'd MMM')} — {formatDate(fromIsoDate(q.end), 'd MMM yyyy')}
              </p>
              <p className="mt-1 text-xs text-muted-foreground">
                {t('settings.academic.days', { count: differenceInCalendarDays(fromIsoDate(q.end), fromIsoDate(q.start)) + 1 })}
              </p>
            </div>
          );
        })}
      </div>

      <p className="mb-2 mt-6 text-2xs font-semibold uppercase tracking-wide text-muted-foreground">{t('settings.academic.shifts')}</p>
      <div className="grid gap-3 sm:grid-cols-2">
        {shifts.map((s) => (
          <div key={s.id} className="flex items-center gap-3 rounded-xl border p-4">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
              <Clock3 className="h-5 w-5" />
            </div>
            <div className="min-w-0">
              <p className="font-semibold">
                {s.name} <span className="font-normal tabular-nums text-muted-foreground">· {s.start}–{s.end}</span>
              </p>
              <p className="text-xs text-muted-foreground">
                {s.weekdays.map((d) => t(`enums.weekdayShort.${d}`)).join(', ')} ·{' '}
                {t('settings.academic.lessons', { count: s.periods.filter((p) => p.kind === 'LESSON').length })}
              </p>
            </div>
          </div>
        ))}
      </div>
    </SectionCard>
  );
}
