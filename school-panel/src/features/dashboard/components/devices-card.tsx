'use client';

import { ShieldOff, Smartphone } from 'lucide-react';
import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from 'recharts';

import { SectionCard } from '@/components/common/section-card';
import type { DeviceModeStatus } from '@/data/contracts';
import type { DashboardOverview } from '@/data/mock/services/dashboard';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { TILE } from '../lib/tile';
import { ChartTooltip } from './chart-tooltip';

const COLORS: Record<DeviceModeStatus, string> = {
  APPLIED: 'hsl(var(--success))',
  NO_PERMISSION: 'hsl(var(--warning))',
  OFFLINE: 'hsl(var(--destructive))',
  NO_PHONE: 'hsl(var(--muted-foreground) / 0.45)',
};
const ORDER: DeviceModeStatus[] = ['APPLIED', 'NO_PERMISSION', 'OFFLINE', 'NO_PHONE'];

export function DevicesCard({ schoolMode }: { schoolMode: NonNullable<DashboardOverview['schoolMode']> }) {
  const { t, formatNumber } = useI18n();
  const total = ORDER.reduce((s, k) => s + schoolMode.devices[k], 0);
  const data = ORDER.map((k) => ({ key: k, name: t(`enums.deviceModeStatus.${k}`), value: schoolMode.devices[k] }));

  return (
    <SectionCard
      title={t('dashboard.devices.title')}
      description={t('dashboard.devices.subtitle')}
      icon={<Smartphone />}
      className="flex flex-col"
      bodyClassName="flex flex-1 flex-col"
    >
      <div className="my-auto flex flex-wrap items-center justify-center gap-5">
        <div className="relative h-36 w-36 shrink-0">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie data={data} dataKey="value" nameKey="name" innerRadius={48} outerRadius={66} paddingAngle={2} cornerRadius={4} strokeWidth={0}>
                {data.map((d) => (
                  <Cell key={d.key} fill={COLORS[d.key]} />
                ))}
              </Pie>
              <Tooltip content={<ChartTooltip />} />
            </PieChart>
          </ResponsiveContainer>
          <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
            <span className="font-display text-xl font-semibold tabular-nums">{formatNumber(total)}</span>
          </div>
        </div>
        <ul className="min-w-[10rem] flex-1 space-y-1.5 text-sm">
          {data.map((d) => (
            <li key={d.key} className={cn(TILE, 'flex items-center gap-2 px-3 py-1.5')}>
              <span className="h-2.5 w-2.5 rounded-full" style={{ background: COLORS[d.key] }} />
              <span className="flex-1 text-muted-foreground">{d.name}</span>
              <span className="font-semibold tabular-nums">{d.value}</span>
            </li>
          ))}
        </ul>
      </div>
      <p className="mt-auto flex items-center gap-2 pt-4 text-xs text-muted-foreground">
        <ShieldOff className="h-3.5 w-3.5 shrink-0" />
        {t('dashboard.devices.exceptions', { count: schoolMode.activeExceptions })}
      </p>
    </SectionCard>
  );
}
