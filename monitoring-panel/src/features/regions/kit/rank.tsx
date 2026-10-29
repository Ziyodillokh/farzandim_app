import { cn } from '@/lib/utils';
import { isNum } from './heat';

export type RankTone = 'top' | 'bottom' | 'plain';

/** Eng yaxshi va eng past uchtalik ajratiladi. */
const EDGE = 3;

const TONES: Record<RankTone, string> = {
  top: 'bg-cyan-500/15 text-cyan-700 ring-cyan-500/35 dark:text-cyan-300',
  bottom: 'bg-amber-500/15 text-amber-700 ring-amber-500/35 dark:text-amber-300',
  plain: 'bg-primary/[0.06] text-muted-foreground ring-border/70 dark:bg-white/[0.04]',
};

/**
 * Reyting (1 — eng yaxshi). Teng qiymatlar bir xil o'rinda ("1, 2, 2, 4").
 * `better: 'neutral'` — kattasi birinchi (baholanmaydi, faqat tartib).
 */
export function rankMap<T>(
  rows: readonly T[],
  id: (row: T) => string,
  value: (row: T) => number | null | undefined,
  better: 'up' | 'down' | 'neutral',
): Map<string, number> {
  const ranked = rows
    .map((row) => ({ key: id(row), v: value(row) }))
    .filter((r): r is { key: string; v: number } => isNum(r.v))
    .sort((a, b) => (better === 'down' ? a.v - b.v : b.v - a.v));
  const out = new Map<string, number>();
  ranked.forEach((r, i) => {
    const prev = ranked[i - 1];
    out.set(r.key, prev && prev.v === r.v ? (out.get(prev.key) as number) : i + 1);
  });
  return out;
}

export function rankTone(rank: number | null | undefined, total: number, polar: boolean): RankTone {
  if (!polar || !rank) return 'plain';
  if (rank <= EDGE) return 'top';
  if (rank > total - EDGE) return 'bottom';
  return 'plain';
}

export function RankBadge({ rank, tone, title, className }: { rank: number | null | undefined; tone: RankTone; title?: string; className?: string }) {
  return (
    <span
      title={title}
      className={cn(
        'inline-flex h-6 min-w-6 shrink-0 items-center justify-center rounded-lg px-1 text-[0.7rem] font-bold tabular-nums ring-1 ring-inset',
        TONES[tone],
        className,
      )}
    >
      {rank ?? '—'}
    </span>
  );
}
