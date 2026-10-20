'use client';

import type { ReactNode } from 'react';

import type { DevDomain } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { DOMAIN_STYLE, domainKey } from '../lib/domains';

/** Grafik tooltip — glass-popover. */
export function DevTooltip({ title, rows }: { title: ReactNode; rows: Array<{ key: string; label: ReactNode; value: ReactNode; swatch?: string; dash?: boolean }> }) {
  return (
    <div className="glass-popover rounded-xl px-3 py-2 text-xs">
      <p className="mb-1 font-semibold text-foreground">{title}</p>
      {rows.map((r) => (
        <p key={r.key} className="flex items-center gap-2 text-muted-foreground">
          {r.swatch && <span className={cn('h-0.5 w-3 rounded-full', r.dash && 'opacity-70')} style={{ background: r.swatch }} />}
          {r.label}: <span className="font-semibold tabular-nums text-foreground">{r.value}</span>
        </p>
      ))}
    </div>
  );
}

/** Soha chizig'i namunasi (rang + yaxlit/uzuq) — legenda uchun. */
export function DomainSwatch({ domain }: { domain: DevDomain }) {
  const style = DOMAIN_STYLE[domain];
  return (
    <svg width="18" height="8" aria-hidden className="shrink-0">
      <line x1="1" y1="4" x2="17" y2="4" stroke={style.color} strokeWidth="2.5" strokeDasharray={style.dash ? '4 3' : undefined} strokeLinecap="round" />
    </svg>
  );
}

export function DomainLegend({ domains }: { domains: readonly DevDomain[] }) {
  const { t } = useI18n();
  return (
    <ul className="mt-3 flex flex-wrap gap-x-4 gap-y-1.5 text-xs text-muted-foreground">
      {domains.map((d) => (
        <li key={d} className="flex items-center gap-1.5">
          <DomainSwatch domain={d} />
          {t(domainKey(d))}
        </li>
      ))}
    </ul>
  );
}

/** Yashirin katak/ustun uchun shtrixlangan fon. */
export const HATCH = 'bg-[repeating-linear-gradient(135deg,hsl(var(--muted-foreground)/0.22)_0_2px,transparent_2px_7px)]';
