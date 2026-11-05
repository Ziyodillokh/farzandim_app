'use client';

import { AlertTriangle } from 'lucide-react';
import { TabsList, TabsTrigger } from '@/components/ui/tabs';
import { LEARNING_SUBJECTS, MIN_TOPIC_QUESTIONS } from '@/lib/constants/learning';
import { cn } from '@/lib/utils';
import type { LearningSubject } from '@/types/api.types';
import type { SubjectSummary } from './topic-order';
import { WARNING_ICON } from './warning-styles';

/**
 * Fan tablari (Radix Tabs: ← → bilan almashtiriladi). Har tabda mavzular
 * soni; faol mavzulardan savoli yetmaydiganlari bo'lsa ogohlantirish belgisi.
 */
export function SubjectTabs({
  summaries,
}: {
  summaries: Partial<Record<LearningSubject, SubjectSummary>>;
}) {
  return (
    // Tor ekranda tablar gorizontal suriladi
    <div className="mb-4 overflow-x-auto pb-1">
      <TabsList aria-label="Fanlar" className="min-w-max">
        {LEARNING_SUBJECTS.map(({ value, label }) => {
          const summary = summaries[value];
          return (
            <TabsTrigger key={value} value={value}>
              {label}
              {summary && summary.total > 0 && (
                <span className="rounded-full bg-foreground/10 px-1.5 text-2xs tabular-nums">
                  {summary.total}
                </span>
              )}
              {summary && summary.underfilled > 0 && (
                <>
                  <AlertTriangle className={cn('h-3.5 w-3.5', WARNING_ICON)} aria-hidden />
                  <span className="sr-only">
                    {`, ${summary.underfilled} ta mavzuda ${MIN_TOPIC_QUESTIONS} tadan kam faol savol`}
                  </span>
                </>
              )}
            </TabsTrigger>
          );
        })}
      </TabsList>
    </div>
  );
}
