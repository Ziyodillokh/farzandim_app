'use client';

import { Activity, CalendarDays, Clock4, ShieldCheck, UserX } from 'lucide-react';

import type { DayCounts } from '@/data/mock/services/attendance';
import { useI18n } from '@/i18n';
import { percent } from '@/lib/utils';
import { rateOf } from '../lib';
import { KpiStrip, type KpiItem } from './kpi-strip';
import { StackedBar } from './stacked-bar';

/** Oylik hisobot ko'rsatkichlari (sinf bo'yicha) — ixcham KPI qatori. */
export function ReportKpis({ totals, days, loading }: { totals: DayCounts; days: number; loading?: boolean }) {
  const { t, formatNumber } = useI18n();
  const decided = totals.total - totals.pending;
  const share = (n: number) => percent(n, decided);

  const items: KpiItem[] = [
    {
      key: 'rate',
      label: t('attendance.reports.kpi.rate'),
      value: decided ? `${rateOf(totals)}%` : '—',
      tone: 'primary',
      icon: <Activity />,
      emphasis: true,
      footer: <StackedBar counts={totals} className="h-1.5" label={t('attendance.reports.kpi.rate')} />,
    },
    { key: 'days', label: t('attendance.reports.kpi.days'), value: formatNumber(days), tone: 'info', icon: <CalendarDays /> },
    { key: 'late', label: t('attendance.reports.kpi.late'), value: formatNumber(totals.late), tone: 'warning', icon: <Clock4 />, share: share(totals.late), hint: `${share(totals.late)}%` },
    {
      key: 'absent',
      label: t('attendance.reports.kpi.absent'),
      value: formatNumber(totals.absent),
      tone: 'destructive',
      icon: <UserX />,
      share: share(totals.absent),
      hint: `${share(totals.absent)}%`,
    },
    {
      key: 'excused',
      label: t('attendance.reports.kpi.excused'),
      value: formatNumber(totals.excused),
      tone: 'muted',
      icon: <ShieldCheck />,
      share: share(totals.excused),
      hint: `${share(totals.excused)}%`,
    },
  ];

  return <KpiStrip items={items} loading={loading} className="lg:grid-cols-5" />;
}
