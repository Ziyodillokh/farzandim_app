'use client';

import { HeartHandshake, Lock } from 'lucide-react';
import Link from 'next/link';

import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import type { DashboardOverview } from '@/data/mock/services/dashboard';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { TILE } from '../lib/tile';

type Aggregate = NonNullable<DashboardOverview['care']>;

export function CareCard({ care }: { care: Aggregate }) {
  const { t } = useI18n();
  return (
    <SectionCard
      title={t('dashboard.care.title')}
      icon={<HeartHandshake />}
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/care">{t('dashboard.care.open')}</Link>
        </Button>
      }
      className="flex flex-col"
      bodyClassName="flex flex-1 flex-col"
    >
      <div className="space-y-4">
        <Metric label={t('dashboard.care.wellbeing')} value={care.wellbeing} hiddenLabel={t('dashboard.care.hidden')} />
        <Metric label={t('dashboard.care.participation')} value={care.participation} hiddenLabel={t('dashboard.care.hidden')} />
        <div className={cn(TILE, 'flex items-center justify-between px-3 py-2.5 text-sm')}>
          <span className="text-muted-foreground">{t('dashboard.care.requestsWeek')}</span>
          <span className="font-display font-semibold tabular-nums">{care.requestsThisWeek}</span>
        </div>
      </div>
      <p className="mt-auto flex items-start gap-2 pt-4 text-xs text-muted-foreground">
        <Lock className="mt-0.5 h-3 w-3 shrink-0" />
        {t('dashboard.care.aggregateNote')}
      </p>
    </SectionCard>
  );
}

function Metric({ label, value, hiddenLabel }: { label: string; value: number | null; hiddenLabel: string }) {
  return (
    <div>
      <div className="mb-1.5 flex items-center justify-between text-sm">
        <span className="text-muted-foreground">{label}</span>
        <span className="font-semibold tabular-nums">{value === null ? hiddenLabel : `${value}%`}</span>
      </div>
      <Progress value={value ?? 0} indicatorClassName="bg-gradient-to-r from-sky-400 to-primary" />
    </div>
  );
}
