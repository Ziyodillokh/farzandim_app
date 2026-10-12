'use client';

import { ChevronRight, UserRoundSearch } from 'lucide-react';
import Link from 'next/link';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import type { AttentionReason } from '@/data/contracts';
import { TILE_INTERACTIVE } from '@/features/dashboard/lib/tile';
import { type TKey, useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useDevAttention } from '../hooks';

const reasonKey = (r: AttentionReason): TKey => `development.attention.reasons.${r}`;

/** E'tibor ro'yxati (faqat psixolog) — skrining signallari, tashxis emas. */
export function AttentionList() {
  const { t, formatDate } = useI18n();
  const list = useDevAttention();
  const rows = list.data ?? [];
  return (
    <SectionCard
      title={t('development.attention.title')}
      description={t('development.attention.hint')}
      icon={<UserRoundSearch />}
      actions={list.data && <Badge variant="outline">{t('development.attention.count', { n: rows.length })}</Badge>}
    >
      {list.error ? (
        <ErrorState error={list.error} onRetry={() => void list.refetch()} />
      ) : list.isLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 6 }, (_, i) => (
            <Skeleton key={i} className="h-14 w-full rounded-xl" />
          ))}
        </div>
      ) : rows.length === 0 ? (
        <EmptyState icon={<UserRoundSearch />} title={t('development.attention.empty')} className="py-10" />
      ) : (
        <ul className="space-y-2">
          {rows.map((r) => (
            <li key={r.studentId}>
              <Link
                href={`/students/view?id=${r.studentId}&tab=development`}
                className={cn(TILE_INTERACTIVE, 'group flex flex-wrap items-center gap-x-4 gap-y-2 px-4 py-3')}
              >
                <span className="min-w-[10rem] flex-1">
                  <span className="block font-medium">{r.name}</span>
                  <span className="text-xs text-muted-foreground">
                    {r.className}
                    {r.lastTakenAt && ` · ${t('development.attention.lastTaken')}: ${formatDate(r.lastTakenAt, 'd MMM yyyy')}`}
                  </span>
                </span>
                <span className="flex flex-wrap gap-1.5">
                  {r.reasons.map((reason) => (
                    <Badge key={reason} variant="info" size="sm">
                      {t(reasonKey(reason))}
                    </Badge>
                  ))}
                </span>
                <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground transition-transform group-hover:translate-x-0.5" />
              </Link>
            </li>
          ))}
        </ul>
      )}
    </SectionCard>
  );
}
