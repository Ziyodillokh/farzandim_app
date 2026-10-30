'use client';

import type { ReactNode } from 'react';

import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';

const toPct = (v: number, max: number) => `${Math.min(100, Math.max(0, (v / (max || 1)) * 100))}%`;

export type CompareRow = {
  key: string;
  label: string;
  value: number | null;
  /** Ustun rangi (berilmasa — brend gradienti). Rang yonida doim matn (nom + qiymat) bor. */
  color?: string;
  /** Ustun ustidagi ingichka belgi (masalan, respublika qiymati). */
  marker?: number | null;
  hint?: ReactNode;
};

/**
 * Taqqoslash ustunlari: nom, qiymat va 0..max shkaladagi ustun. `null` — "—"
 * (K-anonimlik yoki ma'lumot yo'q), ustun chizilmaydi.
 */
export function CompareBars({
  rows,
  format,
  max = 100,
  markerLabel,
  className,
}: {
  rows: CompareRow[];
  format: (v: number | null) => string;
  max?: number;
  markerLabel?: string;
  className?: string;
}) {
  return (
    <ul className={cn('space-y-3', className)}>
      {rows.map((r) => (
        <li key={r.key}>
          <div className="mb-1 flex items-baseline justify-between gap-3 text-[0.8rem]">
            <span className="flex min-w-0 items-center gap-2">
              {r.color && <span aria-hidden className="h-2.5 w-2.5 shrink-0 rounded-sm" style={{ background: r.color }} />}
              <span className="truncate font-medium">{r.label}</span>
            </span>
            <span className="shrink-0 font-semibold tabular-nums">{format(r.value)}</span>
          </div>
          <div className="relative h-2 rounded-full bg-muted/70">
            {r.value !== null && (
              <span
                className="absolute inset-y-0 left-0 rounded-full bg-brand-gradient transition-[width] duration-700"
                style={{ width: toPct(r.value, max), ...(r.color ? { background: r.color } : {}) }}
              />
            )}
            {r.marker !== undefined && r.marker !== null && (
              <span title={markerLabel} className="absolute -top-1 h-4 w-0.5 rounded-full bg-foreground/60" style={{ left: toPct(r.marker, max) }} />
            )}
          </div>
          {r.hint && <div className="mt-1 text-[0.7rem] text-muted-foreground">{r.hint}</div>}
        </li>
      ))}
    </ul>
  );
}

export type StackPart = { key: string; label: string; value: number; color: string };

/** 100% yig'ma ustun: bo'laklar orasida 2px bo'shliq, har bo'lakda nom va ulush (title). */
export function StackBar({ parts, className }: { parts: StackPart[]; className?: string }) {
  const fmt = useMetricFormat();
  const visible = parts.filter((p) => p.value > 0);
  const total = visible.reduce((s, p) => s + p.value, 0) || 1;
  return (
    <div className={cn('flex h-2.5 w-full gap-[2px] overflow-hidden rounded-full', className)} role="img" aria-label={visible.map((p) => `${p.label}: ${fmt.pct(p.value)}`).join('; ')}>
      {visible.map((p) => (
        <span key={p.key} title={`${p.label}: ${fmt.pct(p.value)}`} className="h-full min-w-[2px] transition-[width] duration-700" style={{ width: `${(p.value / total) * 100}%`, background: p.color }} />
      ))}
    </div>
  );
}

/** Rang kalitlari (legenda): nom va ixtiyoriy qiymat. */
export function SwatchLegend({ items, className }: { items: Array<{ key: string; label: string; color: string; value?: string }>; className?: string }) {
  return (
    <ul className={cn('flex flex-wrap gap-x-3 gap-y-1 text-[0.72rem] text-muted-foreground', className)}>
      {items.map((i) => (
        <li key={i.key} className="flex items-center gap-1.5">
          <span aria-hidden className="h-2.5 w-2.5 shrink-0 rounded-sm" style={{ background: i.color }} />
          <span>{i.label}</span>
          {i.value && <span className="font-semibold tabular-nums text-foreground">{i.value}</span>}
        </li>
      ))}
    </ul>
  );
}

/** Bitta ulush (0..100) uchun ingichka chiziq. */
export function Meter({ value, className, barClassName }: { value: number | null; className?: string; barClassName?: string }) {
  return (
    <div className={cn('relative h-1.5 w-full overflow-hidden rounded-full bg-muted/70', className)}>
      {value !== null && <span className={cn('absolute inset-y-0 left-0 rounded-full bg-brand-gradient', barClassName)} style={{ width: toPct(value, 100) }} />}
    </div>
  );
}
