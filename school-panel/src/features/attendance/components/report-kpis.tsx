'use client';

import { Activity, CalendarDays, Clock4, ShieldCheck, UserX } from 'lucide-react';
import type { ReactNode } from 'react';

import { StatCard, type Tone } from '@/components/common/stat-card';
import type { DayCounts } from '@/data/mock/services/attendance';
import { type TKey, useI18n } from '@/i18n';
import { rateOf } from '../lib';

type Item = { labelKey: TKey; value: string; tone: Tone; icon: ReactNode };

/** Oylik hisobot ko'rsatkichlari (sinf bo'yicha). */
export function ReportKpis({ totals, days, loading }: { totals: DayCounts; days: number; loading?: boolean }) {
  const { t, formatNumber } = useI18n();
  const decided = totals.total - totals.pending;
  const items: Item[] = [
    { labelKey: 'attendance.reports.kpi.rate', value: decided ? `${rateOf(totals)}%` : '—', tone: 'primary', icon: <Activity /> },
    { labelKey: 'attendance.reports.kpi.days', value: formatNumber(days), tone: 'info', icon: <CalendarDays /> },
    { labelKey: 'attendance.reports.kpi.late', value: formatNumber(totals.late), tone: 'warning', icon: <Clock4 /> },
    { labelKey: 'attendance.reports.kpi.absent', value: formatNumber(totals.absent), tone: 'destructive', icon: <UserX /> },
    { labelKey: 'attendance.reports.kpi.excused', value: formatNumber(totals.excused), tone: 'muted', icon: <ShieldCheck /> },
  ];
  return (
    <div className="mb-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
      {items.map((item) => (
        <StatCard key={item.labelKey} icon={item.icon} tone={item.tone} label={t(item.labelKey)} value={item.value} loading={loading} />
      ))}
    </div>
  );
}
