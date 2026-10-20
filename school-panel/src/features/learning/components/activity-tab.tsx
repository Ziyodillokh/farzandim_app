'use client';

import { Award, BarChart3, CalendarCheck, CircleCheck, Hourglass, Info, Minus, TrendingDown, TrendingUp, Users } from 'lucide-react';
import { useMemo } from 'react';

import { DataTable, type Column } from '@/components/common/data-table';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { StatCard } from '@/components/common/stat-card';
import { Badge } from '@/components/ui/badge';
import { Progress } from '@/components/ui/progress';
import { Skeleton } from '@/components/ui/skeleton';
import type { ClassActivityRow, LearningActivity } from '@/data/mock/services/learning';
import { isHttpMode } from '@/data/source';
import { useI18n } from '@/i18n';
import { cn, sharePercent } from '@/lib/utils';
import { useLearningActivity } from '../hooks';
import { ClassRateChart, WeeklyActivityChart } from './activity-charts';
import { InterestsCard } from './interests-card';

function Delta({ value, label }: { value: number; label: string }) {
  const Icon = value > 0 ? TrendingUp : value < 0 ? TrendingDown : Minus;
  const tone = value > 0 ? 'text-success' : value < 0 ? 'text-warning' : 'text-muted-foreground';
  return (
    <span className={cn('inline-flex items-center gap-1', tone)}>
      <Icon className="h-3.5 w-3.5" />
      {label}
    </span>
  );
}

const signed = (n: number) => (n > 0 ? `+${n}` : String(n));

const DASH = '—';
/** Natija bo'lmasa (yashirin yoki 0 faol) — null, aks holda formatlangan qiymat. */
const maybe = (n: number | null | undefined, format: (n: number) => string): string | null => (typeof n === 'number' ? format(n) : null);

/** Natija katagi (K=5): 5 nafardan kam faol — xira chiziqcha va izoh; 0 faol — oddiy chiziqcha. */
function ResultCell({ value, suppressed }: { value: string | null; suppressed: boolean }) {
  const { t } = useI18n();
  if (!suppressed) return <>{value ?? DASH}</>;
  const hint = t('learning.activity.suppressed');
  return (
    <span className="cursor-help text-muted-foreground/70" title={hint}>
      <span aria-hidden>{DASH}</span>
      <span className="sr-only">{hint}</span>
    </span>
  );
}

/**
 * Natijalar — oxirgi YAKUNLANGAN hafta (backend: joriy hafta katagi har yakunlashda o'zgaradi, ikki
 * o'qishdan bitta bolaning natijasi topilmasin); joriy hafta — faqat faollar soni.
 */
function WeekHeader({ data }: { data: LearningActivity }) {
  const { t, formatDate, formatNumber } = useI18n();
  return (
    <div className="flex flex-wrap items-center justify-between gap-x-4 gap-y-1.5">
      {data.latestWeek && (
        <p className="flex items-center gap-2 text-sm font-medium">
          <CalendarCheck className="h-4 w-4 shrink-0 text-primary" />
          {t('learning.activity.closedWeek', { date: formatDate(data.latestWeek, 'd MMMM') })}
        </p>
      )}
      {data.current && (
        <p className="flex items-center gap-2 text-xs text-muted-foreground">
          <Hourglass className="h-3.5 w-3.5 shrink-0" />
          {t('learning.activity.currentWeek', { count: formatNumber(data.current.activeStudents) })}
        </p>
      )}
    </div>
  );
}

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
      { key: 'tasks', header: t('learning.activity.columns.tasks'), className: 'tabular-nums', cell: (r) => <ResultCell value={maybe(r.completedTasks, formatNumber)} suppressed={r.suppressed} /> },
      { key: 'score', header: t('learning.activity.columns.score'), className: 'tabular-nums', cell: (r) => <ResultCell value={maybe(r.avgScore, String)} suppressed={r.suppressed} /> },
      { key: 'don', header: t('learning.activity.columns.don'), className: 'tabular-nums', cell: (r) => <ResultCell value={maybe(r.donPoints, formatNumber)} suppressed={r.suppressed} /> },
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
  if (!activity.isLoading && !last) {
    const current = data?.current ? t('learning.activity.currentWeek', { count: formatNumber(data.current.activeStudents) }) : undefined;
    return <EmptyState icon={<BarChart3 />} title={t('learning.activity.empty')} description={current} />;
  }

  const loading = activity.isLoading;
  // Hafta farqi — faqat ikkala hafta qiymati ham bor bo'lsa (yashirin hafta bilan solishtirilmaydi).
  const deltaLabel = (cur: number | null | undefined, before: number | null | undefined) =>
    typeof cur === 'number' && typeof before === 'number' ? <Delta value={cur - before} label={t('learning.activity.vsLastWeek', { delta: signed(cur - before) })} /> : undefined;
  // Hafta jami (bir nechta sinf) yashiriladi — faqat birorta sinfda ham 5 nafar faol bo'lmasa (jami 5 dan ko'p bo'lishi mumkin).
  const suppressedHint = last?.suppressed ? t('learning.activity.suppressedTotal') : undefined;
  // K=5 izohi: http rejimida doim; demoda — faqat biror natija yashirilganda (demo ko'rinishi o'zgarmasin).
  const showK5Note = isHttpMode || Boolean(data?.classes.some((c) => c.suppressed) || data?.weeks.some((w) => w.suppressed));

  return (
    <div className="space-y-6">
      {loading || !data ? <Skeleton className="h-5 w-72 max-w-full rounded-md" /> : <WeekHeader data={data} />}
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          icon={<Users />}
          label={t('learning.activity.activeStudents')}
          value={formatNumber(last?.activeStudents ?? 0)}
          hint={
            <span className="flex flex-col gap-0.5">
              {/* Faollar (o'tgan hafta) sinfning bugungi tarkibidan ko'p bo'lishi mumkin — 100% dan oshmaydi. */}
              {t('learning.activity.activeHint', { rate: sharePercent(last?.activeStudents ?? 0, totalSize) })}
              {deltaLabel(last?.activeStudents, prev?.activeStudents)}
            </span>
          }
          loading={loading}
        />
        <StatCard
          icon={<CircleCheck />}
          tone="success"
          label={t('learning.activity.completedTasks')}
          value={maybe(last?.completedTasks, formatNumber) ?? DASH}
          hint={suppressedHint ?? deltaLabel(last?.completedTasks, prev?.completedTasks)}
          loading={loading}
        />
        <StatCard
          icon={<BarChart3 />}
          tone="info"
          label={t('learning.activity.avgScore')}
          value={maybe(last?.avgScore, String) ?? DASH}
          hint={suppressedHint ?? deltaLabel(last?.avgScore, prev?.avgScore)}
          loading={loading}
        />
        <StatCard
          icon={<Award />}
          tone="warning"
          label={t('learning.activity.donPoints')}
          value={maybe(last?.donPoints, formatNumber) ?? DASH}
          hint={suppressedHint ?? t('learning.activity.donHint')}
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
        {showK5Note && (
          <p className="mt-3 flex items-start gap-2 text-xs text-muted-foreground">
            <Info className="mt-0.5 h-3.5 w-3.5 shrink-0" />
            {t('learning.activity.k5Note')}
          </p>
        )}
      </section>

      <InterestsCard />
    </div>
  );
}
