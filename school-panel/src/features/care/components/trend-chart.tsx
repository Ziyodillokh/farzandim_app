'use client';

import { TrendingUp } from 'lucide-react';
import { Area, AreaChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { EmptyState } from '@/components/common/empty-state';
import { SectionCard } from '@/components/common/section-card';
import { Skeleton } from '@/components/ui/skeleton';
import type { CareAggregate } from '@/data/contracts';
import { useI18n } from '@/i18n';

type Point = { label: string; wellbeing: number; respondents: number };

function TrendTooltip({ active, payload, respondentsLabel }: { active?: boolean; payload?: Array<{ payload?: Point }>; respondentsLabel: string }) {
  const point = payload?.[0]?.payload;
  if (!active || !point) return null;
  return (
    <div className="glass-popover rounded-xl px-3 py-2 text-xs">
      <p className="font-semibold">{point.label}</p>
      <p className="mt-0.5 tabular-nums text-muted-foreground">
        <span className="font-semibold text-foreground">{point.wellbeing}</span>/100 · {respondentsLabel}: {point.respondents}
      </p>
    </div>
  );
}

/** O'zini his qilish indeksi — oxirgi 4 so'rovnoma (faqat k ≥ 5 bo'lgan haftalar). */
export function TrendChart({ aggregate, loading }: { aggregate: CareAggregate | undefined; loading?: boolean }) {
  const { t, formatDate } = useI18n();
  const data: Point[] = (aggregate?.weeklyTrend ?? []).map((p) => ({
    label: formatDate(p.weekStart, 'd MMM'),
    wellbeing: p.wellbeing,
    respondents: p.respondents,
  }));

  return (
    <SectionCard title={t('care.overview.trendTitle')} description={t('care.overview.trendHint')} icon={<TrendingUp />}>
      {loading && !aggregate ? (
        <Skeleton className="h-56 w-full rounded-xl" />
      ) : data.length < 2 ? (
        <EmptyState title={t('care.overview.trendEmpty')} className="py-10" />
      ) : (
        <div className="h-56 animate-fade-in">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={data} margin={{ top: 8, right: 12, bottom: 0, left: -18 }}>
              <defs>
                <linearGradient id="care-trend-fill" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="hsl(var(--chart-5))" stopOpacity={0.28} />
                  <stop offset="100%" stopColor="hsl(var(--chart-5))" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid vertical={false} stroke="hsl(var(--border))" strokeDasharray="3 3" />
              <XAxis dataKey="label" tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} />
              <YAxis domain={[0, 100]} ticks={[0, 25, 50, 75, 100]} tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} />
              <Tooltip content={<TrendTooltip respondentsLabel={t('care.overview.respondents')} />} />
              <Area
                type="monotone"
                dataKey="wellbeing"
                stroke="hsl(var(--chart-5))"
                strokeWidth={2.5}
                fill="url(#care-trend-fill)"
                dot={{ r: 4, fill: 'hsl(var(--card))', stroke: 'hsl(var(--chart-5))', strokeWidth: 2 }}
                activeDot={{ r: 5 }}
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      )}
    </SectionCard>
  );
}
