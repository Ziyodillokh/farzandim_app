'use client';

import { HeartHandshake, Lock } from 'lucide-react';
import Link from 'next/link';

import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import type { DashboardOverview } from '@/data/mock/services/dashboard';
import { useI18n } from '@/i18n';

type Aggregate = NonNullable<DashboardOverview['care']>;

export function CareCard({ care }: { care: Aggregate }) {
  const { t } = useI18n();
  return (
    <SectionCard
      title={
        <span className="flex items-center gap-2">
          <HeartHandshake className="h-4 w-4 text-pink-500" />
          {t('dashboard.care.title')}
        </span>
      }
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/care">{t('dashboard.care.open')}</Link>
        </Button>
      }
    >
      <div className="space-y-4">
        <Metric label={t('dashboard.care.wellbeing')} value={care.wellbeing} hiddenLabel={t('dashboard.care.hidden')} />
        <Metric label={t('dashboard.care.participation')} value={care.participation} hiddenLabel={t('dashboard.care.hidden')} />
        <div className="flex items-center justify-between rounded-lg bg-muted/50 px-3 py-2 text-sm">
          <span className="text-muted-foreground">{t('dashboard.care.requestsWeek')}</span>
          <span className="font-display font-semibold tabular-nums">{care.requestsThisWeek}</span>
        </div>
      </div>
      <p className="mt-4 flex items-start gap-2 text-xs text-muted-foreground">
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
      <Progress value={value ?? 0} indicatorClassName="bg-gradient-to-r from-pink-500 to-primary" />
    </div>
  );
}
