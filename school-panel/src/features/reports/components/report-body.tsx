'use client';

import { CalendarCheck, Clock, UserX, Users } from 'lucide-react';
import type { ReactNode } from 'react';

import { StatCard, type Tone } from '@/components/common/stat-card';
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

type Kpi = { key: string; icon: ReactNode; tone: Tone; label: string; value: string; hint?: string };

/** Chop etish uchun KPI — rangli nursiz, oq fonda ingichka chegara. */
function PrintKpi({ label, value, hint }: Kpi) {
  return (
    <div className="break-inside-avoid rounded-xl border border-border p-4">
      <p className="text-xs font-medium text-muted-foreground">{label}</p>
      <p className="mt-1.5 font-display text-2xl font-semibold leading-none tabular-nums">{value}</p>
      {hint && <p className="mt-1.5 text-xs text-muted-foreground">{hint}</p>}
    </div>
  );
}

/** Oylik hisobot tanasi — ekran (/reports) va chop etish (/reports/print) uchun umumiy. */
export function ReportBody({ report, print = false }: { report: MonthlyReport; print?: boolean }) {
  const { t, formatNumber } = useI18n();
  const a = report.attendance;
  const p = report.parents;
  // Chop etishda ustunlar o'rniga ketma-ket bloklar (A4 kengligi tor).
  const grid = print ? 'space-y-6' : 'grid gap-6 lg:grid-cols-3';
  const wide = print ? '' : 'lg:col-span-2';
  const stack = 'min-w-0 space-y-6';

  const kpis: Kpi[] = [
    ...(a
      ? [
          { key: 'rate', icon: <CalendarCheck />, tone: 'success' as const, label: t('reports.kpi.attendance'), value: `${a.rate}%` },
          { key: 'late', icon: <Clock />, tone: 'warning' as const, label: t('reports.kpi.late'), value: formatNumber(a.late) },
          { key: 'absent', icon: <UserX />, tone: 'destructive' as const, label: t('reports.kpi.absent'), value: formatNumber(a.absent) },
        ]
      : []),
    ...(p
      ? [{ key: 'parents', icon: <Users />, tone: 'info' as const, label: t('reports.kpi.parents'), value: `${p.rate}%`, hint: `${p.linkedStudents} / ${p.totalStudents}` }]
      : []),
  ];

  return (
    <div className="space-y-6">
      <div className={cn('grid gap-4', print ? 'grid-cols-4' : 'sm:grid-cols-2 xl:grid-cols-4')}>
        {kpis.map((k) =>
          print ? <PrintKpi {...k} key={k.key} /> : <StatCard key={k.key} icon={k.icon} tone={k.tone} label={k.label} value={k.value} hint={k.hint} />,
        )}
      </div>

      <div className={grid}>
        <div className={cn(stack, wide)}>{a && <AttendanceTable data={a} print={print} />}</div>
        <div className={stack}>
          {a && <WeekdayChart data={a} print={print} />}
          {report.schoolMode && <SchoolModeSection data={report.schoolMode} print={print} />}
          {report.messages && <MessagesSection data={report.messages} print={print} />}
        </div>
      </div>

      <div className={cn(grid, print && 'print-break')}>
        <div className={stack}>{p && <ParentsTable data={p} print={print} />}</div>
        <div className={cn(stack, wide)}>
          {report.care && <CareSection data={report.care} print={print} />}
          {report.learning && <LearningSection data={report.learning} print={print} />}
        </div>
      </div>
    </div>
  );
}
