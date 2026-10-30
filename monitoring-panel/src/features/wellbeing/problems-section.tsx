'use client';

import { LifeBuoy } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useMemo, useState } from 'react';

import { useCan } from '@/auth/use-session';
import { HeatTable } from '@/components/charts/heat-table';
import { ErrorState } from '@/components/common/error-state';
import { ExportMenu } from '@/components/common/export-menu';
import { Section } from '@/components/common/section';
import { Select, SelectContent, SelectItem, SelectSeparator, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Skeleton } from '@/components/ui/skeleton';
import type { AreaMatrix, Scope } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { useMetricFormat } from '@/lib/format';
import { useAreaCsv } from './kit/area-table';
import { BlockTitle } from './kit/chart-block';
import { findHotspots, type ProblemSort, rankProblems, sortAreaRows } from './problem-analysis';
import { PROBLEM_METRICS, problemLabelKey } from './problem-keys';
import { HotspotsPanel, WidespreadPanel } from './problem-summary';

/** Issiqlik jadvali tartibini tanlash: rasmiy, o'rtachadan jami oshish yoki bitta signal. */
function SortSelect({ value, onChange }: { value: ProblemSort; onChange: (v: ProblemSort) => void }) {
  const { t } = useI18n();
  return (
    <div className="flex items-center gap-2 text-[0.75rem] text-muted-foreground">
      <span aria-hidden>{t('wellbeing.problems.sort')}</span>
      <Select value={value} onValueChange={(v) => onChange(v as ProblemSort)}>
        <SelectTrigger aria-label={t('wellbeing.problems.sort')} className="h-8 w-[224px] rounded-lg text-[0.78rem]">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="official">{t('wellbeing.problems.sortOfficial')}</SelectItem>
          <SelectItem value="burden">{t('wellbeing.problems.sortBurden')}</SelectItem>
          <SelectSeparator />
          {PROBLEM_METRICS.map((m) => (
            <SelectItem key={m} value={m}>
              {t(problemLabelKey(m))}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}

function ProblemsBody({ scope, matrix }: { scope: Scope; matrix: AreaMatrix }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const router = useRouter();
  const can = useCan();
  const [sort, setSort] = useState<ProblemSort>('burden');
  const national = scope.kind === 'NATIONAL';
  const clickable = national && can('regions.view');
  const ranks = useMemo(() => rankProblems(matrix, PROBLEM_METRICS), [matrix]);
  const hotspots = useMemo(() => findHotspots(matrix, PROBLEM_METRICS), [matrix]);
  const rows = useMemo(() => sortAreaRows(matrix.rows, PROBLEM_METRICS, sort), [matrix, sort]);

  return (
    <div className="space-y-7">
      <div className="grid gap-6 xl:grid-cols-2 xl:gap-8">
        <WidespreadPanel ranks={ranks} />
        <HotspotsPanel scope={scope} hotspots={hotspots} total={PROBLEM_METRICS.length} />
      </div>
      <div>
        <div className="mb-2.5 flex flex-wrap items-center justify-between gap-2">
          <BlockTitle>{t('wellbeing.problems.matrix')}</BlockTitle>
          <SortSelect value={sort} onChange={setSort} />
        </div>
        <HeatTable
          columns={PROBLEM_METRICS.map((k) => ({ key: k, label: t(problemLabelKey(k)), better: 'down' as const }))}
          rows={rows.map((r) => ({
            id: r.id,
            label: areaName(r.id, { short: true, fallback: r.name }),
            values: Object.fromEntries(PROBLEM_METRICS.map((k) => [k, r.values[k]?.value ?? null])),
          }))}
          format={(v) => (v === null ? '—' : fmt.num(v, 1))}
          firstHeader={national ? t('nav.regions') : t('common.districtsTitle')}
          onRowClick={clickable ? (id) => router.push(`/regions/view?id=${id}`) : undefined}
          minWidth={640}
        />
        <p className="mt-2 text-[0.7rem] text-muted-foreground">{clickable ? t('dashboard.problemsHint') : t('dashboard.problemsHintDistrict')}</p>
      </div>
    </div>
  );
}

/**
 * "Bolalar o'rtasidagi muammolar — hududlar kesimida": eng keng tarqalgan
 * signallar, signallari o'rtachadan ko'p hududlar va to'liq issiqlik jadvali.
 */
export function ProblemsSection({
  id,
  scope,
  matrix,
  error,
  onRetry,
}: {
  id: string;
  scope: Scope;
  matrix: AreaMatrix | undefined;
  error: unknown;
  onRetry: () => void;
}) {
  const { t } = useI18n();
  const downloadCsv = useAreaCsv(scope, PROBLEM_METRICS);
  const national = scope.kind === 'NATIONAL';
  return (
    <Section
      id={id}
      className="scroll-mt-32"
      icon={<LifeBuoy />}
      title={national ? t('wellbeing.problems.title') : t('wellbeing.problems.titleDistrict')}
      subtitle={t('wellbeing.problems.subtitle')}
      actions={<ExportMenu disabled={!matrix} onCsv={matrix ? () => downloadCsv(t('wellbeing.problems.csvFile'), matrix.rows) : undefined} />}
    >
      {error ? (
        <ErrorState error={error} onRetry={onRetry} />
      ) : !matrix ? (
        <div className="space-y-6">
          <div className="grid gap-6 xl:grid-cols-2">
            <Skeleton className="h-[420px] rounded-xl" />
            <Skeleton className="h-[420px] rounded-xl" />
          </div>
          <Skeleton className="h-[480px] w-full rounded-xl" />
        </div>
      ) : (
        <ProblemsBody scope={scope} matrix={matrix} />
      )}
    </Section>
  );
}
