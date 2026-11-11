'use client';

import type { KeyboardEvent } from 'react';
import { AlertTriangle, School } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { DataPagination } from '@/components/common/data-pagination';
import { EmptyState } from '@/components/common/empty-state';
import { cn } from '@/lib/utils';
import type { AdminSchool, Paginated } from '@/types/api.types';
import { formatDate } from './school-format';
import { schoolsErrorMessage } from './schools-errors';

const COLUMN_COUNT = 6;

export function SchoolsTable({
  data,
  isLoading,
  isFetching,
  error,
  limit,
  onPageChange,
  onOpen,
}: {
  data: Paginated<AdminSchool> | undefined;
  isLoading: boolean;
  isFetching: boolean;
  error: unknown;
  limit: number;
  onPageChange: (page: number) => void;
  onOpen: (school: AdminSchool) => void;
}) {
  return (
    <Card className="overflow-hidden">
      {Boolean(error) && data && (
        <p
          role="alert"
          className="flex items-center gap-2 border-b border-destructive/30 bg-destructive/10 px-4 py-2 text-xs text-destructive"
        >
          <AlertTriangle className="h-3.5 w-3.5 shrink-0" aria-hidden />
          Ro&apos;yxatni yangilab bo&apos;lmadi: {schoolsErrorMessage(error)}
        </p>
      )}
      <div className="overflow-x-auto">
        <table className="w-full min-w-[860px] text-sm">
          <thead>
            <tr className="border-b border-border bg-muted/30 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              <th className="px-4 py-3 text-left">Maktab</th>
              <th className="px-4 py-3 text-left">Kod</th>
              <th className="px-4 py-3 text-left">Direktor</th>
              <th className="px-4 py-3 text-right">O&apos;quvchilar</th>
              <th className="px-4 py-3 text-right">Xodimlar</th>
              <th className="px-4 py-3 text-left">Ochilgan</th>
            </tr>
          </thead>
          <tbody className={cn(isFetching && !isLoading && 'opacity-60 transition-opacity')}>
            {isLoading ? (
              Array.from({ length: 5 }).map((_, i) => <RowSkeleton key={i} />)
            ) : error && !data ? (
              <tr>
                <td colSpan={COLUMN_COUNT} className="p-0">
                  <EmptyState
                    icon={<AlertTriangle />}
                    title="Maktablarni yuklab bo'lmadi"
                    description={schoolsErrorMessage(error)}
                  />
                </td>
              </tr>
            ) : !data || data.items.length === 0 ? (
              <tr>
                <td colSpan={COLUMN_COUNT} className="p-0">
                  <EmptyState
                    icon={<School />}
                    title="Maktab topilmadi"
                    description="Qidiruvni o'zgartiring yoki «Yangi maktab» tugmasi bilan birinchi maktabni oching."
                  />
                </td>
              </tr>
            ) : (
              data.items.map((s) => <SchoolRow key={s.id} school={s} onOpen={() => onOpen(s)} />)
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

function SchoolRow({ school: s, onOpen }: { school: AdminSchool; onOpen: () => void }) {
  const directors = s.accounts.filter((a) => a.role === 'DIRECTOR');
  const onKeyDown = (e: KeyboardEvent<HTMLTableRowElement>) => {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    e.preventDefault();
    onOpen();
  };
  return (
    <tr
      tabIndex={0}
      onClick={onOpen}
      onKeyDown={onKeyDown}
      aria-label={`${s.name} — batafsil`}
      className="group/row cursor-pointer border-b border-border transition-colors last:border-0 hover:bg-accent/40 focus-visible:bg-accent/40 focus-visible:outline-none"
    >
      <td className="px-4 py-3">
        <p className="font-medium transition-colors group-hover/row:text-primary">{s.name}</p>
        <p className="text-xs text-muted-foreground">{s.city}</p>
      </td>
      <td className="whitespace-nowrap px-4 py-3 font-mono text-xs">{s.code}</td>
      <td className="px-4 py-3">
        {directors.length === 0 ? (
          <Badge variant="warning" size="sm">
            Direktor yo&apos;q
          </Badge>
        ) : (
          directors.map((d) => (
            <div key={d.id} className="flex flex-wrap items-center gap-1.5">
              <span>{d.fullName}</span>
              {d.mustChangePassword && (
                <Badge variant="info" size="sm">
                  Hali kirmagan
                </Badge>
              )}
            </div>
          ))
        )}
      </td>
      <td className="px-4 py-3 text-right tabular-nums">{s.counts.students}</td>
      <td className="px-4 py-3 text-right tabular-nums">{s.counts.staff}</td>
      <td className="whitespace-nowrap px-4 py-3 text-xs text-muted-foreground">
        {formatDate(s.createdAt)}
        {s.status === 'SUSPENDED' && (
          <Badge variant="destructive" size="sm" className="ml-2">
            To&apos;xtatilgan
          </Badge>
        )}
      </td>
    </tr>
  );
}

function RowSkeleton() {
  return (
    <tr className="border-b border-border last:border-0">
      {Array.from({ length: COLUMN_COUNT }).map((_, i) => (
        <td key={i} className="px-4 py-3">
          <Skeleton className="h-4 w-full max-w-[160px]" />
        </td>
      ))}
    </tr>
  );
}
