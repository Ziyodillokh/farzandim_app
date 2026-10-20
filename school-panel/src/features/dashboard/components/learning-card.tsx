'use client';

import { CalendarClock, EyeOff, GraduationCap } from 'lucide-react';
import Link from 'next/link';

import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import type { DashboardOverview } from '@/data/mock/services/dashboard';
import { useI18n } from '@/i18n';
import { cn, sharePercent } from '@/lib/utils';
import { TILE } from '../lib/tile';

/**
 * Oxirgi yakunlangan hafta (`weekStart`) ko'rsatkichlari. Natijalar (ball, topshiriqlar) — K=5: birorta
 * sinfda ham 5 nafar faol bo'lmasa null ("—") va qisqa izoh.
 */
export function LearningCard({ learning }: { learning: NonNullable<DashboardOverview['learning']> }) {
  const { t, formatNumber, formatDate } = useI18n();
  // O'tgan hafta faollari sinflarning bugungi tarkibidan ko'p bo'lishi mumkin — 100% dan oshmaydi.
  const activeRate = sharePercent(learning.activeStudents, learning.totalStudents);
  const score = learning.avgScore;
  return (
    <SectionCard
      title={t('dashboard.learning.title')}
      description={learning.weekStart ? t('dashboard.learning.week', { date: formatDate(learning.weekStart, 'd MMMM') }) : undefined}
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
        <Row label={t('dashboard.learning.score')} value={score === null ? '—' : `${score}%`} progress={score} />
        <div className={cn(TILE, 'flex items-center justify-between px-3 py-2.5 text-sm')}>
          <span className="text-muted-foreground">{t('dashboard.learning.tasks')}</span>
          <span className="font-display font-semibold tabular-nums">{learning.completedTasks === null ? '—' : formatNumber(learning.completedTasks)}</span>
        </div>
        {learning.suppressed && (
          <p className="flex items-center gap-1.5 text-xs text-muted-foreground">
            <EyeOff className="h-3.5 w-3.5 shrink-0" />
            {t('dashboard.learning.suppressed')}
          </p>
        )}
      </div>
      <p className="mt-auto flex items-center gap-2 pt-4 text-xs text-muted-foreground">
        <CalendarClock className="h-3.5 w-3.5 shrink-0" />
        {t('dashboard.learning.due', { count: learning.dueThisWeek })}
      </p>
    </SectionCard>
  );
}

/** `progress` null (yashirin yoki natija yo'q) — chiziq chizilmaydi: 0% bilan adashtirilmasin. */
function Row({ label, value, progress }: { label: string; value: string; progress: number | null }) {
  return (
    <div>
      <div className="mb-1.5 flex items-center justify-between text-sm">
        <span className="text-muted-foreground">{label}</span>
        <span className="font-semibold tabular-nums">{value}</span>
      </div>
      {progress !== null && <Progress value={progress} indicatorClassName="bg-gradient-to-r from-cyan-400 to-primary" />}
    </div>
  );
}
