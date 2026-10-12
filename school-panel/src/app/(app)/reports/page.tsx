'use client';

import { FileText } from 'lucide-react';
import { useMemo, useState } from 'react';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { ExportMenu } from '@/components/common/export-menu';
import { PageHeader } from '@/components/common/page-header';
import { Skeleton } from '@/components/ui/skeleton';
import { api } from '@/data/api';
import { MonthPicker } from '@/features/reports/components/month-picker';
import { ReportBody } from '@/features/reports/components/report-body';
import { useMonthlyReport } from '@/features/reports/hooks';
import { useI18n } from '@/i18n';
import { withBase } from '@/lib/base-path';
import { downloadCsv } from '@/lib/csv';

export default function ReportsPage() {
  const { t, formatDate } = useI18n();
  const months = useMemo(() => api.reports.months(), []);
  const [month, setMonth] = useState(() => months[0] ?? '');
  const report = useMonthlyReport(month);
  const r = report.data;

  const exportCsv = () => {
    if (!r?.attendance) return;
    downloadCsv(t('reports.csv.filename', { month }), r.attendance.byClass, [
      { header: t('reports.attendance.columns.class'), value: (x) => x.className },
      { header: t('reports.attendance.columns.students'), value: (x) => x.students },
      { header: `${t('reports.attendance.columns.rate')} %`, value: (x) => x.rate },
      { header: t('reports.attendance.columns.late'), value: (x) => x.late },
      { header: t('reports.attendance.columns.absent'), value: (x) => x.absent },
      { header: t('reports.attendance.columns.excused'), value: (x) => x.excused },
    ]);
  };

  return (
    <>
      <PageHeader
        title={t('reports.title')}
        subtitle={
          r ? (r.until ? t('reports.period', { from: formatDate(`${month}-01T12:00:00`, 'd MMMM'), to: formatDate(`${r.until}T12:00:00`, 'd MMMM'), days: r.schoolDays }) : t('reports.periodEmpty')) : t('reports.subtitle')
        }
        actions={
          <>
            <MonthPicker months={months} value={month} onChange={setMonth} />
            <ExportMenu
              disabled={!r}
              onCsv={r?.attendance ? exportCsv : undefined}
              onPrint={() => window.open(withBase(`/reports/print/?month=${month}&auto=1`), '_blank', 'noopener')}
            />
          </>
        }
      />
      {report.isError ? (
        <ErrorState error={report.error} onRetry={() => void report.refetch()} />
      ) : !r ? (
        <div className="space-y-6">
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            {Array.from({ length: 4 }).map((_, i) => (
              <Skeleton key={i} className="h-28 rounded-xl" />
            ))}
          </div>
          <Skeleton className="h-96 rounded-xl" />
        </div>
      ) : !r.until ? (
        <EmptyState icon={<FileText />} title={t('reports.periodEmpty')} />
      ) : (
        <ReportBody report={r} />
      )}
    </>
  );
}
