'use client';

import { CalendarHeart, Plus, Trash2 } from 'lucide-react';
import { useMemo, useState } from 'react';

import { Can } from '@/auth/can';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import type { Holiday } from '@/data/contracts';
import { useClockNow } from '@/features/engine/use-clock';
import { useSchool } from '@/features/school/hooks';
import { HolidayDialog } from '@/features/school-mode/components/holiday-dialog';
import { NextHolidayCard } from '@/features/school-mode/components/next-holiday-card';
import { useRemoveHoliday } from '@/features/school-mode/hooks';
import { localDate, TONE_ORB } from '@/features/school-mode/lib';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

function groupByMonth(holidays: readonly Holiday[]): Array<[string, Holiday[]]> {
  const groups = new Map<string, Holiday[]>();
  for (const h of [...holidays].sort((a, b) => a.date.localeCompare(b.date))) {
    const key = h.date.slice(0, 7);
    groups.set(key, [...(groups.get(key) ?? []), h]);
  }
  return [...groups.entries()];
}

export default function SchoolModeHolidaysPage() {
  const { t, tc, formatDate } = useI18n();
  const school = useSchool();
  const remove = useRemoveHoliday();
  const now = useClockNow(60_000);
  const today = formatDate(now, 'yyyy-MM-dd');
  const [addOpen, setAddOpen] = useState(false);
  const [removing, setRemoving] = useState<Holiday | null>(null);

  const holidays = useMemo(() => school.data?.holidays ?? [], [school.data?.holidays]);
  const groups = useMemo(() => groupByMonth(holidays), [holidays]);
  const next = holidays.filter((h) => h.date >= today).sort((a, b) => a.date.localeCompare(b.date))[0];

  return (
    <>
      <PageHeader
        title={t('schoolMode.holidays.title')}
        subtitle={t('schoolMode.holidays.subtitle')}
        badge={holidays.length > 0 ? <Badge variant="secondary">{tc('schoolMode.holidays.total', holidays.length)}</Badge> : undefined}
        actions={
          <Can perm="schoolMode.manage">
            <Button onClick={() => setAddOpen(true)}>
              <Plus />
              {t('schoolMode.holidays.add')}
            </Button>
          </Can>
        }
      />

      {school.isError ? (
        <ErrorState error={school.error} onRetry={() => void school.refetch()} />
      ) : school.isLoading ? (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-40 rounded-2xl" />
          ))}
        </div>
      ) : holidays.length === 0 ? (
        <EmptyState icon={<CalendarHeart />} title={t('schoolMode.holidays.empty')} description={t('schoolMode.holidays.emptyHint')} />
      ) : (
        <>
          <NextHolidayCard next={next} today={today} />
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {groups.map(([month, items]) => (
              <SectionCard
                key={month}
                className={cn('animate-slide-up', items.every((h) => h.date < today) && 'opacity-70')}
                title={<span className="capitalize">{formatDate(localDate(`${month}-01`), 'LLLL yyyy')}</span>}
                actions={
                  <Badge variant="secondary" size="sm" className="tabular-nums">
                    {items.length}
                  </Badge>
                }
                bodyClassName="p-3"
              >
                <ul className="space-y-1">
                  {items.map((h) => {
                    const past = h.date < today;
                    const isToday = h.date === today;
                    const isNext = h.id === next?.id;
                    const date = localDate(h.date);
                    return (
                      <li
                        key={h.id}
                        className={cn('group flex items-center gap-3 rounded-xl px-2 py-2 transition-colors hover:bg-primary/[0.04]', isNext && 'bg-primary/[0.06] ring-1 ring-inset ring-primary/25')}
                      >
                        <div className={cn('flex h-11 w-11 shrink-0 flex-col items-center justify-center rounded-xl ring-1 ring-inset', past ? TONE_ORB.muted : TONE_ORB.primary)}>
                          <span className="font-display text-base font-semibold leading-none">{formatDate(date, 'd')}</span>
                          <span className="mt-0.5 text-2xs uppercase">{formatDate(date, 'EEEEEE')}</span>
                        </div>
                        <p className={cn('min-w-0 flex-1 truncate text-sm font-medium', past && 'text-muted-foreground')} title={h.name}>
                          {h.name}
                        </p>
                        {isToday && <Badge size="sm">{t('schoolMode.holidays.today')}</Badge>}
                        {past && !isToday && (
                          <Badge variant="secondary" size="sm">
                            {t('schoolMode.holidays.past')}
                          </Badge>
                        )}
                        <Can perm="schoolMode.manage">
                          <Button
                            variant="ghost"
                            size="icon-sm"
                            className="text-muted-foreground opacity-100 hover:text-destructive md:opacity-0 md:group-hover:opacity-100 md:focus-visible:opacity-100"
                            onClick={() => setRemoving(h)}
                            aria-label={`${t('common.delete')}: ${h.name}`}
                          >
                            <Trash2 />
                          </Button>
                        </Can>
                      </li>
                    );
                  })}
                </ul>
              </SectionCard>
            ))}
          </div>
        </>
      )}

      <HolidayDialog open={addOpen} onOpenChange={setAddOpen} defaultDate={today} />
      <ConfirmDialog
        open={Boolean(removing)}
        onOpenChange={(open) => !open && setRemoving(null)}
        title={t('schoolMode.holidays.removeTitle')}
        description={removing ? t('schoolMode.holidays.removeDescription', { date: formatDate(localDate(removing.date), 'd MMMM yyyy'), name: removing.name }) : undefined}
        confirmLabel={t('common.delete')}
        destructive
        loading={remove.isPending}
        onConfirm={() => removing && remove.mutate(removing.id, { onSuccess: () => setRemoving(null) })}
      />
    </>
  );
}
