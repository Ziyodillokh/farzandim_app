import type { ReactNode } from 'react';

import { cn } from '@/lib/utils';

/**
 * Chop etiladigan hujjat bo'laklari: oq "qog'oz" ustida aniq (slate) ranglar —
 * mavzudan (qorong'i/yorug') mustaqil, printerda ham o'qiladi.
 */
export function DocSection({ n, title, note, children, className }: { n: number; title: string; note?: string; children: ReactNode; className?: string }) {
  return (
    <section className={cn('break-inside-avoid-page pt-7', className)}>
      <h2 className="flex items-baseline gap-2.5 border-b border-slate-200 pb-2 text-[1.02rem] font-semibold text-slate-900">
        <span className="font-display text-[0.8rem] text-sky-700">{String(n).padStart(2, '0')}</span>
        {title}
        {note && <span className="ml-auto text-[0.7rem] font-normal text-slate-500">{note}</span>}
      </h2>
      <div className="pt-3">{children}</div>
    </section>
  );
}

export function DocTable({ head, rows, align }: { head: string[]; rows: Array<Array<ReactNode>>; align?: Array<'left' | 'right'> }) {
  return (
    <table className="w-full border-collapse text-[0.78rem] text-slate-800">
      <thead>
        <tr>
          {head.map((h, i) => (
            <th
              key={h}
              className={cn(
                'border-b border-slate-300 px-2 py-1.5 text-[0.68rem] font-semibold uppercase tracking-[0.06em] text-slate-500',
                (align?.[i] ?? (i === 0 ? 'left' : 'right')) === 'left' ? 'text-left' : 'text-right',
              )}
            >
              {h}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {rows.map((r, ri) => (
          <tr key={ri} className="break-inside-avoid odd:bg-slate-50">
            {r.map((c, ci) => (
              <td
                key={ci}
                className={cn('border-b border-slate-100 px-2 py-1.5 tabular-nums', (align?.[ci] ?? (ci === 0 ? 'left' : 'right')) === 'left' ? 'text-left' : 'text-right')}
              >
                {c}
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}

/** Gorizontal ulush chizig'i (fon chop etilishi uchun print-color-adjust: exact). */
export function DocBar({ label, value, share, color = '#0284c7' }: { label: string; value: string; share: number; color?: string }) {
  return (
    <div className="break-inside-avoid">
      <div className="flex items-baseline justify-between gap-3 text-[0.78rem] text-slate-800">
        <span className="truncate">{label}</span>
        <span className="font-semibold tabular-nums">{value}</span>
      </div>
      <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-slate-100">
        <div className="h-full rounded-full" style={{ width: `${Math.max(0, Math.min(100, share))}%`, background: color }} />
      </div>
    </div>
  );
}

/** O'zgarish matni rangi: yaxshi — zumrad, e'tibor — amber. */
export function DeltaText({ text, tone }: { text: string; tone: 'good' | 'bad' | 'neutral' }) {
  return <span className={cn(tone === 'good' ? 'text-emerald-700' : tone === 'bad' ? 'text-amber-700' : 'text-slate-500')}>{text}</span>;
}

export function DocLabel({ children }: { children: ReactNode }) {
  return <p className="mb-2 text-[0.68rem] font-semibold uppercase tracking-[0.1em] text-slate-500">{children}</p>;
}
