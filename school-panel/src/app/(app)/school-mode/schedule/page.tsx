'use client';

import { CalendarClock, Clock3, Pencil, Users } from 'lucide-react';
import { useState } from 'react';

import { Can } from '@/auth/can';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import type { BellPhase, ShiftRow } from '@/data/mock/services/school-mode';
import { useClockNow } from '@/features/engine/use-clock';
import { SafetyCallout } from '@/features/school-mode/components/safety-callout';
import { ShiftEditDialog } from '@/features/school-mode/components/shift-edit-dialog';
import { PeriodList, ShiftTimeline } from '@/features/school-mode/components/shift-timeline';
import { useSmShifts } from '@/features/school-mode/hooks';
import { TILE } from '@/features/school-mode/lib';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

const WEEKDAYS = [1, 2, 3, 4, 5, 6, 7] as const;

function PhaseBadge({ phase }: { phase: BellPhase }) {
  const { t } = useI18n();
  const text = t(`schoolMode.schedule.phase.${phase.kind}`, {
    no: 'periodNo' in phase ? phase.periodNo : '',
    time: 'endsAt' in phase ? phase.endsAt : 'startsAt' in phase ? phase.startsAt : '',
  });
  const variant = phase.kind === 'LESSON' ? 'default' : phase.kind === 'BREAK' ? 'info' : 'secondary';
  return (
    <Badge variant={variant} className="whitespace-nowrap">
      {(phase.kind === 'LESSON' || phase.kind === 'BREAK') && <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-current" aria-hidden />}
      {text}
    </Badge>
  );
}

function ShiftCard({ shift, nowMinute, onEdit }: { shift: ShiftRow; nowMinute: number; onEdit: () => void }) {
  const { t } = useI18n();
  return (
    <SectionCard
      className="animate-slide-up"
      icon={<Clock3 />}
      title={<span className="font-display text-base">{shift.name}</span>}
      description={t('schoolMode.schedule.summary', { start: shift.start, end: shift.end, lessons: shift.lessonCount })}
      actions={
        <>
          <PhaseBadge phase={shift.phase} />
          <Can perm="schoolMode.manage">
            <Button variant="outline" size="sm" onClick={onEdit}>
              <Pencil />
              {t('common.edit')}
            </Button>
          </Can>
        </>
      }
    >
      <div className="space-y-5">
        <div className="flex flex-wrap items-center gap-1.5" aria-label={t('schoolMode.schedule.weekdays')}>
          {WEEKDAYS.map((d) => (
            <span
              key={d}
              title={t(`enums.weekday.${d}`)}
              className={cn(
                'inline-flex h-7 w-9 items-center justify-center rounded-md text-xs font-semibold',
                shift.weekdays.includes(d)
                  ? 'bg-primary/10 text-primary ring-1 ring-inset ring-primary/20'
                  : 'text-muted-foreground/50 line-through ring-1 ring-inset ring-border/50',
              )}
            >
              {t(`enums.weekdayShort.${d}`)}
            </span>
          ))}
        </div>
        <ShiftTimeline shift={shift} nowMinute={nowMinute} />
        <PeriodList shift={shift} />
        <div className={cn('p-4', TILE)}>
          <div className="mb-2 flex flex-wrap items-center justify-between gap-2 text-sm">
            <span className="font-medium">{t('schoolMode.schedule.classesUsing')}</span>
            <span className="inline-flex items-center gap-1.5 text-xs text-muted-foreground">
              <Users className="h-3.5 w-3.5" aria-hidden />
              {t('schoolMode.schedule.students', { count: shift.studentCount })}
            </span>
          </div>
          {shift.classes.length === 0 ? (
            <p className="text-sm text-muted-foreground">{t('schoolMode.schedule.noClasses')}</p>
          ) : (
            <div className="flex flex-wrap gap-1.5">
              {shift.classes.map((c) => (
                <Badge key={c.id} variant="outline" className="whitespace-nowrap bg-card/80 tabular-nums">
                  {c.name}
                </Badge>
              ))}
            </div>
          )}
        </div>
      </div>
    </SectionCard>
  );
}

export default function SchoolModeSchedulePage() {
  const { t } = useI18n();
  const shifts = useSmShifts();
  const now = useClockNow(15_000);
  const nowMinute = now.getHours() * 60 + now.getMinutes() + now.getSeconds() / 60;
  const [editing, setEditing] = useState<ShiftRow | null>(null);

  return (
    <>
      <PageHeader title={t('schoolMode.schedule.title')} subtitle={t('schoolMode.schedule.subtitle')} />
      {shifts.isError ? (
        <ErrorState error={shifts.error} onRetry={() => void shifts.refetch()} />
      ) : shifts.isLoading ? (
        <div className="grid gap-6">
          <Skeleton className="h-80 rounded-2xl" />
          <Skeleton className="h-80 rounded-2xl" />
        </div>
      ) : (shifts.data ?? []).length === 0 ? (
        <EmptyState icon={<CalendarClock />} title={t('common.noData')} />
      ) : (
        <div className="grid gap-6">
          {(shifts.data ?? []).map((shift) => (
            <ShiftCard key={shift.id} shift={shift} nowMinute={nowMinute} onEdit={() => setEditing(shift)} />
          ))}
        </div>
      )}
      <SafetyCallout className="mt-6" />
      <ShiftEditDialog shift={editing} onOpenChange={(open) => !open && setEditing(null)} />
    </>
  );
}
