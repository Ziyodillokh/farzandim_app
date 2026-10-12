'use client';

import { ArrowLeft, Printer } from 'lucide-react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { Suspense, useEffect, useRef } from 'react';

import { ErrorState } from '@/components/common/error-state';
import { SchoolLogo } from '@/components/common/school-logo';
import { ParvozLogo } from '@/components/layout/parvoz-logo';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { clockToday } from '@/data/mock/clock';
import { ReportBody } from '@/features/reports/components/report-body';
import { useMonthlyReport } from '@/features/reports/hooks';
import { useSchool } from '@/features/school/hooks';
import { useI18n } from '@/i18n';

const PRINT_DELAY_MS = 700;

function PrintableReport() {
  const { t, formatDate } = useI18n();
  const params = useSearchParams();
  const month = params.get('month') ?? clockToday().slice(0, 7);
  const auto = params.get('auto') === '1';
  const report = useMonthlyReport(month);
  const school = useSchool();
  const printed = useRef(false);
  const r = report.data;

  useEffect(() => {
    if (!auto || !r || !school.data || printed.current) return;
    printed.current = true;
    const timer = window.setTimeout(() => window.print(), PRINT_DELAY_MS);
    return () => window.clearTimeout(timer);
  }, [auto, r, school.data]);

  if (report.isError) return <ErrorState error={report.error} onRetry={() => void report.refetch()} />;
  const monthLabel = formatDate(`${month}-15T12:00:00`, 'LLLL yyyy');

  return (
    <div className="mx-auto max-w-5xl">
      <div className="mb-6 flex items-center justify-between no-print">
        <Button asChild variant="ghost" size="sm">
          <Link href="/reports">
            <ArrowLeft />
            {t('reports.title')}
          </Link>
        </Button>
        <Button onClick={() => window.print()} disabled={!r}>
          <Printer />
          {t('reports.printPdf')}
        </Button>
      </div>

      <header className="mb-8 flex items-start justify-between gap-6 border-b pb-6">
        <div className="flex items-center gap-4">
          <SchoolLogo school={school.data?.school} className="h-14 w-14" />
          <div>
            <p className="text-sm text-muted-foreground">{school.data?.school.name}</p>
            <h1 className="font-display text-2xl font-semibold">
              {t('reports.printTitle')} — {monthLabel.charAt(0).toUpperCase() + monthLabel.slice(1)}
            </h1>
            {r?.until && (
              <p className="mt-1 text-sm text-muted-foreground">
                {t('reports.period', { from: formatDate(`${month}-01T12:00:00`, 'd MMMM'), to: formatDate(`${r.until}T12:00:00`, 'd MMMM'), days: r.schoolDays })}
              </p>
            )}
          </div>
        </div>
        <ParvozLogo className="h-8 w-auto shrink-0" />
      </header>

      {!r ? <Skeleton className="h-[600px] rounded-xl" /> : <ReportBody report={r} print />}

      {r && (
        <footer className="mt-10 border-t pt-4 text-xs text-muted-foreground">
          {t('reports.generated', { date: formatDate(r.generatedAt, 'dd.MM.yyyy HH:mm'), name: r.generatedBy })} · {t('common.appName')}
        </footer>
      )}
    </div>
  );
}

export default function ReportsPrintPage() {
  return (
    <Suspense>
      <PrintableReport />
    </Suspense>
  );
}
