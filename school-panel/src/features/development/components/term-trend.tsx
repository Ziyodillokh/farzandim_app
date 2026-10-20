'use client';

import { TrendingUp } from 'lucide-react';
import { CartesianGrid, Line, LineChart, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { EmptyState } from '@/components/common/empty-state';
import { SectionCard } from '@/components/common/section-card';
import { Skeleton } from '@/components/ui/skeleton';
import type { DevDomain, SchoolDevOverview } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { DOMAIN_STYLE, DOMAINS, domainKey, formatTerm, shortTerm } from '../lib/domains';
import { DevTooltip, DomainLegend } from './chart-parts';

type Datum = { termKey: string; label: string; n: number } & Partial<Record<DevDomain, number>>;

/** Choraklar bo'yicha maktab o'rtacha indeksi (har soha — alohida chiziq). */
export function TermTrend({ overview, loading }: { overview: SchoolDevOverview | undefined; loading?: boolean }) {
  const { t } = useI18n();
  const data: Datum[] = (overview?.trend ?? []).map((p) => ({ termKey: p.termKey, label: shortTerm(p.termKey), n: p.n, ...p.values }));
  const present = DOMAINS.filter((d) => data.some((x) => typeof x[d] === 'number'));
  const values = data.flatMap((x) => present.map((d) => x[d]).filter((v): v is number => typeof v === 'number'));
  const lo = Math.max(0, Math.floor((Math.min(50, ...values) - 10) / 10) * 10);
  const hi = Math.min(100, Math.ceil((Math.max(50, ...values) + 10) / 10) * 10);

  return (
    <SectionCard title={t('development.charts.trendTitle')} description={t('development.charts.trendHint')} icon={<TrendingUp />}>
      {loading && !overview ? (
        <Skeleton className="h-60 w-full rounded-xl" />
      ) : data.length < 2 ? (
        <EmptyState title={t('development.empty.noResults')} className="py-10" />
      ) : (
        <>
          <div className="h-60 animate-fade-in">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={data} margin={{ top: 8, right: 12, bottom: 0, left: -18 }}>
                <CartesianGrid vertical={false} stroke="hsl(var(--border))" strokeDasharray="3 3" />
                <XAxis dataKey="label" tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} />
                <YAxis domain={[lo, hi]} allowDecimals={false} tickCount={5} tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} />
                <ReferenceLine y={50} stroke="hsl(var(--muted-foreground) / 0.5)" strokeDasharray="4 4" />
                <Tooltip
                  cursor={{ stroke: 'hsl(var(--primary) / 0.3)' }}
                  content={({ active, payload }) => {
                    const d = payload?.[0]?.payload as Datum | undefined;
                    if (!active || !d) return null;
                    const rows = present.map((dm) => ({ key: dm, label: t(domainKey(dm)), value: d[dm] ?? '—', swatch: DOMAIN_STYLE[dm].color, dash: Boolean(DOMAIN_STYLE[dm].dash) }));
                    return <DevTooltip title={`${formatTerm(d.termKey, t)} · n=${d.n}`} rows={rows} />;
                  }}
                />
                {present.map((d) => (
                  <Line
                    key={d}
                    type="monotone"
                    dataKey={d}
                    name={t(domainKey(d))}
                    stroke={DOMAIN_STYLE[d].color}
                    strokeDasharray={DOMAIN_STYLE[d].dash}
                    strokeWidth={2}
                    dot={{ r: 3.5, fill: 'hsl(var(--card))', stroke: DOMAIN_STYLE[d].color, strokeWidth: 2 }}
                    activeDot={{ r: 5 }}
                    connectNulls
                    isAnimationActive={false}
                  />
                ))}
              </LineChart>
            </ResponsiveContainer>
          </div>
          <DomainLegend domains={present} />
        </>
      )}
    </SectionCard>
  );
}
