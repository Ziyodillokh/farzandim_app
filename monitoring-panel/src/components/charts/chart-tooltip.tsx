'use client';

const isMissing = (value: unknown): value is null | undefined => value === null || value === undefined;

/** Recharts uchun ixcham, mavzuga mos tooltip. Qiymat yo'q (null) — "—". */
export function ChartTooltip({
  active,
  label,
  payload,
  formatLabel,
  formatValue,
}: {
  active?: boolean;
  label?: string | number;
  payload?: Array<{ name?: string | number; value?: number | string | null; color?: string; dataKey?: string | number }>;
  formatLabel?: (label: string) => string;
  formatValue?: (value: number, dataKey?: string) => string;
}) {
  if (!active || !payload?.length) return null;
  return (
    <div className="glass-popover rounded-xl px-3 py-2 text-xs">
      {label !== undefined && <p className="mb-1 font-semibold text-foreground">{formatLabel ? formatLabel(String(label)) : label}</p>}
      {payload.map((p) => (
        <p key={String(p.dataKey ?? p.name)} className="flex items-center gap-2 text-muted-foreground">
          <span className="h-2 w-2 rounded-full" style={{ background: p.color }} />
          {p.name}:{' '}
          <span className="font-semibold tabular-nums text-foreground">
            {isMissing(p.value) ? '—' : formatValue && typeof p.value === 'number' ? formatValue(p.value, String(p.dataKey ?? '')) : p.value}
          </span>
        </p>
      ))}
    </div>
  );
}
