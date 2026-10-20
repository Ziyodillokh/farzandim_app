'use client';

import { useId, useMemo } from 'react';
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { useI18n } from '@/i18n';
import { fromIsoDate } from '../lib';
import type { MonthReport } from './report-types';

type Point = { date: string; label: string; rate: number | null };

/** Kunlik davomat (bitta qator) — har o'quv kunida kelganlar ulushi. */
export function DailyRateChart({ report }: { report: MonthReport }) {
  const { formatDate } = useI18n();
  const gradientId = `rate-${useId().replace(/:/g, '')}`;

  const data = useMemo<Point[]>(
    () =>
      report.days.map((date, i) => {
        let attended = 0;
        let decided = 0;
        for (const row of report.rows) {
          const status = row.cells[i];
          if (!status) continue;
          decided += 1;
          if (status === 'PRESENT' || status === 'LATE' || status === 'LEFT_EARLY') attended += 1;
        }
        return { date, label: formatDate(fromIsoDate(date), 'd'), rate: decided ? Math.round((attended / decided) * 100) : null };
      }),
    [report, formatDate],
  );

  return (
    <div className="h-56 w-full">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} margin={{ top: 8, right: 4, bottom: 0, left: -18 }} barCategoryGap="22%">
          <defs>
            <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#508AFF" />
              <stop offset="100%" stopColor="#216BFF" />
            </linearGradient>
          </defs>
          <CartesianGrid vertical={false} stroke="hsl(var(--border))" strokeOpacity={0.7} strokeDasharray="3 3" />
          <XAxis dataKey="label" tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} interval={0} />
          <YAxis domain={[0, 100]} ticks={[0, 50, 100]} tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} unit="%" />
          <Tooltip
            cursor={{ fill: 'hsl(var(--primary) / 0.06)', radius: 8 }}
            content={({ active, payload }) => {
              const point = payload?.[0]?.payload as Point | undefined;
              if (!active || !point) return null;
              return (
                <div className="glass-popover rounded-xl px-3 py-2 text-xs">
                  <p className="font-medium text-muted-foreground">{formatDate(fromIsoDate(point.date), 'd MMMM, EEEE')}</p>
                  <p className="mt-0.5 font-display text-base font-semibold text-foreground">{point.rate === null ? '—' : `${point.rate}%`}</p>
                </div>
              );
            }}
          />
          <Bar dataKey="rate" fill={`url(#${gradientId})`} radius={[4, 4, 0, 0]} maxBarSize={22} isAnimationActive={false} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
