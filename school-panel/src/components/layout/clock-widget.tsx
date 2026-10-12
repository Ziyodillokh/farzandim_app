'use client';

import { Clock3, RotateCcw } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { CLOCK_SPEEDS, restartMorning, setClockMode, setClockSpeed } from '@/data/mock/clock';
import { useClockNow, useClockState } from '@/features/engine/use-clock';
import { useSchool } from '@/features/school/hooks';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

/** Yuqori paneldagi soat: haqiqiy vaqt yoki "Demo kuni" ssenariysi. */
export function ClockWidget() {
  const { t, formatDate } = useI18n();
  const now = useClockNow();
  const state = useClockState();
  const { data } = useSchool();
  const holidays = data?.holidays.map((h) => h.date) ?? [];
  const scenario = state.mode === 'SCENARIO';

  return (
    <Popover>
      <PopoverTrigger asChild>
        <button
          type="button"
          className={cn(
            'flex h-10 items-center gap-2 rounded-xl bg-white/60 px-3 text-sm ring-1 ring-inset ring-border/60 transition-colors hover:ring-primary/40 dark:bg-white/[0.04]',
            scenario && 'bg-primary/[0.07] ring-primary/30 dark:bg-primary/10',
          )}
        >
          <span className="relative flex h-2 w-2">
            <span className="absolute inline-flex h-full w-full animate-pulse-ring rounded-full bg-success" />
            <span className="relative inline-flex h-2 w-2 rounded-full bg-success" />
          </span>
          <span className="font-semibold tabular-nums">{formatDate(now, 'HH:mm')}</span>
          <span className="hidden text-muted-foreground md:inline">{formatDate(now, 'd MMM, EEEE')}</span>
          {scenario && <span className="rounded bg-primary px-1.5 py-0.5 text-2xs font-bold text-primary-foreground">{state.speed}×</span>}
        </button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-80">
        <div className="flex items-center gap-2">
          <Clock3 className="h-4 w-4 text-primary" />
          <p className="font-semibold">{t('demo.clockTitle')}</p>
        </div>
        <p className="mt-1 text-xs text-muted-foreground">{t('demo.clockHint')}</p>
        <div className="mt-3 grid grid-cols-2 gap-2">
          <Button variant={scenario ? 'outline' : 'default'} size="sm" onClick={() => setClockMode('REAL')}>
            {t('demo.clockReal')}
          </Button>
          <Button variant={scenario ? 'default' : 'outline'} size="sm" onClick={() => setClockMode('SCENARIO', holidays)}>
            {t('demo.clockScenario')}
          </Button>
        </div>
        {scenario && (
          <>
            <p className="mb-1.5 mt-4 text-xs font-medium text-muted-foreground">{t('demo.speed')}</p>
            <div className="grid grid-cols-3 gap-2">
              {CLOCK_SPEEDS.map((speed) => (
                <Button key={speed} size="sm" variant={state.speed === speed ? 'soft' : 'outline'} onClick={() => setClockSpeed(speed)}>
                  {speed}×
                </Button>
              ))}
            </div>
            <Button variant="outline" size="sm" className="mt-3 w-full" onClick={() => restartMorning(holidays)}>
              <RotateCcw />
              {t('demo.restartMorning')}
            </Button>
          </>
        )}
      </PopoverContent>
    </Popover>
  );
}
