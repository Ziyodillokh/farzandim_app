'use client';

import { Award, BarChart3, CircleCheck, TrendingDown, TrendingUp, Users } from 'lucide-react';
import { useMemo } from 'react';

import { DataTable, type Column } from '@/components/common/data-table';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { StatCard } from '@/components/common/stat-card';
import { Badge } from '@/components/ui/badge';
import { Progress } from '@/components/ui/progress';
import { Skeleton } from '@/components/ui/skeleton';
import type { ClassActivityRow } from '@/data/mock/services/learning';
import { useI18n } from '@/i18n';
import { cn, percent } from '@/lib/utils';
import { useLearningActivity } from '../hooks';
import { ClassRateChart, WeeklyActivityChart } from './activity-charts';
import { InterestsCard } from './interests-card';

function Delta({ value, label }: { value: number; label: string }) {
  const up = value >= 0;
  const Icon = up ? TrendingUp : TrendingDown;
  return (
    <span className={cn('inline-flex items-center gap-1', up ? 'text-success' : 'text-warning')}>
      <Icon className="h-3.5 w-3.5" />
      {label}
    </span>
  );
}

const signed = (n: number) => (n > 0 ? `+${n}` : String(n));

/** Sinf darajasidagi faollik (shaxsiy reyting yo'q). Sinf rahbari — faqat o'z sinfi. */
export function ActivityTab() {
  const { t, formatNumber } = useI18n();
  const activity = useLearningActivity();
  const data = activity.data;
  const last = data?.weeks.at(-1);
  const prev = data?.weeks.at(-2);
  const totalSize = data?.classes.reduce((s, c) => s + c.size, 0) ?? 0;

  const columns = useMemo<Column<ClassActivityRow>[]>(
    () => [
      { key: 'class', header: t('learning.activity.columns.class'), cell: (r) => <Badge variant="outline">{r.className}</Badge> },
      {
        key: 'active',
        header: t('learning.activity.columns.active'),
        className: 'tabular-nums',
        cell: (r) => (
          <span>
            <span className="font-semibold">{r.activeStudents}</span>
            <span className="text-muted-foreground"> / {r.size}</span>
          </span>
        ),
      },
      {
        key: 'rate',
        header: t('learning.activity.columns.rate'),
        cell: (r) => (
          <div className="flex min-w-[110px] items-center gap-2">
            <Progress value={r.activeRate} className="h-1.5 flex-1" />
            <span className="w-9 text-right text-xs font-semibold tabular-nums">{r.activeRate}%</span>
          </div>
        ),
      },
      { key: 'tasks', header: t('learning.activity.columns.tasks'), className: 'tabular-nums', cell: (r) => formatNumber(r.completedTasks) },
      { key: 'score', header: t('learning.activity.columns.score'), className: 'tabular-nums', cell: (r) => r.avgScore },
      { key: 'don', header: t('learning.activity.columns.don'), className: 'tabular-nums', cell: (r) => formatNumber(r.donPoints) },
      {
        key: 'delta',
        header: t('learning.activity.columns.delta'),
        className: 'whitespace-nowrap text-xs',
        cell: (r) => <Delta value={r.activeDelta} label={signed(r.activeDelta)} />,
      },
    ],
    [t, formatNumber],
  );

  if (activity.error) return <ErrorState error={activity.error} onRetry={() => void activity.refetch()} />;
  if (!activity.isLoading && !last) return <EmptyState icon={<BarChart3 />} title={t('learning.activity.empty')} />;

  const loading = activity.isLoading;
  const deltaLabel = (cur: number, before: number | undefined) =>
    before === undefined ? undefined : <Delta value={cur - before} label={t('learning.activity.vsLastWeek', { delta: signed(cur - before) })} />;

  return (
    <div className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          icon={<Users />}
          label={t('learning.activity.activeStudents')}
          value={formatNumber(last?.activeStudents ?? 0)}
          hint={
            <span className="flex flex-col gap-0.5">
              {t('learning.activity.activeHint', { rate: percent(last?.activeStudents ?? 0, totalSize) })}
              {last && deltaLabel(last.activeStudents, prev?.activeStudents)}
            </span>
          }
          loading={loading}
        />
        <StatCard
          icon={<CircleCheck />}
          tone="success"
          label={t('learning.activity.completedTasks')}
          value={formatNumber(last?.completedTasks ?? 0)}
          hint={last && deltaLabel(last.completedTasks, prev?.completedTasks)}
          loading={loading}
        />
        <StatCard
          icon={<BarChart3 />}
          tone="info"
          label={t('learning.activity.avgScore')}
          value={`${last?.avgScore ?? 0}`}
          hint={last && deltaLabel(last.avgScore, prev?.avgScore)}
          loading={loading}
        />
        <StatCard
          icon={<Award />}
          tone="warning"
          label={t('learning.activity.donPoints')}
          value={formatNumber(last?.donPoints ?? 0)}
          hint={t('learning.activity.donHint')}
          loading={loading}
        />
      </div>

      {loading || !data ? (
        <div className="grid gap-6 xl:grid-cols-2">
          <Skeleton className="h-80 rounded-xl" />
          <Skeleton className="h-80 rounded-xl" />
        </div>
      ) : (
        <div className="grid gap-6 xl:grid-cols-2 animate-fade-in">
          <WeeklyActivityChart weeks={data.weeks} />
          <ClassRateChart classes={data.classes} />
        </div>
      )}

      <section>
        <h2 className="mb-3 text-[0.95rem] font-semibold">{t('learning.activity.tableTitle')}</h2>
        <DataTable columns={columns} rows={data?.classes} rowKey={(r) => r.classId} loading={loading} skeletonRows={6} />
      </section>

      <InterestsCard />
    </div>
  );
}
