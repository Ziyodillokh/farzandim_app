'use client';

import { CalendarCheck, Clock, UserX, Users } from 'lucide-react';

import { StatCard } from '@/components/common/stat-card';
import type { MonthlyReport } from '@/data/mock/services/reports';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import {
  AttendanceTable,
  CareSection,
  LearningSection,
  MessagesSection,
  ParentsTable,
  SchoolModeSection,
  WeekdayChart,
} from './report-sections';

/** Oylik hisobot tanasi — ekran (/reports) va chop etish (/reports/print) uchun umumiy. */
export function ReportBody({ report, print = false }: { report: MonthlyReport; print?: boolean }) {
  const { t, formatNumber } = useI18n();
  const a = report.attendance;
  const p = report.parents;
  // Chop etishda ustunlar o'rniga ketma-ket bloklar (A4 kengligi tor).
  const grid = print ? 'space-y-6' : 'grid gap-6 lg:grid-cols-3';
  const wide = print ? '' : 'lg:col-span-2';
  const stack = 'min-w-0 space-y-6';

  return (
    <div className="space-y-6">
      <div className={cn('grid gap-4', print ? 'grid-cols-4' : 'sm:grid-cols-2 xl:grid-cols-4')}>
        {a && (
          <>
            <StatCard icon={<CalendarCheck />} tone="success" label={t('reports.kpi.attendance')} value={`${a.rate}%`} />
            <StatCard icon={<Clock />} tone="warning" label={t('reports.kpi.late')} value={formatNumber(a.late)} />
            <StatCard icon={<UserX />} tone="destructive" label={t('reports.kpi.absent')} value={formatNumber(a.absent)} />
          </>
        )}
        {p && <StatCard icon={<Users />} tone="info" label={t('reports.kpi.parents')} value={`${p.rate}%`} hint={`${p.linkedStudents} / ${p.totalStudents}`} />}
      </div>

      <div className={grid}>
        <div className={cn(stack, wide)}>{a && <AttendanceTable data={a} print={print} />}</div>
        <div className={stack}>
          {a && <WeekdayChart data={a} print={print} />}
          {report.schoolMode && <SchoolModeSection data={report.schoolMode} />}
          {report.messages && <MessagesSection data={report.messages} />}
        </div>
      </div>

      <div className={cn(grid, print && 'print-break')}>
        <div className={stack}>{p && <ParentsTable data={p} />}</div>
        <div className={cn(stack, wide)}>
          {report.care && <CareSection data={report.care} />}
          {report.learning && <LearningSection data={report.learning} />}
        </div>
      </div>
    </div>
  );
}
