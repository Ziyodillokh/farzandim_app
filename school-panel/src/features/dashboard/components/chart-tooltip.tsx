'use client';

/** Recharts uchun ixcham, mavzuga mos tooltip. */
export function ChartTooltip({
  active,
  label,
  payload,
  formatLabel,
}: {
  active?: boolean;
  label?: string | number;
  payload?: Array<{ name?: string | number; value?: number | string; color?: string; unit?: string | number }>;
  formatLabel?: (label: string) => string;
}) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-lg border bg-popover px-3 py-2 text-xs shadow-lg">
      {label !== undefined && <p className="mb-1 font-medium">{formatLabel ? formatLabel(String(label)) : label}</p>}
      {payload.map((p) => (
        <p key={String(p.name)} className="flex items-center gap-2 text-muted-foreground">
          <span className="h-2 w-2 rounded-full" style={{ background: p.color }} />
          {p.name}: <span className="font-semibold text-foreground tabular-nums">{p.value}
            {p.unit}
          </span>
        </p>
      ))}
    </div>
  );
}
