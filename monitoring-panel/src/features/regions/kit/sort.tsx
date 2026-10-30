'use client';

import { ArrowDown, ArrowUp, ArrowUpDown } from 'lucide-react';
import { useCallback, useState, type ReactNode } from 'react';

import { METRICS } from '@/data/mock/model/metrics';
import type { MetricKey } from '@/data/contracts';
import { cn } from '@/lib/utils';

export type SortDir = 'asc' | 'desc';
export type SortState<K extends string = string> = { key: K; dir: SortDir };
export type SortValue = number | string | null | undefined;

/** Ko'rsatkich ustuni birinchi bosilganda — eng yaxshisi yuqorida. */
export function bestFirstDir(metric: MetricKey): SortDir {
  return METRICS[metric].better === 'down' ? 'asc' : 'desc';
}

/** Saralash holati: yangi ustun — `firstDir` yo'nalishida, o'sha ustun qayta bosilsa — teskari. */
export function useTableSort<K extends string>(initial: SortState<K>, firstDir: (key: K) => SortDir) {
  const [sort, setSort] = useState<SortState<K>>(initial);
  const toggle = useCallback(
    (key: K) => setSort((s) => (s.key === key ? { key, dir: s.dir === 'asc' ? 'desc' : 'asc' } : { key, dir: firstDir(key) })),
    [firstDir],
  );
  return { sort, toggle, setSort };
}

const isMissing = (v: SortValue): boolean => v === null || v === undefined || (typeof v === 'number' && !Number.isFinite(v));

/** Saralangan nusxa (asl massiv o'zgarmaydi); bo'sh qiymatlar har doim oxirida. */
export function sortRows<T>(rows: readonly T[], value: (row: T) => SortValue, dir: SortDir, locale: string): T[] {
  return [...rows].sort((a, b) => {
    const va = value(a);
    const vb = value(b);
    const ma = isMissing(va);
    const mb = isMissing(vb);
    if (ma || mb) return ma === mb ? 0 : ma ? 1 : -1;
    const diff = typeof va === 'number' && typeof vb === 'number' ? va - vb : String(va).localeCompare(String(vb), locale);
    return dir === 'asc' ? diff : -diff;
  });
}

export function ariaSort(active: boolean, dir: SortDir): 'ascending' | 'descending' | undefined {
  if (!active) return undefined;
  return dir === 'asc' ? 'ascending' : 'descending';
}

/** Saralanadigan sarlavha: matn + yo'nalish belgisi (faol bo'lmasa — xira). */
export function SortButton({
  label,
  active,
  dir,
  onClick,
  align = 'center',
  title,
}: {
  label: ReactNode;
  active: boolean;
  dir: SortDir;
  onClick: () => void;
  align?: 'left' | 'center' | 'right';
  title?: string;
}) {
  const Icon = !active ? ArrowUpDown : dir === 'asc' ? ArrowUp : ArrowDown;
  return (
    <button
      type="button"
      onClick={onClick}
      title={title}
      className={cn(
        // `max-w-full` yo'q: jadval katagida u ustunning eng kichik enini nolga tushirib, sarlavhani kesib qo'yadi.
        'group/sort -mx-1 inline-flex items-center gap-1 rounded-md px-1 py-0.5 text-inherit transition-colors hover:text-foreground',
        active && 'text-foreground',
        align === 'left' && 'text-left',
        align === 'center' && 'justify-center text-center',
        align === 'right' && 'justify-end text-right',
      )}
    >
      <span className="line-clamp-2">{label}</span>
      <Icon aria-hidden className={cn('h-3 w-3 shrink-0', active ? 'text-primary' : 'opacity-40 group-hover/sort:opacity-80')} />
    </button>
  );
}
