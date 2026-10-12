'use client';

import { Hourglass, PhoneOff, ShieldAlert, ShieldCheck } from 'lucide-react';

import { StatCard } from '@/components/common/stat-card';
import { Progress } from '@/components/ui/progress';
import type { SchoolModeOverview } from '@/data/mock/services/school-mode';
import { useI18n } from '@/i18n';
import { percent } from '@/lib/utils';

/** 4 ta asosiy ko'rsatkich: qo'llangan %, ruxsat yo'q, telefonsiz, faol istisnolar. */
export function LiveKpis({ overview, loading }: { overview: SchoolModeOverview | undefined; loading: boolean }) {
  const { t, formatNumber } = useI18n();
  const totals = overview?.totals;
  const devices = totals?.devices;
  const phones = devices ? devices.total - devices.NO_PHONE : 0;
  const ios = totals ? percent(totals.os.IOS, totals.devices.total) : 0;
  const android = totals ? percent(totals.os.ANDROID, totals.devices.total) : 0;

  return (
    <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
      <StatCard
        icon={<ShieldCheck />}
        label={t('schoolMode.kpi.applied')}
        value={`${totals?.appliedRate ?? 0}%`}
        hint={t('schoolMode.kpi.appliedHint', { applied: formatNumber(devices?.APPLIED ?? 0), phones: formatNumber(phones) })}
        loading={loading}
        footer={
          !loading && (
            <div className="space-y-1.5">
              <Progress value={totals?.appliedRate ?? 0} indicatorClassName="bg-success" aria-label={t('schoolMode.kpi.applied')} />
              <p className="text-2xs text-muted-foreground">{t('schoolMode.kpi.osShare', { ios, android })}</p>
            </div>
          )
        }
      />
      <StatCard
        icon={<ShieldAlert />}
        tone="warning"
        label={t('schoolMode.kpi.noPermission')}
        value={formatNumber(devices?.NO_PERMISSION ?? 0)}
        hint={t('schoolMode.kpi.noPermissionHint')}
        loading={loading}
      />
      <StatCard
        icon={<PhoneOff />}
        tone="muted"
        label={t('schoolMode.kpi.noPhone')}
        value={formatNumber(devices?.NO_PHONE ?? 0)}
        hint={t('schoolMode.kpi.noPhoneHint', { total: formatNumber(devices?.total ?? 0) })}
        loading={loading}
      />
      <StatCard
        icon={<Hourglass />}
        tone="info"
        label={t('schoolMode.kpi.exceptions')}
        value={formatNumber(totals?.activeExceptions ?? 0)}
        hint={t('schoolMode.kpi.exceptionsHint')}
        loading={loading}
      />
    </div>
  );
}
