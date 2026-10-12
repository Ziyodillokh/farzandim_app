'use client';

import { Info } from 'lucide-react';

import { ErrorState } from '@/components/common/error-state';
import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { SUBJECTS } from '@/data/schemas/learning';
import { useI18n } from '@/i18n';
import { useLearningInterests } from '../hooks';

/** Ulushga qarab yumshoq rang intensivligi (heatmap). */
function cellStyle(percent: number) {
  const alpha = Math.min(0.85, 0.05 + percent / 30);
  return { background: `hsl(var(--primary) / ${alpha.toFixed(2)})`, color: alpha > 0.45 ? 'hsl(var(--primary-foreground))' : undefined };
}

/** Qiziqishlar taqsimoti — sinf darajasi bo'yicha TAXMINIY baho (demo, shaxsiy ma'lumotsiz). */
export function InterestsCard() {
  const { t } = useI18n();
  const interests = useLearningInterests();

  return (
    <SectionCard
      title={
        <span className="flex flex-wrap items-center gap-2">
          {t('learning.interests.title')}
          <Badge variant="warning" size="sm">{t('learning.interests.estimate')}</Badge>
        </span>
      }
      description={t('learning.interests.hint')}
      bodyClassName="p-0"
    >
      {interests.error ? (
        <ErrorState error={interests.error} onRetry={() => void interests.refetch()} />
      ) : interests.isLoading ? (
        <div className="p-5">
          <Skeleton className="h-48 w-full rounded-lg" />
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full min-w-[640px] border-separate border-spacing-1 p-3 text-sm">
            <thead>
              <tr>
                <th className="px-2 py-1.5 text-left text-xs font-medium text-muted-foreground" />
                {SUBJECTS.map((s) => (
                  <th key={s} className="px-1 py-1.5 text-center text-xs font-medium text-muted-foreground">
                    {t(`enums.subject.${s}`)}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {(interests.data ?? []).map((row) => {
                const bySubject = new Map(row.shares.map((x) => [x.subject, x.percent]));
                return (
                  <tr key={row.grade}>
                    <th scope="row" className="whitespace-nowrap px-2 py-1 text-left text-xs font-semibold">
                      {t('learning.interests.grade', { grade: row.grade })}
                    </th>
                    {SUBJECTS.map((s) => {
                      const pct = bySubject.get(s) ?? 0;
                      return (
                        <td key={s} className="rounded-md px-1 py-1.5 text-center text-xs font-semibold tabular-nums transition-colors" style={cellStyle(pct)}>
                          {pct}%
                        </td>
                      );
                    })}
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
      <p className="flex items-start gap-2 border-t px-5 py-3 text-xs text-muted-foreground">
        <Info className="mt-0.5 h-3.5 w-3.5 shrink-0" />
        {t('learning.privacyNote')}
      </p>
    </SectionCard>
  );
}
