'use client';

import { BarChart3 } from 'lucide-react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Bar, BarChart, CartesianGrid, Cell, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import type { ClassToday } from '@/data/mock/services/dashboard';
import { useI18n } from '@/i18n';
import { ChartTooltip } from './chart-tooltip';

const GOOD = 95;
const WARN = 85;

function barColor(rate: number): string {
  if (rate >= GOOD) return 'hsl(var(--success))';
  if (rate >= WARN) return 'hsl(var(--chart-1))';
  return 'hsl(var(--warning))';
}

export function ClassesChart({ rows, loading }: { rows: ClassToday[] | null | undefined; loading: boolean }) {
  const { t } = useI18n();
  const router = useRouter();
  const data = (rows ?? []).filter((r) => r.total > 0 && r.arrived + r.absent > 0);

  return (
    <SectionCard
      title={t('dashboard.classes.title')}
      description={t('dashboard.classes.subtitle')}
      icon={<BarChart3 />}
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/attendance">{t('dashboard.classes.open')}</Link>
        </Button>
      }
    >
      {loading ? (
        <Skeleton className="h-64 w-full rounded-xl" />
      ) : data.length === 0 ? (
        <p className="flex h-64 items-center justify-center text-sm text-muted-foreground">{t('dashboard.feed.empty')}</p>
      ) : (
        <div className="h-64">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={data} margin={{ top: 8, right: 8, left: -18, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
              <XAxis dataKey="className" tickLine={false} axisLine={false} interval={0} tick={{ fontSize: 10, fill: 'hsl(var(--muted-foreground))' }} />
              <YAxis domain={[0, 100]} tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} tickFormatter={(v: number) => `${v}%`} />
              <Tooltip content={<ChartTooltip />} cursor={{ fill: 'hsl(var(--primary) / 0.06)' }} />
              <Bar
                dataKey="rate"
                name={t('dashboard.trend.rate')}
                unit="%"
                radius={[6, 6, 0, 0]}
                maxBarSize={28}
                className="cursor-pointer"
                onClick={(entry: { payload?: ClassToday }) => entry.payload && router.push(`/attendance/class?id=${entry.payload.classId}`)}
              >
                {data.map((r) => (
                  <Cell key={r.classId} fill={barColor(r.rate)} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
    </SectionCard>
  );
}
