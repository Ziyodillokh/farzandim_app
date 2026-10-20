'use client';

import { BellRing, ChevronRight, CircleCheck } from 'lucide-react';
import Link from 'next/link';

import { SectionCard } from '@/components/common/section-card';
import { toneClass } from '@/components/common/stat-card';
import { Skeleton } from '@/components/ui/skeleton';
import type { DashboardAlert } from '@/data/mock/services/dashboard';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { ICON_CHIP, TILE_INTERACTIVE } from '../lib/tile';

export function AlertsCard({ alerts, loading }: { alerts: DashboardAlert[] | undefined; loading: boolean }) {
  const { t } = useI18n();
  return (
    <SectionCard title={t('dashboard.alerts.title')} icon={<BellRing />} bodyClassName="p-3">
      {loading ? (
        <div className="space-y-2">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-14 rounded-xl" />
          ))}
        </div>
      ) : !alerts?.length ? (
        <div className="flex flex-col items-center gap-2 px-4 py-10 text-center text-sm text-muted-foreground">
          <span className={cn(ICON_CHIP, 'h-12 w-12 bg-success/10 text-success ring-success/20')}>
            <CircleCheck className="h-6 w-6" />
          </span>
          {t('dashboard.alerts.empty')}
        </div>
      ) : (
        <ul className="space-y-2">
          {alerts.map((a) => (
            <li key={a.kind} data-alert={a.kind}>
              <Link href={a.href} className={cn(TILE_INTERACTIVE, 'group flex items-center gap-3 px-3 py-2.5')}>
                <span className={cn(ICON_CHIP, 'h-9 min-w-9 px-2 font-display text-sm font-semibold tabular-nums', toneClass(a.tone))}>
                  {a.kind === 'EMERGENCY' ? '!' : a.count}
                </span>
                <span className="flex-1 text-sm leading-snug">{t(`dashboard.alerts.${a.kind}`)}</span>
                <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground transition-transform group-hover:translate-x-0.5" />
              </Link>
            </li>
          ))}
        </ul>
      )}
    </SectionCard>
  );
}
