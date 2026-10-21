'use client';

import type { KeyboardEvent } from 'react';
import { AlertTriangle, Telescope } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Switch } from '@/components/ui/switch';
import { DataPagination } from '@/components/common/data-pagination';
import { EmptyState } from '@/components/common/empty-state';
import { answerTypeLabel, categoryLabel } from '@/lib/constants/kelajak';
import { cn } from '@/lib/utils';
import type { KelajakQuestion, Paginated } from '@/types/api.types';
import { kelajakErrorMessage } from './kelajak-errors';
import { useToggleKelajakActive } from './use-toggle-active';

const COLUMN_COUNT = 7;

export function KelajakTable({
  data,
  isLoading,
  isFetching,
  error,
  limit,
  onPageChange,
  onOpen,
}: {
  data: Paginated<KelajakQuestion> | undefined;
  isLoading: boolean;
  isFetching: boolean;
  error: unknown;
  limit: number;
  onPageChange: (page: number) => void;
  onOpen: (question: KelajakQuestion) => void;
}) {
  return (
    <Card className="overflow-hidden">
      {/* Yangilash xatosi: eski qatorlar ko'rinib tursa ham ogohlantiramiz. */}
      {Boolean(error) && data && (
        <p role="alert" className="flex items-center gap-2 border-b border-destructive/30 bg-destructive/10 px-4 py-2 text-xs text-destructive">
          <AlertTriangle className="h-3.5 w-3.5 shrink-0" aria-hidden />
          Ro&apos;yxatni yangilab bo&apos;lmadi — eski ma&apos;lumot ko&apos;rsatilmoqda: {kelajakErrorMessage(error)}
        </p>
      )}
      {/* Tor ekranda jadval karta ichida gorizontal suriladi */}
      <div className="overflow-x-auto">
        <table className="w-full min-w-[960px] text-sm">
          <thead>
            <tr className="border-b border-border bg-muted/30 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              <th className="px-4 py-3 text-left">ID</th>
              <th className="px-4 py-3 text-left">Savol matni</th>
              <th className="px-4 py-3 text-left">Kategoriya</th>
              <th className="px-4 py-3 text-left">Yosh</th>
              <th className="px-4 py-3 text-left">Javob turi</th>
              <th className="px-4 py-3 text-left">Manba</th>
              <th className="px-4 py-3 text-left">Holat</th>
            </tr>
          </thead>
          <tbody className={cn(isFetching && !isLoading && 'opacity-60 transition-opacity')}>
            {isLoading ? (
              Array.from({ length: 8 }).map((_, i) => <RowSkeleton key={i} />)
            ) : error && !data ? (
              <tr>
                <td colSpan={COLUMN_COUNT} className="p-0">
                  <EmptyState
                    icon={<AlertTriangle />}
                    title="Savollarni yuklab bo'lmadi"
                    description={kelajakErrorMessage(error)}
                  />
                </td>
              </tr>
            ) : !data || data.items.length === 0 ? (
              <tr>
                <td colSpan={COLUMN_COUNT} className="p-0">
                  <EmptyState
                    icon={<Telescope />}
                    title="Savol topilmadi"
                    description="Bu filtrlarda savol yo'q. Filtrni o'zgartiring yoki yangi savol qo'shing."
                  />
                </td>
              </tr>
            ) : (
              data.items.map((q) => <QuestionRow key={q.id} question={q} onOpen={() => onOpen(q)} />)
            )}
          </tbody>
        </table>
      </div>

      {data && (
        <DataPagination
          page={data.page}
          totalPages={data.totalPages}
          total={data.total}
          limit={limit}
          onPageChange={onPageChange}
        />
      )}
    </Card>
  );
}

/* ─── Savol qatori ─── */

function QuestionRow({ question: q, onOpen }: { question: KelajakQuestion; onOpen: () => void }) {
  const toggle = useToggleKelajakActive();

  const handleKeyDown = (e: KeyboardEvent<HTMLTableRowElement>) => {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    e.preventDefault();
    onOpen();
  };

  return (
    <tr
      tabIndex={0}
      onClick={onOpen}
      onKeyDown={handleKeyDown}
      aria-label={`${q.externalId} — ko'rish va tahrirlash`}
      className="group/row cursor-pointer border-b border-border last:border-0 transition-colors hover:bg-accent/40 focus-visible:bg-accent/40 focus-visible:outline-none"
    >
      <td className="whitespace-nowrap px-4 py-3 font-mono text-xs text-muted-foreground">{q.externalId}</td>
      <td className="px-4 py-3">
        <p className="line-clamp-2 min-w-[260px] max-w-[440px] font-medium transition-colors group-hover/row:text-primary">
          {q.text.uz}
        </p>
        {q.reviewNote && (
          <Badge variant="warning" size="sm" className="mt-1">
            <AlertTriangle className="h-3 w-3" /> Ko&apos;rib chiqish
          </Badge>
        )}
      </td>
      <td className="px-4 py-3">
        <span className="line-clamp-2 min-w-[150px] max-w-[220px] text-xs">{categoryLabel(q.category)}</span>
      </td>
      <td className="whitespace-nowrap px-4 py-3">
        <Badge variant="info" size="sm">{q.ageGroup}</Badge>
      </td>
      <td className="whitespace-nowrap px-4 py-3 text-xs text-muted-foreground">
        {answerTypeLabel(q.answerType)}
      </td>
      <td className="px-4 py-3 text-xs">
        <p className="whitespace-nowrap font-medium">{q.sourceName}</p>
        <p className="whitespace-nowrap text-muted-foreground">{q.sourceVersion}</p>
      </td>
      {/* Switch bosilganda qator (dialog) ochilmasin */}
      <td className="px-4 py-3" onClick={(e) => e.stopPropagation()} onKeyDown={(e) => e.stopPropagation()}>
        <div className="flex items-center gap-2">
          <Switch
            checked={q.active}
            disabled={toggle.isPending}
            onCheckedChange={(active) => toggle.mutate({ id: q.id, active })}
            aria-label={q.active ? `${q.externalId}ni nofaol qilish` : `${q.externalId}ni faollashtirish`}
          />
          <span className={cn('text-xs font-medium', q.active ? 'text-success' : 'text-muted-foreground')}>
            {q.active ? 'Faol' : 'Nofaol'}
          </span>
        </div>
      </td>
    </tr>
  );
}

/* ─── Qator skeleti ─── */

function RowSkeleton() {
  return (
    <tr className="border-b border-border">
      <td className="px-4 py-3"><Skeleton className="h-3 w-24" /></td>
      <td className="px-4 py-3">
        <div className="space-y-1.5">
          <Skeleton className="h-3 w-72" />
          <Skeleton className="h-3 w-48" />
        </div>
      </td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-32" /></td>
      <td className="px-4 py-3"><Skeleton className="h-5 w-12 rounded-full" /></td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-24" /></td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-20" /></td>
      <td className="px-4 py-3"><Skeleton className="h-6 w-16 rounded-full" /></td>
    </tr>
  );
}
