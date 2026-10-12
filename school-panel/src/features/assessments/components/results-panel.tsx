'use client';

import { AlertTriangle, CalendarClock, FileSpreadsheet, Gauge, ListChecks, Users } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { ExportMenu } from '@/components/common/export-menu';
import { ScreeningDisclaimer } from '@/components/common/screening-disclaimer';
import { StatCard } from '@/components/common/stat-card';
import { FilterSelect, Toolbar } from '@/components/common/toolbar';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import type { ScoreBand } from '@/data/contracts';
import type { PsychTestRow, ResultsByTest } from '@/data/mock/services/assessments';
import { useI18n } from '@/i18n';
import { downloadCsv } from '@/lib/csv';
import { percent } from '@/lib/utils';
import { useClassOptions, useResults, useTests } from '../hooks';
import { bandLabel } from '../lib/labels';
import { BandChart } from './band-chart';
import { CsvImportDialog } from './csv-import-dialog';
import { ResultsTable } from './results-table';
import { viewHref } from './test-card';

function average(data: ResultsByTest | undefined, scaleKey: string | null): number | null {
  const values = (data?.rows ?? []).flatMap((r) => r.scales.find((s) => s.key === scaleKey)?.standard ?? []);
  return values.length ? Math.round(values.reduce((a, b) => a + b, 0) / values.length) : null;
}

function Stats({ data, test, loading }: { data: ResultsByTest | undefined; test: PsychTestRow | undefined; loading: boolean }) {
  const { t, formatDate } = useI18n();
  const p = data?.participation ?? { invited: 0, completed: 0 };
  const rate = percent(p.completed, p.invited);
  const scale = test?.scales.find((s) => s.key === data?.scaleKey);
  const avg = scale?.display === 'STANDARD' ? average(data, data?.scaleKey ?? null) : null;
  const latest = data?.rows[0]?.takenAt;
  return (
    <div className="grid gap-4 sm:grid-cols-3 lg:grid-cols-1">
      <StatCard
        icon={<Users />}
        label={t('assessments.results.participation')}
        value={`${rate}%`}
        hint={t('assessments.results.participationHint', { completed: p.completed, invited: p.invited })}
        loading={loading}
        footer={!loading && <Progress value={rate} className="h-1.5" />}
      />
      {avg !== null ? (
        <StatCard icon={<Gauge />} tone="info" label={t('assessments.results.average')} value={avg} hint={t('assessments.results.averageHint')} loading={loading} />
      ) : (
        <StatCard icon={<ListChecks />} tone="info" label={t('assessments.results.count')} value={data?.rows.length ?? 0} loading={loading} />
      )}
      <StatCard
        icon={<CalendarClock />}
        tone="muted"
        label={t('assessments.results.latest')}
        value={<span className="text-xl">{latest ? formatDate(latest, 'd MMM') : t('assessments.results.noLatest')}</span>}
        hint={latest ? formatDate(latest, 'HH:mm, yyyy') : undefined}
        loading={loading}
      />
    </div>
  );
}

