'use client';

import type { Level } from '@/data/reference/domains';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

/** "Bola ovozi" daraja chegaralari (domains.topicLevel bilan bir xil). */
export const LEVEL_MIDDLE = 60;
export const LEVEL_GOOD = 72;

export const LEVEL_TONE: Record<Level, string> = {
  GOOD: 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300',
  MIDDLE: 'bg-sky-500/15 text-sky-700 dark:text-sky-300',
  LOW: 'bg-amber-500/15 text-amber-700 dark:text-amber-300',
};

/** Shkala to'ldirilishi (daraja rangi): yaxshi — moviy-yashil, o'rta — havorang, past — amber. */
export const LEVEL_FILL: Record<Level, string> = {
  GOOD: 'linear-gradient(90deg, hsl(172 66% 40%), hsl(160 64% 46%))',
  MIDDLE: 'linear-gradient(90deg, hsl(205 85% 52%), hsl(195 88% 52%))',
  LOW: 'linear-gradient(90deg, hsl(32 92% 52%), hsl(40 92% 58%))',
};

export function LevelBadge({ level, className }: { level: Level | null; className?: string }) {
  const { t } = useI18n();
  if (!level) return null;
  return <span className={cn('inline-flex shrink-0 items-center rounded-full px-2 py-0.5 text-[0.66rem] font-semibold', LEVEL_TONE[level], className)}>{t(`enums.level.${level}`)}</span>;
}

/**
 * 0–100 shkala: zonalar (60 va 72 chegaralari), qiymat belgisi va ixtiyoriy
 * respublika belgisi. Raqamlar shkala ostida — rang yagona kanal emas.
 */
export function LevelScale({ value, national, className }: { value: number | null; national?: number | null; className?: string }) {
  const clamp = (v: number) => Math.min(100, Math.max(0, v));
  return (
    <div className={cn('relative pb-4', className)}>
      <div className="flex h-2 gap-[2px] overflow-hidden rounded-full">
        <span className="bg-amber-500/30" style={{ width: `${LEVEL_MIDDLE}%` }} />
        <span className="bg-sky-500/30" style={{ width: `${LEVEL_GOOD - LEVEL_MIDDLE}%` }} />
        <span className="flex-1 bg-emerald-500/30" />
      </div>
      {national !== undefined && national !== null && (
        <span aria-hidden className="absolute -top-1 h-4 w-0.5 -translate-x-1/2 rounded-full bg-foreground/50" style={{ left: `${clamp(national)}%` }} />
      )}
      {value !== null && (
        <span
          aria-hidden
          className="absolute -top-[5px] h-[18px] w-[18px] -translate-x-1/2 rounded-full border-[3px] border-card bg-foreground shadow-soft"
          style={{ left: `${clamp(value)}%` }}
        />
      )}
      <span className="absolute left-0 top-3 text-[0.62rem] tabular-nums text-muted-foreground">0</span>
      <span className="absolute top-3 -translate-x-1/2 text-[0.62rem] tabular-nums text-muted-foreground" style={{ left: `${LEVEL_MIDDLE}%` }}>
        {LEVEL_MIDDLE}
      </span>
      <span className="absolute top-3 -translate-x-1/2 text-[0.62rem] tabular-nums text-muted-foreground" style={{ left: `${LEVEL_GOOD}%` }}>
        {LEVEL_GOOD}
      </span>
      <span className="absolute right-0 top-3 text-[0.62rem] tabular-nums text-muted-foreground">100</span>
    </div>
  );
}
