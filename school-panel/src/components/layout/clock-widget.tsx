'use client';

import { Clock3 } from 'lucide-react';

import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { scenarioEnded } from '@/data/mock/clock';
import { ClockControls } from '@/features/engine/clock-controls';
import { useClockNow, useClockState } from '@/features/engine/use-clock';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

/** Yuqori paneldagi soat: haqiqiy vaqt yoki "Demo kuni" ssenariysi. */
export function ClockWidget() {
  const { t, formatDate } = useI18n();
  const now = useClockNow();
  const state = useClockState();
  const scenario = state.mode === 'SCENARIO';
  const ended = scenario && scenarioEnded();

  return (
    <Popover>
      <PopoverTrigger asChild>
        <button
          type="button"
          aria-label={`${t('demo.clockTitle')}: ${formatDate(now, 'HH:mm')}`}
          className={cn(
            'flex h-10 shrink-0 items-center gap-2 rounded-xl bg-white/60 px-2.5 text-sm sm:px-3 ring-1 ring-inset ring-border/60 transition-colors hover:ring-primary/40 dark:bg-white/[0.04]',
            scenario && 'bg-primary/[0.07] ring-primary/30 dark:bg-primary/10',
          )}
        >
          <span className="relative flex h-2 w-2">
            {!ended && <span className="absolute inline-flex h-full w-full animate-pulse-ring rounded-full bg-success" />}
            <span className={cn('relative inline-flex h-2 w-2 rounded-full', ended ? 'bg-muted-foreground' : 'bg-success')} />
          </span>
          <span className="font-semibold tabular-nums">{formatDate(now, 'HH:mm')}</span>
          <span className="hidden text-muted-foreground md:inline">{formatDate(now, 'd MMM, EEEE')}</span>
          {scenario && (
            <span className="hidden rounded-md bg-primary/15 px-1.5 py-0.5 text-2xs font-bold text-primary ring-1 ring-inset ring-primary/20 dark:bg-primary/20 sm:inline">
              {state.speed}×
            </span>
          )}
        </button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-80">
        <div className="flex items-center gap-2">
          <Clock3 className="h-4 w-4 text-primary" />
          <p className="font-semibold">{t('demo.clockTitle')}</p>
        </div>
        <p className="mb-3 mt-1 text-xs text-muted-foreground">{t('demo.clockHint')}</p>
        <ClockControls />
      </PopoverContent>
    </Popover>
  );
}
