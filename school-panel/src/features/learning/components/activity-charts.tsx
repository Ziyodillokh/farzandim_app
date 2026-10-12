'use client';

import { Bar, BarChart, CartesianGrid, ComposedChart, Legend, Line, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { SectionCard } from '@/components/common/section-card';
import type { ActivityWeek, ClassActivityRow } from '@/data/mock/services/learning';
import { useI18n } from '@/i18n';

const AXIS_TICK = { fontSize: 11, fill: 'hsl(var(--muted-foreground))' };
const TOOLTIP_STYLE = {
  borderRadius: 10,
  border: '1px solid hsl(var(--border))',
  background: 'hsl(var(--popover))',
  color: 'hsl(var(--popover-foreground))',
  fontSize: 12,
};

/** Haftalik dinamika: bajarilgan topshiriqlar (ustun) va faol o'quvchilar (chiziq). */
export function WeeklyActivityChart({ weeks }: { weeks: ActivityWeek[] }) {
  const { t, formatDate } = useI18n();
  const data = weeks.map((w) => ({ ...w, label: formatDate(w.weekStart, 'd MMM') }));
  return (
    <SectionCard title={t('learning.activity.trendTitle')} description={t('learning.activity.trendHint')}>
      <div className="h-64">
        <ResponsiveContainer width="100%" height="100%">
          <ComposedChart data={data} margin={{ top: 8, right: 4, bottom: 0, left: -12 }}>
            <CartesianGrid vertical={false} stroke="hsl(var(--border))" strokeDasharray="3 3" />
            <XAxis dataKey="label" tick={AXIS_TICK} axisLine={false} tickLine={false} />
            <YAxis yAxisId="tasks" tick={AXIS_TICK} axisLine={false} tickLine={false} />
            <YAxis yAxisId="active" orientation="right" tick={AXIS_TICK} axisLine={false} tickLine={false} />
            <Tooltip contentStyle={TOOLTIP_STYLE} cursor={{ fill: 'hsl(var(--muted) / 0.5)' }} />
            <Legend iconType="circle" iconSize={8} wrapperStyle={{ fontSize: 12 }} />
            <Bar
              yAxisId="tasks"
              dataKey="completedTasks"
              name={t('learning.activity.seriesTasks')}
              fill="hsl(var(--chart-1))"
              fillOpacity={0.85}
              radius={[6, 6, 0, 0]}
              maxBarSize={36}
            />
            <Line
              yAxisId="active"
              type="monotone"
              dataKey="activeStudents"
              name={t('learning.activity.seriesActive')}
              stroke="hsl(var(--chart-2))"
              strokeWidth={2.5}
              dot={{ r: 3.5, fill: 'hsl(var(--card))', strokeWidth: 2 }}
            />
          </ComposedChart>
        </ResponsiveContainer>
      </div>
    </SectionCard>
  );
}

/** Sinflar kesimida faol o'quvchilar ulushi (joriy hafta). */
export function ClassRateChart({ classes }: { classes: ClassActivityRow[] }) {
  const { t } = useI18n();
  return (
    <SectionCard title={t('learning.activity.classesTitle')} description={t('learning.activity.classesHint')}>
      <div className="h-64">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={classes} margin={{ top: 8, right: 4, bottom: 0, left: -18 }}>
            <CartesianGrid vertical={false} stroke="hsl(var(--border))" strokeDasharray="3 3" />
            <XAxis dataKey="className" tick={AXIS_TICK} axisLine={false} tickLine={false} interval={0} angle={classes.length > 12 ? -45 : 0} textAnchor={classes.length > 12 ? 'end' : 'middle'} height={classes.length > 12 ? 44 : 24} />
            <YAxis domain={[0, 100]} tick={AXIS_TICK} axisLine={false} tickLine={false} unit="%" />
            <Tooltip contentStyle={TOOLTIP_STYLE} cursor={{ fill: 'hsl(var(--muted) / 0.5)' }} formatter={(value) => [`${String(value)}%`, t('learning.activity.seriesRate')]} />
            <Bar dataKey="activeRate" name={t('learning.activity.seriesRate')} fill="hsl(var(--chart-5))" radius={[6, 6, 0, 0]} maxBarSize={40} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </SectionCard>
  );
}
