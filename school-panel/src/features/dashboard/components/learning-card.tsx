'use client';

import { CalendarClock, GraduationCap } from 'lucide-react';
import Link from 'next/link';

import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import type { DashboardOverview } from '@/data/mock/services/dashboard';
import { useI18n } from '@/i18n';
import { cn, percent } from '@/lib/utils';
import { TILE } from '../lib/tile';

export function LearningCard({ learning }: { learning: NonNullable<DashboardOverview['learning']> }) {
  const { t, formatNumber } = useI18n();
  const activeRate = percent(learning.activeStudents, learning.totalStudents);
  return (
    <SectionCard
      title={t('dashboard.learning.title')}
      icon={<GraduationCap />}
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/learning">{t('common.open')}</Link>
        </Button>
      }
      className="flex flex-col"
      bodyClassName="flex flex-1 flex-col"
    >
      <div className="space-y-4">
        <Row label={t('dashboard.learning.active')} value={`${activeRate}%`} progress={activeRate} />
        <Row label={t('dashboard.learning.score')} value={`${learning.avgScore}%`} progress={learning.avgScore} />
        <div className={cn(TILE, 'flex items-center justify-between px-3 py-2.5 text-sm')}>
          <span className="text-muted-foreground">{t('dashboard.learning.tasks')}</span>
          <span className="font-display font-semibold tabular-nums">{formatNumber(learning.completedTasks)}</span>
        </div>
      </div>
      <p className="mt-auto flex items-center gap-2 pt-4 text-xs text-muted-foreground">
        <CalendarClock className="h-3.5 w-3.5 shrink-0" />
        {t('dashboard.learning.due', { count: learning.dueThisWeek })}
      </p>
    </SectionCard>
  );
}

function Row({ label, value, progress }: { label: string; value: string; progress: number }) {
  return (
    <div>
      <div className="mb-1.5 flex items-center justify-between text-sm">
        <span className="text-muted-foreground">{label}</span>
        <span className="font-semibold tabular-nums">{value}</span>
      </div>
      <Progress value={progress} indicatorClassName="bg-gradient-to-r from-cyan-400 to-primary" />
    </div>
  );
}
