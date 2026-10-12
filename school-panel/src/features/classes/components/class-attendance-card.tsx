'use client';

import { CalendarOff } from 'lucide-react';
import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from 'recharts';

import { EmptyState } from '@/components/common/empty-state';
import { SectionCard } from '@/components/common/section-card';
import { Skeleton } from '@/components/ui/skeleton';
import type { ClassBoardRow, DayCounts } from '@/data/mock/services/attendance';
import { type TKey, useI18n } from '@/i18n';

type Slice = { key: keyof Omit<DayCounts, 'total'>; label: TKey; color: string };

const SLICES: Slice[] = [
  { key: 'present', label: 'enums.attendanceStatus.PRESENT', color: 'hsl(var(--chart-2))' },
  { key: 'late', label: 'enums.attendanceStatus.LATE', color: 'hsl(var(--chart-3))' },
  { key: 'absent', label: 'enums.attendanceStatus.ABSENT', color: 'hsl(var(--chart-4))' },
  { key: 'leftEarly', label: 'enums.attendanceStatus.LEFT_EARLY', color: 'hsl(var(--chart-5))' },
  { key: 'excused', label: 'enums.attendanceStatus.EXCUSED', color: 'hsl(var(--chart-1))' },
  { key: 'pending', label: 'classes.card.noMarks', color: 'hsl(var(--muted))' },
];

const TOOLTIP_STYLE = {
  background: 'hsl(var(--card))',
  border: '1px solid hsl(var(--border))',
  borderRadius: 10,
  color: 'hsl(var(--card-foreground))',
  fontSize: 12,
};

/** Bugungi davomat: donut + izoh (sinf sahifasi). */
export function ClassAttendanceCard({ row, loading }: { row: ClassBoardRow | undefined; loading: boolean }) {
  const { t, formatNumber } = useI18n();

  const body = () => {
    if (loading) return <Skeleton className="mx-auto h-40 w-40 rounded-full" />;
    if (!row || !row.schoolDay) {
      return <EmptyState icon={<CalendarOff />} title={t('classes.view.noAttendance')} className="py-6" />;
    }
    const data = SLICES.map((s) => ({ ...s, name: t(s.label), value: row.counts[s.key] })).filter((d) => d.value > 0);
    return (
      <div className="grid items-center gap-4 sm:grid-cols-[160px_1fr] lg:grid-cols-1 xl:grid-cols-[160px_1fr]">
        <div className="relative mx-auto h-40 w-40">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie data={data} dataKey="value" nameKey="name" innerRadius={52} outerRadius={74} paddingAngle={2} stroke="none" isAnimationActive>
                {data.map((d) => (
                  <Cell key={d.key} fill={d.color} />
                ))}
              </Pie>
              <Tooltip contentStyle={TOOLTIP_STYLE} itemStyle={{ color: 'hsl(var(--card-foreground))' }} />
            </PieChart>
          </ResponsiveContainer>
          <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
            <span className="font-display text-2xl font-semibold tabular-nums">{row.rate}%</span>
            <span className="text-2xs uppercase tracking-wide text-muted-foreground">{t('classes.view.todayCenter')}</span>
          </div>
        </div>
        <ul className="space-y-1.5 text-sm">
          {SLICES.map((s) => (
            <li key={s.key} className="flex items-center justify-between gap-3">
              <span className="flex items-center gap-2 text-muted-foreground">
                <span className="h-2.5 w-2.5 rounded-full" style={{ background: s.color }} aria-hidden />
                {t(s.label)}
              </span>
              <span className="font-semibold tabular-nums">{formatNumber(row.counts[s.key])}</span>
            </li>
          ))}
        </ul>
      </div>
    );
  };

  return <SectionCard title={t('classes.view.todayTitle')}>{body()}</SectionCard>;
}
