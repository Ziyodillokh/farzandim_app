'use client';

import { ChartColumnBig, TrendingUp } from 'lucide-react';
import { Bar, BarChart, CartesianGrid, ComposedChart, Legend, Line, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { SectionCard } from '@/components/common/section-card';
import type { ActivityWeek, ClassActivityRow } from '@/data/mock/services/learning';
import { ChartTooltip } from '@/features/dashboard/components/chart-tooltip';
import { useI18n } from '@/i18n';

const AXIS_TICK = { fontSize: 11, fill: 'hsl(var(--muted-foreground))' };
const CURSOR = { fill: 'hsl(var(--primary) / 0.06)' };

type WeekTooltipEntry = { dataKey?: unknown; name?: string | number; value?: number | string | null; color?: string; unit?: string | number; payload?: ActivityWeek };

/** Shtrixli ustun tooltip'ga kirmaydi; yashirin haftada topshiriqlar "—", ostida sababi. */
function WeeklyTooltip({ active, label, payload = [], hiddenNote }: { active?: boolean; label?: string | number; payload?: WeekTooltipEntry[]; hiddenNote: string }) {
  const rows = payload.filter((p) => p.dataKey !== 'ghost');
  return <ChartTooltip active={active} label={label} payload={rows} note={rows[0]?.payload?.suppressed ? hiddenNote : undefined} />;
}

/**
 * Haftalik dinamika: bajarilgan topshiriqlar (ustun) va faol o'quvchilar (chiziq).
 * Yashirin hafta (K=5) — topshiriqlar null (0 ga aylantirilmaydi): o'rnida shtrixli ustun, tooltip'da sababi.
 */
export function WeeklyActivityChart({ weeks }: { weeks: ActivityWeek[] }) {
  const { t, formatDate } = useI18n();
  // Shtrixli ustun — eng baland hafta bo'yi; topshiriq soni umuman yo'q bo'lsa chap o'q yashiriladi (soxta shkala chiqmasin).
  const maxTasks = Math.max(0, ...weeks.map((w) => w.completedTasks ?? 0));
  const data = weeks.map((w) => ({ ...w, label: formatDate(w.weekStart, 'd MMM'), ghost: w.suppressed ? Math.max(1, maxTasks) : null }));
  return (
    <SectionCard title={t('learning.activity.trendTitle')} description={t('learning.activity.trendHint')} icon={<TrendingUp />}>
      <div className="h-64">
        <ResponsiveContainer width="100%" height="100%">
          <ComposedChart data={data} margin={{ top: 8, right: 4, bottom: 0, left: -12 }}>
            <defs>
              <linearGradient id="learning-tasks-fill" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="hsl(var(--chart-1))" stopOpacity={0.95} />
                <stop offset="100%" stopColor="hsl(var(--chart-1))" stopOpacity={0.45} />
              </linearGradient>
              <pattern id="learning-tasks-hatch" width="7" height="7" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
                <line x1="0" y1="0" x2="0" y2="7" stroke="hsl(var(--muted-foreground) / 0.25)" strokeWidth="2" />
              </pattern>
            </defs>
            <CartesianGrid vertical={false} stroke="hsl(var(--border))" strokeDasharray="3 3" />
            <XAxis dataKey="label" tick={AXIS_TICK} axisLine={false} tickLine={false} />
            <YAxis yAxisId="tasks" hide={maxTasks === 0} allowDecimals={false} tick={AXIS_TICK} axisLine={false} tickLine={false} />
            <YAxis yAxisId="active" orientation="right" allowDecimals={false} tick={AXIS_TICK} axisLine={false} tickLine={false} />
            <Tooltip content={<WeeklyTooltip hiddenNote={t('learning.activity.suppressedTotal')} />} cursor={CURSOR} filterNull={false} />
            {/* Ikon turi seriyalarda (legendType): Legend'dagi iconType hammasini, shu jumladan shtrixli ustunni ham legendaga chiqarardi. */}
            <Legend iconSize={8} wrapperStyle={{ fontSize: 12 }} />
            <Bar
              yAxisId="tasks"
              dataKey="completedTasks"
              stackId="tasks"
              name={t('learning.activity.seriesTasks')}
              fill="url(#learning-tasks-fill)"
              radius={[8, 8, 0, 0]}
              maxBarSize={36}
              legendType="circle"
            />
            <Bar yAxisId="tasks" dataKey="ghost" stackId="tasks" fill="url(#learning-tasks-hatch)" radius={[8, 8, 0, 0]} maxBarSize={36} legendType="none" />
            <Line
              yAxisId="active"
              type="monotone"
              dataKey="activeStudents"
              name={t('learning.activity.seriesActive')}
              stroke="hsl(var(--chart-5))"
              strokeWidth={2.5}
              dot={{ r: 3.5, fill: 'hsl(var(--card))', stroke: 'hsl(var(--chart-5))', strokeWidth: 2 }}
              activeDot={{ r: 5, strokeWidth: 2, stroke: 'hsl(var(--card))' }}
              legendType="circle"
            />
          </ComposedChart>
        </ResponsiveContainer>
      </div>
    </SectionCard>
  );
}

/** Sinflar kesimida faol o'quvchilar ulushi (oxirgi yakunlangan hafta). */
export function ClassRateChart({ classes }: { classes: ClassActivityRow[] }) {
  const { t } = useI18n();
  const dense = classes.length > 12;
  return (
    <SectionCard title={t('learning.activity.classesTitle')} description={t('learning.activity.classesHint')} icon={<ChartColumnBig />}>
      <div className="h-64">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={classes} margin={{ top: 8, right: 4, bottom: 0, left: -18 }}>
            <defs>
              <linearGradient id="learning-rate-fill" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="hsl(var(--chart-5))" stopOpacity={0.95} />
                <stop offset="100%" stopColor="hsl(var(--chart-1))" stopOpacity={0.55} />
              </linearGradient>
            </defs>
            <CartesianGrid vertical={false} stroke="hsl(var(--border))" strokeDasharray="3 3" />
            <XAxis
              dataKey="className"
              tick={AXIS_TICK}
              axisLine={false}
              tickLine={false}
              interval={0}
              angle={dense ? -45 : 0}
              textAnchor={dense ? 'end' : 'middle'}
              height={dense ? 44 : 24}
            />
            <YAxis domain={[0, 100]} tick={AXIS_TICK} axisLine={false} tickLine={false} unit="%" />
            <Tooltip content={<ChartTooltip />} cursor={CURSOR} />
            <Bar dataKey="activeRate" name={t('learning.activity.seriesRate')} unit="%" fill="url(#learning-rate-fill)" radius={[8, 8, 0, 0]} maxBarSize={40} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </SectionCard>
  );
}