/** Test natijalari: taqsimot, ishtirok va o'quvchilar jadvali. `onTestChange` bo'lsa — test tanlovi. */
export function ResultsPanel({
  testId,
  onTestChange,
  showDisclaimer = true,
}: {
  testId: string | undefined;
  onTestChange?: (id: string) => void;
  showDisclaimer?: boolean;
}) {
  const { t, locale, formatDate } = useI18n();
  const tests = useTests();
  const classes = useClassOptions();
  const [classId, setClassId] = useState<string | undefined>();
  const [scaleKey, setScaleKey] = useState<string | undefined>();
  const [csvOpen, setCsvOpen] = useState(false);
  const test = tests.data?.find((x) => x.id === testId);
  const results = useResults(test?.id, { classId, scale: scaleKey });
  const data = results.data;
  const scored = (test?.scales ?? []).filter((s) => s.display !== 'RAW');
  const scale = test?.scales.find((s) => s.key === data?.scaleKey) ?? test?.scales[0];
  const loading = tests.isLoading || results.isLoading;
  const choices = (tests.data ?? []).filter((x) => x.resultsCount > 0 || x.id === testId);
  const testClasses = (classes.data ?? []).filter((c) => !test || test.grades.includes(c.grade));

  const exportCsv = () =>
    downloadCsv(`${t('assessments.results.exportFile')}-${test?.id ?? ''}`, data?.rows ?? [], [
      { header: t('assessments.results.columns.student'), value: (r) => r.studentName },
      { header: t('assessments.results.columns.class'), value: (r) => r.className },
      { header: t('assessments.results.columns.date'), value: (r) => formatDate(r.takenAt, 'yyyy-MM-dd') },
      { header: t('assessments.results.standard'), value: (r) => r.scales.find((s) => s.key === scale?.key)?.standard ?? '' },
      { header: t('assessments.results.columns.band'), value: (r) => (r.scales.find((s) => s.key === scale?.key)?.band ? bandLabel(t, r.scales.find((s) => s.key === scale?.key)?.band as ScoreBand) : r.topCodes ?? '') },
      { header: t('assessments.results.columns.origin'), value: (r) => t(`assessments.results.origin.${r.origin}`) },
    ]);

  if (tests.error) return <ErrorState error={tests.error} onRetry={() => void tests.refetch()} />;

  return (
    <div className="space-y-6">
      <Toolbar className="mb-0">
        {onTestChange && (
          <Select value={test?.id} onValueChange={(v) => { setScaleKey(undefined); onTestChange(v); }}>
            <SelectTrigger className="w-full sm:w-80" aria-label={t('assessments.results.test')} data-testid="results-test">
              <SelectValue placeholder={t('assessments.results.test')} />
            </SelectTrigger>
            <SelectContent>
              {choices.map((x) => (
                <SelectItem key={x.id} value={x.id}>
                  {x.title[locale]}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        )}
        <FilterSelect
          value={classId}
          onChange={setClassId}
          options={testClasses.map((c) => ({ value: c.id, label: c.name }))}
          allLabel={`${t('assessments.results.class')}: ${t('common.all')}`}
          className="sm:w-44"
        />
        {scored.length > 1 && (
          <Select value={data?.scaleKey ?? undefined} onValueChange={setScaleKey}>
            <SelectTrigger className="w-full sm:w-48" aria-label={t('assessments.results.scale')}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {scored.map((s) => (
                <SelectItem key={s.key} value={s.key}>
                  {s.label[locale]}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        )}
        <div className="flex w-full gap-2 sm:ml-auto sm:w-auto">
          <Button variant="outline" className="flex-1 sm:flex-none" onClick={() => setCsvOpen(true)}>
            <FileSpreadsheet />
            {t('assessments.results.csvImport')}
          </Button>
          <ExportMenu onCsv={exportCsv} disabled={!data?.rows.length} />
        </div>
      </Toolbar>

      {showDisclaimer && <ScreeningDisclaimer variant="banner" withIq={test?.kind === 'COGNITIVE'} />}

      {!testId && !loading ? (
        <Card>
          <EmptyState icon={<ListChecks />} title={t('assessments.results.noTests')} description={t('assessments.results.emptyHint')} />
        </Card>
      ) : results.error ? (
        <ErrorState error={results.error} onRetry={() => void results.refetch()} />
      ) : (
        <>
          {data?.needsNorms && test && (
            <div className="flex flex-wrap items-center gap-3 rounded-2xl bg-warning/10 p-4 text-sm ring-1 ring-inset ring-warning/25">
              <AlertTriangle className="h-5 w-5 shrink-0 text-warning" />
              <span className="flex-1">{t('assessments.results.needsNorms')}</span>
              <Button asChild size="sm" variant="outline">
                <Link href={viewHref(test.id, 'norms')}>{t('assessments.results.addNorms')}</Link>
              </Button>
            </div>
          )}
          <div className="grid gap-6 lg:grid-cols-3">
            <div className="lg:col-span-2">
              <BandChart distribution={data?.distribution} loading={loading} career={test?.kind === 'CAREER'} scales={test?.scales ?? []} />
            </div>
            <Stats data={data} test={test} loading={loading} />
          </div>
          <section className="space-y-3">
            <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
              <h2 className="font-display text-lg font-semibold tracking-[-0.01em]">
                {t('assessments.results.students')} <span className="ml-1 text-sm font-medium tabular-nums text-muted-foreground">{data?.rows.length ?? ''}</span>
              </h2>
              <p className="text-sm text-muted-foreground">{t('assessments.results.studentsHint')}</p>
            </div>
            <ResultsTable rows={data?.rows} loading={loading} scale={scale} kind={test?.kind} />
          </section>
        </>
      )}
      <CsvImportDialog open={csvOpen} onOpenChange={setCsvOpen} />
    </div>
  );
}
