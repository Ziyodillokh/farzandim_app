'use client';

import { TrendingUp } from 'lucide-react';
import { Area, AreaChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { SectionCard } from '@/components/common/section-card';
import { Skeleton } from '@/components/ui/skeleton';
import { useI18n } from '@/i18n';
import { useAttendanceTrend } from '../hooks';
import { ChartTooltip } from './chart-tooltip';

const MIN_Y = 70;

export function TrendChart() {
  const { t, formatDate } = useI18n();
  const trend = useAttendanceTrend();
  const data = (trend.data ?? []).map((d) => ({ ...d, label: d.date }));
  const minY = Math.min(MIN_Y, ...data.map((d) => Math.floor(d.rate / 10) * 10));
  const ticks = Array.from({ length: (100 - minY) / 10 + 1 }, (_, i) => minY + i * 10);

  return (
    <SectionCard title={t('dashboard.trend.title')} description={t('dashboard.trend.subtitle')} icon={<TrendingUp />}>
      {trend.isLoading ? (
        <Skeleton className="h-64 w-full rounded-xl" />
      ) : (
        <div className="h-64">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={data} margin={{ top: 8, right: 8, left: -18, bottom: 0 }}>
              <defs>
                <linearGradient id="rateFill" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="hsl(var(--chart-1))" stopOpacity={0.28} />
                  <stop offset="60%" stopColor="hsl(var(--chart-5))" stopOpacity={0.06} />
                  <stop offset="100%" stopColor="hsl(var(--chart-1))" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
              <XAxis
                dataKey="label"
                tickLine={false}
                axisLine={false}
                tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }}
                tickFormatter={(d: string) => formatDate(`${d}T12:00:00`, 'd MMM')}
                minTickGap={16}
              />
              <YAxis
                domain={[minY, 100]}
                ticks={ticks}
                tickLine={false}
                axisLine={false}
                tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }}
                tickFormatter={(v: number) => `${v}%`}
              />
              <Tooltip
                content={<ChartTooltip formatLabel={(d) => formatDate(`${d}T12:00:00`, 'EEEE, d MMMM')} />}
                cursor={{ stroke: 'hsl(var(--border))' }}
              />
              <Area
                type="monotone"
                dataKey="rate"
                name={t('dashboard.trend.rate')}
                stroke="hsl(var(--chart-1))"
                strokeWidth={2.5}
                fill="url(#rateFill)"
                dot={false}
                activeDot={{ r: 5, strokeWidth: 2, stroke: 'hsl(var(--card))' }}
                unit="%"
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      )}
    </SectionCard>
  );
}
