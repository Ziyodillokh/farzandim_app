'use client';

import { MoonStar, RotateCcw } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { CLOCK_SPEEDS, restartMorning, scenarioEnded, setClockMode, setClockSpeed } from '@/data/mock/clock';
import { useSchool } from '@/features/school/hooks';
import { useI18n } from '@/i18n';
import { useClockNow, useClockState } from './use-clock';

/** "Demo kuni yakunlandi" (19:00) — qayta boshlash taklifi bilan. */
function DayEndedNotice({ onRestart }: { onRestart: () => void }) {
  const { t } = useI18n();
  return (
    <div className="mt-3 rounded-xl bg-primary/[0.07] p-3 ring-1 ring-inset ring-primary/20">
      <p className="flex items-center gap-2 text-sm font-semibold text-primary">
        <MoonStar className="h-4 w-4" />
        {t('demo.dayEnded')}
      </p>
      <p className="mt-1 text-xs text-muted-foreground">{t('demo.dayEndedHint')}</p>
      <Button size="sm" className="mt-2.5 w-full" onClick={onRestart}>
        <RotateCcw />
        {t('demo.restart')}
      </Button>
    </div>
  );
}

/** Demo soati boshqaruvi: rejim, tezlik, ertalabni qayta boshlash (soat vidjeti va demo panel). */
export function ClockControls() {
  const { t } = useI18n();
  const state = useClockState();
  // Har 5 soniyada qayta chizish — 19:00 holati o'z vaqtida ko'rinsin.
  useClockNow(5000);
  const { data } = useSchool();
  const holidays = data?.holidays.map((h) => h.date) ?? [];
  const scenario = state.mode === 'SCENARIO';
  const ended = scenario && scenarioEnded();
  const restart = () => restartMorning(holidays);

  return (
    <div>
      <div className="grid grid-cols-2 gap-2" role="group" aria-label={t('demo.clockTitle')}>
        <Button variant={scenario ? 'outline' : 'default'} size="sm" aria-pressed={!scenario} onClick={() => setClockMode('REAL')}>
          {t('demo.clockReal')}
        </Button>
        <Button variant={scenario ? 'default' : 'outline'} size="sm" aria-pressed={scenario} onClick={() => setClockMode('SCENARIO', holidays)}>
          {t('demo.clockScenario')}
        </Button>
      </div>
      {scenario && (
        <>
          <p className="mb-1.5 mt-4 text-xs font-medium text-muted-foreground">{t('demo.speed')}</p>
          <div className="grid grid-cols-3 gap-2" role="group" aria-label={t('demo.speed')}>
            {CLOCK_SPEEDS.map((speed) => (
              <Button key={speed} size="sm" variant={state.speed === speed ? 'soft' : 'outline'} aria-pressed={state.speed === speed} onClick={() => setClockSpeed(speed)}>
                {speed}×
              </Button>
            ))}
          </div>
          {ended ? (
            <DayEndedNotice onRestart={restart} />
          ) : (
            <Button variant="outline" size="sm" className="mt-3 w-full" onClick={restart}>
              <RotateCcw />
              {t('demo.restartMorning')}
            </Button>
          )}
        </>
      )}
    </div>
  );
}
