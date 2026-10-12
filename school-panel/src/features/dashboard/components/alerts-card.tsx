'use client';

import { ChevronRight, CircleCheck } from 'lucide-react';
import Link from 'next/link';

import { SectionCard } from '@/components/common/section-card';
import { toneClass } from '@/components/common/stat-card';
import { Skeleton } from '@/components/ui/skeleton';
import type { DashboardAlert } from '@/data/mock/services/dashboard';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

export function AlertsCard({ alerts, loading }: { alerts: DashboardAlert[] | undefined; loading: boolean }) {
  const { t } = useI18n();
  return (
    <SectionCard title={t('dashboard.alerts.title')} bodyClassName="p-2">
      {loading ? (
        <div className="space-y-2 p-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-12 rounded-lg" />
          ))}
        </div>
      ) : !alerts?.length ? (
        <div className="flex flex-col items-center gap-2 px-4 py-10 text-center text-sm text-muted-foreground">
          <CircleCheck className="h-8 w-8 text-success" />
          {t('dashboard.alerts.empty')}
        </div>
      ) : (
        <ul>
          {alerts.map((a) => (
            <li key={a.kind}>
              <Link href={a.href} className="group flex items-center gap-3 rounded-lg px-3 py-2.5 transition-colors hover:bg-muted/60">
                <span className={cn('flex h-9 min-w-9 items-center justify-center rounded-lg px-2 font-display text-sm font-semibold tabular-nums', toneClass(a.tone))}>
                  {a.kind === 'EMERGENCY' ? '!' : a.count}
                </span>
                <span className="flex-1 text-sm leading-snug">{t(`dashboard.alerts.${a.kind}`)}</span>
                <ChevronRight className="h-4 w-4 text-muted-foreground transition-transform group-hover:translate-x-0.5" />
              </Link>
            </li>
          ))}
        </ul>
      )}
    </SectionCard>
  );
}
