'use client';

import { Activity, Clock4, Hourglass, LogOut, UserCheck, UserX } from 'lucide-react';
import type { ReactNode } from 'react';

import type { Tone } from '@/components/common/stat-card';
import type { DayCounts } from '@/data/mock/services/attendance';
import { type TKey, useI18n } from '@/i18n';
import { percent } from '@/lib/utils';
import { rateOf } from '../lib';
import { KpiStrip, type KpiItem } from './kpi-strip';
import { StackedBar } from './stacked-bar';

type Kpi = { key: keyof DayCounts; labelKey: TKey; tone: Tone; icon: ReactNode };

const KPIS: readonly Kpi[] = [
  { key: 'present', labelKey: 'attendance.stats.present', tone: 'success', icon: <UserCheck /> },
  { key: 'late', labelKey: 'attendance.stats.late', tone: 'warning', icon: <Clock4 /> },
  { key: 'absent', labelKey: 'attendance.stats.absent', tone: 'destructive', icon: <UserX /> },
  { key: 'leftEarly', labelKey: 'attendance.stats.leftEarly', tone: 'info', icon: <LogOut /> },
  { key: 'pending', labelKey: 'attendance.stats.pending', tone: 'muted', icon: <Hourglass /> },
];

/** Kun ko'rsatkichlari: umumiy davomat (holatlar chizig'i bilan) + har holat soni va ulushi. */
export function DayKpis({ counts, loading }: { counts: DayCounts; loading?: boolean }) {
  const { t, formatNumber } = useI18n();
  const decided = counts.total - counts.pending;

  const items: KpiItem[] = [
    {
      key: 'rate',
      label: t('attendance.stats.rate'),
      value: decided > 0 ? `${rateOf(counts)}%` : '—',
      tone: 'primary',
      icon: <Activity />,
      emphasis: true,
      title: t('attendance.stats.rateHint'),
      footer: <StackedBar counts={counts} className="h-1.5" label={t('attendance.stats.rate')} />,
      hint: t('attendance.ofTotal', { count: formatNumber(decided), total: formatNumber(counts.total) }),
    },
    ...KPIS.map((kpi) => ({
      key: kpi.key,
      label: t(kpi.labelKey),
      value: formatNumber(counts[kpi.key]),
      tone: kpi.tone,
      icon: kpi.icon,
      share: percent(counts[kpi.key], counts.total),
      hint: `${t('attendance.share', { value: percent(counts[kpi.key], counts.total) })} · ${t('attendance.ofTotal', { count: formatNumber(counts[kpi.key]), total: formatNumber(counts.total) })}`,
    })),
  ];

  return <KpiStrip items={items} loading={loading} className="xl:grid-cols-6" />;
}
