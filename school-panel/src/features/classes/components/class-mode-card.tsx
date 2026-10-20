'use client';

import { ArrowUpRight, Smartphone } from 'lucide-react';
import Link from 'next/link';

import { Can } from '@/auth/can';
import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import type { Shift } from '@/data/contracts';
import type { ClassModeState } from '@/data/mock/school-mode-state';
import { useI18n } from '@/i18n';
import { cn, hhmmToMinutes } from '@/lib/utils';
import { useClassMode } from '../hooks';
import { MODE_ICON, RestrictionHint, useModeLabel } from './mode-chip';

/** Smena jadvali chizig'i: darslar, tanaffuslar va "hozir" belgisi. */
function ShiftTimeline({ shift, minute }: { shift: Shift; minute: number }) {
  const { t } = useI18n();
  const start = hhmmToMinutes(shift.start);
  const end = hhmmToMinutes(shift.end);
  const span = Math.max(1, end - start);
  const nowPct = ((minute - start) / span) * 100;
  return (
    <div className="space-y-1.5">
      <div className="relative flex h-3 overflow-hidden rounded-full bg-muted">
        {shift.periods.map((p) => {
          const ps = hhmmToMinutes(p.start);
          const pe = hhmmToMinutes(p.end);
          const active = minute >= ps && minute < pe;
          return (
            <Tooltip key={`${p.kind}-${p.no}-${p.start}`}>
              <TooltipTrigger asChild>
                <span
                  className={cn(
                    'h-full border-r border-card last:border-r-0',
                    p.kind === 'LESSON' ? 'bg-primary/35' : 'bg-muted-foreground/15',
                    active && (p.kind === 'LESSON' ? 'bg-primary' : 'bg-info'),
                  )}
                  style={{ width: `${((pe - ps) / span) * 100}%` }}
                />
              </TooltipTrigger>
              <TooltipContent>
                {p.kind === 'LESSON' ? `${p.no} · ${t('classes.view.lesson')}` : t('classes.view.break')} · {p.start}–{p.end}
              </TooltipContent>
            </Tooltip>
          );
        })}
        {nowPct > 0 && nowPct < 100 && (
          <span className="absolute inset-y-0 w-0.5 bg-foreground shadow-[0_0_0_2px_hsl(var(--card))]" style={{ left: `${nowPct}%` }} aria-hidden />
        )}
      </div>
      <div className="flex justify-between text-2xs tabular-nums text-muted-foreground">
        <span>{shift.start}</span>
        <span>{shift.end}</span>
      </div>
    </div>
  );
}

function StateHero({ state }: { state: ClassModeState }) {
  const label = useModeLabel();
  const Icon = MODE_ICON[state.kind];
  return (
    <div className="flex items-center gap-3">
      <div
        className={cn(
          'flex h-12 w-12 shrink-0 items-center justify-center rounded-xl [&_svg]:size-5',
          state.restricted ? 'bg-brand-gradient text-white shadow-primary-glow' : 'bg-muted text-muted-foreground ring-1 ring-inset ring-border/60',
          state.kind === 'EMERGENCY_OFF' && 'bg-destructive/10 text-destructive',
        )}
      >
        <Icon />
      </div>
      <div className="min-w-0">
        <p className="font-display text-base font-semibold leading-tight">{label(state)}</p>
        <div className="mt-1">
          <RestrictionHint state={state} />
        </div>
      </div>
    </div>
  );
}

export function ClassModeCard({ classId, shift }: { classId: string; shift: Shift | null }) {
  const { t } = useI18n();
  const mode = useClassMode(classId);
  return (
    <SectionCard
      icon={<Smartphone />}
      title={t('classes.view.modeTitle')}
      description={shift ? t('classes.view.modeShift', { name: shift.name, start: shift.start, end: shift.end }) : undefined}
      actions={
        <Can perm="schoolMode.view">
          <Button asChild variant="ghost" size="icon-sm" className="text-primary hover:text-primary" title={t('classes.view.modeLink')}>
            <Link href="/school-mode" aria-label={t('classes.view.modeLink')}>
              <ArrowUpRight />
            </Link>
          </Button>
        </Can>
      }
    >
      {mode.data ? (
        <div className="space-y-4">
          <StateHero state={mode.data.state} />
          {shift && <ShiftTimeline shift={shift} minute={mode.data.minute} />}
          <p className="text-xs leading-relaxed text-muted-foreground">{t('classes.view.modeNote')}</p>
        </div>
      ) : (
        <div className="space-y-3">
          <Skeleton className="h-12 w-full" />
          <Skeleton className="h-3 w-full" />
        </div>
      )}
    </SectionCard>
  );
}
