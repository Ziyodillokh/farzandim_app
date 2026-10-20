'use client';

const isMissing = (value: unknown): value is null | undefined => value === null || value === undefined;

/** Recharts uchun ixcham, mavzuga mos tooltip. Qiymat yo'q (null, masalan yashirin natija) — "—", birliksiz. */
export function ChartTooltip({
  active,
  label,
  payload,
  formatLabel,
  note,
}: {
  active?: boolean;
  label?: string | number;
  payload?: Array<{ name?: string | number; value?: number | string | null; color?: string; unit?: string | number }>;
  formatLabel?: (label: string) => string;
  /** Qatorlar ostidagi qisqa izoh (masalan, natija nega yashirilgani). */
  note?: string;
}) {
  if (!active || !payload?.length) return null;
  return (
    <div className="glass-popover rounded-xl px-3 py-2 text-xs">
      {label !== undefined && <p className="mb-1 font-semibold text-foreground">{formatLabel ? formatLabel(String(label)) : label}</p>}
      {payload.map((p) => (
        <p key={String(p.name)} className="flex items-center gap-2 text-muted-foreground">
          <span className="h-2 w-2 rounded-full" style={{ background: p.color }} />
          {p.name}: <span className="font-semibold text-foreground tabular-nums">{isMissing(p.value) ? '—' : p.value}
            {isMissing(p.value) ? null : p.unit}
          </span>
        </p>
      ))}
      {note && <p className="mt-1 max-w-[220px] text-muted-foreground">{note}</p>}
    </div>
  );
}
