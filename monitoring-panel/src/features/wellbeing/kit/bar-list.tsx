'use client';

import type { ReactNode } from 'react';

import { cn } from '@/lib/utils';

export type BarRow = { key: string; label: string; value: number | null; color?: string; note?: ReactNode };

/** Minimal ko'rinadigan ustun uzunligi (%) — kichik qiymat ham ko'rinsin. */
const MIN_BAR = 3;
/** Avtomatik shkalada eng uzun ustundan keyingi havo (8%). */
const AUTO_HEADROOM = 1.08;

/**
 * Gorizontal taqqoslash ustunlari (o'g'il/qiz bolalar, maktab turlari). Ustunlar
 * doim 0 dan boshlanadi — uzunlik qiymatga mutanosib (yaqin qiymatlar orasidagi
 * kichik farq bo'rttirilmaydi). `max` — shkalaning yuqori chegarasi (foiz, indeks
 * uchun 100), bo'lmasa — eng katta qiymatdan; `reference` — ingichka belgi (umumiy qiymat).
 */
export function BarList({
  rows,
  format,
  max,
  reference,
  referenceLabel,
  labelWidth = '7.5rem',
  className,
}: {
  rows: readonly BarRow[];
  format: (v: number | null) => string;
  max?: number;
  reference?: number | null;
  referenceLabel?: string;
  labelWidth?: string;
  className?: string;
}) {
  const values = rows.map((r) => r.value).filter((v): v is number => v !== null);
  const top = max ?? Math.max(1, ...values, reference ?? 0) * AUTO_HEADROOM;
  const pos = (v: number) => Math.min(100, Math.max(0, (v / (top || 1)) * 100));
  return (
    <ul className={cn('space-y-2', className)}>
      {rows.map((r) => (
        <li key={r.key} className="grid items-center gap-2.5 text-[0.8rem]" style={{ gridTemplateColumns: `minmax(0,${labelWidth}) minmax(0,1fr) auto` }}>
          <span className="truncate text-muted-foreground" title={r.label}>
            {r.label}
          </span>
          <span className="relative h-2.5 rounded-full bg-muted/70">
            {r.value !== null && (
              <span
                className="absolute inset-y-0 left-0 rounded-full bg-brand-gradient transition-[width] duration-700"
                style={{ width: `${Math.max(MIN_BAR, pos(r.value))}%`, ...(r.color ? { background: r.color } : {}) }}
              />
            )}
            {reference !== undefined && reference !== null && (
              // Ingichka belgi, sichqoncha uchun kengroq maydon (title — belgining nomi).
              <span title={referenceLabel} aria-hidden className="absolute -top-1 flex h-[18px] w-3 -translate-x-1/2 justify-center" style={{ left: `${pos(reference)}%` }}>
                <span className="h-full w-0.5 rounded-full bg-foreground/55" />
              </span>
            )}
          </span>
          <span className="flex items-baseline justify-end gap-1.5 whitespace-nowrap">
            <b className="font-semibold tabular-nums">{format(r.value)}</b>
            {r.note}
          </span>
        </li>
      ))}
    </ul>
  );
}
