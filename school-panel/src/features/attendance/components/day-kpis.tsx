'use client';

import { Activity, Clock4, Hourglass, LogOut, UserCheck, UserX } from 'lucide-react';
import type { ReactNode } from 'react';

import { StatCard, type Tone } from '@/components/common/stat-card';
import type { DayCounts } from '@/data/mock/services/attendance';
import { type TKey, useI18n } from '@/i18n';
import { percent } from '@/lib/utils';
import { rateOf } from '../lib';

type Kpi = { key: keyof DayCounts; labelKey: TKey; tone: Tone; icon: ReactNode };

const KPIS: readonly Kpi[] = [
  { key: 'present', labelKey: 'attendance.stats.present', tone: 'success', icon: <UserCheck /> },
  { key: 'late', labelKey: 'attendance.stats.late', tone: 'warning', icon: <Clock4 /> },
  { key: 'absent', labelKey: 'attendance.stats.absent', tone: 'destructive', icon: <UserX /> },
  { key: 'leftEarly', labelKey: 'attendance.stats.leftEarly', tone: 'info', icon: <LogOut /> },
  { key: 'pending', labelKey: 'attendance.stats.pending', tone: 'muted', icon: <Hourglass /> },
];

/** Kun ko'rsatkichlari: umumiy davomat + har holat soni va ulushi. */
export function DayKpis({ counts, loading }: { counts: DayCounts; loading?: boolean }) {
  const { t, formatNumber } = useI18n();
  const decided = counts.total - counts.pending;
  const share = (n: number) => `${t('attendance.share', { value: percent(n, counts.total) })} · ${t('attendance.ofTotal', { count: formatNumber(n), total: formatNumber(counts.total) })}`;

  return (
    <div className="mb-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-6">
      <StatCard
        icon={<Activity />}
        label={t('attendance.stats.rate')}
        value={decided > 0 ? `${rateOf(counts)}%` : '—'}
        hint={t('attendance.stats.rateHint')}
        loading={loading}
        className="bg-gradient-to-br from-primary/[0.07] to-transparent"
      />
      {KPIS.map((kpi) => (
        <StatCard
          key={kpi.key}
          icon={kpi.icon}
          tone={kpi.tone}
          label={t(kpi.labelKey)}
          value={formatNumber(counts[kpi.key])}
          hint={share(counts[kpi.key])}
          loading={loading}
        />
      ))}
    </div>
  );
}
