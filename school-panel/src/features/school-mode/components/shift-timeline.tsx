'use client';

import type { BellPeriod } from '@/data/contracts';
import type { BellPhase, ShiftRow } from '@/data/mock/services/school-mode';
import { useI18n } from '@/i18n';
import { cn, hhmmToMinutes } from '@/lib/utils';
import { TILE } from '../lib';

/** Tanaffus — chiziqli naqsh (ikkala mavzuda ham ko'rinadi). */
const HATCH = { backgroundImage: 'repeating-linear-gradient(135deg, hsl(var(--muted-foreground) / 0.16) 0 4px, transparent 4px 8px)' };

const isCurrent = (p: BellPeriod, phase: BellPhase) =>
  (phase.kind === 'LESSON' || phase.kind === 'BREAK') && phase.kind === p.kind && phase.startsAt === p.start;

/** Smena chizig'i: darslar va tanaffuslar uzunligiga mos, hozirgi davr va "Hozir" belgisi bilan. */
export function ShiftTimeline({ shift, nowMinute }: { shift: ShiftRow; nowMinute: number }) {
  const { t } = useI18n();
  const start = hhmmToMinutes(shift.start);
  const span = Math.max(1, hhmmToMinutes(shift.end) - start);
  const pos = (minute: number) => `${((minute - start) / span) * 100}%`;
  const live = shift.phase.kind === 'LESSON' || shift.phase.kind === 'BREAK';

  return (
    <div className="overflow-x-auto pb-1">
      <div className={cn('relative min-w-[600px]', live ? 'pt-6' : 'pt-1')}>
        {live && (
          <div className="pointer-events-none absolute bottom-6 top-0 z-10 flex -translate-x-1/2 flex-col items-center" style={{ left: pos(nowMinute) }}>
            <span className="rounded-full bg-card px-2 py-px text-2xs font-semibold text-destructive shadow-soft ring-1 ring-destructive/40">
              {t('schoolMode.schedule.nowMarker')}
            </span>
            <span className="w-0.5 flex-1 rounded-full bg-destructive/80" />
          </div>
        )}
        <div className={cn('relative h-14', TILE)} role="list">
          {shift.periods.map((p) => {
            const ps = hhmmToMinutes(p.start);
            const pe = hhmmToMinutes(p.end);
            const current = isCurrent(p, shift.phase);
            const lesson = p.kind === 'LESSON';
            const label = lesson ? t('schoolMode.state.LESSON', { no: p.no }) : t('enums.bellKind.BREAK');
            return (
              <div
                key={`${p.kind}-${p.start}`}
                role="listitem"
                title={`${label} · ${p.start}–${p.end}`}
                aria-current={current || undefined}
                className={cn(
                  'absolute inset-y-1 flex items-center justify-center overflow-hidden rounded-lg text-xs font-semibold transition-colors',
                  lesson ? 'bg-primary/10 text-primary ring-1 ring-inset ring-primary/20' : 'text-muted-foreground',
                  current && lesson && 'bg-primary/20 font-bold ring-2 ring-primary shadow-primary-glow',
                  current && !lesson && 'bg-info/10 ring-2 ring-info',
                )}
                style={{ left: pos(ps), width: `${((pe - ps) / span) * 100}%`, ...(lesson ? {} : HATCH) }}
              >
                {lesson ? <span className="truncate px-1">{p.no}</span> : null}
              </div>
            );
          })}
        </div>
        <div className="relative mt-1.5 h-5 text-2xs tabular-nums text-muted-foreground">
          {shift.periods
            .filter((p) => p.kind === 'LESSON')
            .map((p) => (
              <span key={p.start} className="absolute -translate-x-1/2 first:translate-x-0" style={{ left: pos(hhmmToMinutes(p.start)) }}>
                {p.start}
              </span>
            ))}
          <span className="absolute right-0">{shift.end}</span>
        </div>
      </div>
    </div>
  );
}

/** Davrlar ro'yxati (chip ko'rinishida) — davomiylik bilan. */
export function PeriodList({ shift }: { shift: ShiftRow }) {
  const { t } = useI18n();
  return (
    <ol className="flex flex-wrap gap-1.5">
      {shift.periods.map((p) => {
        const minutes = hhmmToMinutes(p.end) - hhmmToMinutes(p.start);
        const current = isCurrent(p, shift.phase);
        const lesson = p.kind === 'LESSON';
        return (
          <li
            key={`${p.kind}-${p.start}`}
            className={cn(
              'inline-flex items-center gap-1.5 rounded-lg px-2.5 py-1 text-xs tabular-nums ring-1 ring-inset',
              lesson ? 'bg-white/60 ring-border/60 dark:bg-white/[0.04]' : 'bg-transparent text-muted-foreground ring-border/40',
              current && 'bg-primary/10 text-primary ring-primary/40',
            )}
          >
            <span className="font-semibold">{lesson ? t('schoolMode.state.LESSON', { no: p.no }) : t('enums.bellKind.BREAK')}</span>
            <span>
              {p.start}–{p.end}
            </span>
            <span className="text-muted-foreground">· {t('schoolMode.schedule.minutes', { count: minutes })}</span>
          </li>
        );
      })}
    </ol>
  );
}
