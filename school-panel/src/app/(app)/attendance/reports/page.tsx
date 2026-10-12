'use client';

import { CalendarX2 } from 'lucide-react';
import { useMemo, useState } from 'react';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { ExportMenu } from '@/components/common/export-menu';
import { PageHeader } from '@/components/common/page-header';
import { SectionCard } from '@/components/common/section-card';
import { Skeleton } from '@/components/ui/skeleton';
import { DailyRateChart } from '@/features/attendance/components/daily-rate-chart';
import { MatrixLegend, MonthMatrix } from '@/features/attendance/components/month-matrix';
import { monthDate, ReportFilters } from '@/features/attendance/components/report-filters';
import { ReportKpis } from '@/features/attendance/components/report-kpis';
import { useAttendanceClassOptions, useMonthReport } from '@/features/attendance/hooks';
import { EMPTY_COUNTS, fromIsoDate, sumCounts, useClockToday } from '@/features/attendance/lib';
import { useSchool } from '@/features/school/hooks';
import { useI18n } from '@/i18n';
import { downloadCsv } from '@/lib/csv';

const PRINT_LANDSCAPE = '@media print { @page { size: A4 landscape; margin: 10mm; } }';

export default function AttendanceReportsPage() {
  const { t, formatDate } = useI18n();
  const today = useClockToday();
  const currentMonth = today.slice(0, 7);
  const school = useSchool();
  const classes = useAttendanceClassOptions();
  const [month, setMonth] = useState(currentMonth);
  const [picked, setPicked] = useState<string>();
  const classId = picked ?? classes.data?.[0]?.id;
  const report = useMonthReport(month, classId);
  const data = report.data;

  const totals = useMemo(() => (data ? sumCounts(data.rows.map((r) => r.summary)) : EMPTY_COUNTS), [data]);
  const monthLabel = formatDate(monthDate(month), 'LLLL yyyy');

  const exportCsv = () => {
    if (!data) return;
    const code = (s: (typeof data.rows)[number]['cells'][number]) => t(`attendance.reports.codes.${s ?? 'none'}`);
    downloadCsv(t('attendance.reports.exportFile', { className: data.className, month }), data.rows, [
      { header: t('common.fullName'), value: (r) => r.name },
      ...data.days.map((d, i) => ({ header: formatDate(fromIsoDate(d), 'dd.MM'), value: (r: (typeof data.rows)[number]) => code(r.cells[i] ?? null) })),
      { header: t('attendance.stats.present'), value: (r) => r.summary.present },
      { header: t('attendance.stats.late'), value: (r) => r.summary.late },
      { header: t('attendance.stats.absent'), value: (r) => r.summary.absent },
      { header: t('attendance.stats.leftEarly'), value: (r) => r.summary.leftEarly },
      { header: t('attendance.stats.excused'), value: (r) => r.summary.excused },
      { header: t('attendance.stats.rate'), value: (r) => `${r.rate}%` },
    ]);
  };

  return (
    <>
      <style>{PRINT_LANDSCAPE}</style>
      <PageHeader
        title={t('attendance.reports.title')}
        subtitle={t('attendance.reports.subtitle')}
        actions={<ExportMenu onCsv={exportCsv} disabled={!data || data.days.length === 0} />}
      />
      <div className="print-only mb-4">
        <p className="text-lg font-semibold">{t('attendance.reports.title')}</p>
        <p className="text-sm capitalize">{t('attendance.reports.printMeta', { school: school.data?.school.name ?? '', className: data?.className ?? '', month: monthLabel })}</p>
      </div>

      <ReportFilters
        month={month}
        currentMonth={currentMonth}
        onMonthChange={setMonth}
        classId={classId}
        classes={classes.data}
        onClassChange={setPicked}
      />

      {report.error || classes.error ? (
        <ErrorState error={report.error ?? classes.error} onRetry={() => void report.refetch()} />
      ) : !data ? (
        <div className="space-y-6">
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
            {Array.from({ length: 5 }).map((_, i) => (
              <Skeleton key={i} className="h-24 rounded-xl" />
            ))}
          </div>
          <Skeleton className="h-96 rounded-xl" />
        </div>
      ) : data.days.length === 0 ? (
        <EmptyState icon={<CalendarX2 />} title={t('attendance.reports.noDays')} description={t('attendance.reports.noDaysHint')} />
      ) : (
        <div className={report.isFetching ? 'opacity-70 transition-opacity' : 'transition-opacity'}>
          <ReportKpis totals={totals} days={data.days.length} />
          <SectionCard title={t('attendance.reports.chartTitle')} description={t('attendance.reports.chartHint')} className="mb-6 no-print">
            <DailyRateChart report={data} />
          </SectionCard>
          <SectionCard
            title={`${t('attendance.reports.matrixTitle')} · ${data.className}`}
            description={<span className="capitalize">{monthLabel}</span>}
            bodyClassName="p-0"
          >
            <MonthMatrix report={data} />
            <div className="border-t px-4 py-3">
              <MatrixLegend />
            </div>
          </SectionCard>
        </div>
      )}
    </>
  );
}
