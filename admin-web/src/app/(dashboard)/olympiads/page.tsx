'use client';

import { useState } from 'react';
import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query';
import { Trophy, MoreHorizontal, Eye, Send, BarChart3, Plus } from 'lucide-react';
import { toast } from 'sonner';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  DropdownMenuSeparator,
  DropdownMenuLabel,
} from '@/components/ui/dropdown-menu';
import { PageHeader } from '@/components/common/page-header';
import { DataPagination } from '@/components/common/data-pagination';
import { EmptyState } from '@/components/common/empty-state';
import { olympiadsApi } from '@/lib/api/admin.api';
import { cn, formatRelative } from '@/lib/utils';
import { getApiErrorMessage } from '@/lib/api/client';
import type { Olympiad } from '@/types/api.types';

const STATUS_TABS = [
  { value: '', label: 'Hammasi' },
  { value: 'draft', label: 'Qoralama' },
  { value: 'published', label: 'Chop etilgan' },
  { value: 'archived', label: 'Arxiv' },
];

const STATUS_CFG: Record<string, { label: string; variant: 'success' | 'warning' | 'secondary' }> = {
  draft: { label: 'Qoralama', variant: 'warning' },
  published: { label: 'Chop etilgan', variant: 'success' },
  archived: { label: 'Arxiv', variant: 'secondary' },
};

const TYPE_LABELS: Record<string, string> = {
  test: 'Test',
  creative: 'Ijodiy',
  mixed: 'Aralash',
};

export default function OlympiadsPage() {
  const qc = useQueryClient();
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const limit = 20;

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['olympiads', { status, page, limit }],
    queryFn: () => olympiadsApi.list({ status, page, limit }),
    placeholderData: (prev) => prev,
  });

  const publish = useMutation({
    mutationFn: (id: string) => olympiadsApi.publish(id),
    onSuccess: () => {
      toast.success('Chop etildi');
      qc.invalidateQueries({ queryKey: ['olympiads'] });
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  return (
    <div className="container mx-auto max-w-screen-2xl px-6 py-8">
      <PageHeader
        eyebrow="Konkurslar boshqaruvi"
        title="Konkurslar"
        count={data?.total}
        actions={
          <Button>
            <Plus className="h-4 w-4" /> Yangi konkurs
          </Button>
        }
      />

      {/* Status tabs */}
      <div className="mb-4 flex flex-wrap gap-1.5">
        {STATUS_TABS.map((tab) => (
          <button
            key={tab.value}
            onClick={() => { setStatus(tab.value); setPage(1); }}
            className={cn(
              'rounded-lg px-3.5 py-1.5 text-sm font-medium transition-colors',
              status === tab.value
                ? 'bg-primary text-primary-foreground shadow-soft'
                : 'bg-card text-muted-foreground hover:bg-accent hover:text-foreground',
            )}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Table */}
      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border bg-muted/30 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                <th className="px-4 py-3 text-left">Konkurs</th>
                <th className="px-4 py-3 text-left">Fan</th>
                <th className="px-4 py-3 text-left">Yosh</th>
                <th className="px-4 py-3 text-left">Turi</th>
                <th className="px-4 py-3 text-left">Daraja</th>
                <th className="px-4 py-3 text-left">Davomiyligi</th>
                <th className="px-4 py-3 text-left">Boshlanishi</th>
                <th className="px-4 py-3 text-left">Status</th>
                <th className="px-4 py-3 w-10" />
              </tr>
            </thead>
            <tbody className={cn(isFetching && !isLoading && 'opacity-60 transition-opacity')}>
              {isLoading ? (
                Array.from({ length: 8 }).map((_, i) => <RowSkeleton key={i} />)
              ) : !data || data.items.length === 0 ? (
                <tr>
                  <td colSpan={9} className="p-0">
                    <EmptyState
                      icon={<Trophy />}
                      title="Konkurs topilmadi"
                      description="Bu filtrda hozircha konkurs yo'q. Yangi konkurs qo'shing yoki filtrni o'zgartiring."
                    />
                  </td>
                </tr>
              ) : (
                data.items.map((o) => (
                  <OlympiadRow key={o.id} olympiad={o} onPublish={() => publish.mutate(o.id)} />
                ))
              )}
            </tbody>
          </table>
        </div>

        {data && data.totalPages > 1 && (
          <DataPagination
            page={data.page}
            totalPages={data.totalPages}
            total={data.total}
            limit={limit}
            onPageChange={setPage}
          />
        )}
      </Card>
    </div>
  );
}

/* ─── Olympiad row ─── */

function OlympiadRow({ olympiad, onPublish }: { olympiad: Olympiad; onPublish: () => void }) {
  const statusCfg = STATUS_CFG[olympiad.status] ?? { label: olympiad.status, variant: 'secondary' as const };

  return (
    <tr className="border-b border-border last:border-0 transition-colors hover:bg-accent/40">
      <td className="px-4 py-3">
        <p className="font-semibold">{olympiad.title}</p>
        {olympiad.description && (
          <p className="mt-0.5 line-clamp-1 max-w-[280px] text-xs text-muted-foreground">{olympiad.description}</p>
        )}
      </td>
      <td className="px-4 py-3">
        <Badge variant="info" size="sm">{olympiad.subject}</Badge>
      </td>
      <td className="px-4 py-3 text-muted-foreground">{olympiad.ageFrom}–{olympiad.ageTo} yosh</td>
      <td className="px-4 py-3">
        <Badge variant="secondary" size="sm">{TYPE_LABELS[olympiad.type] ?? olympiad.type}</Badge>
      </td>
      <td className="px-4 py-3 text-muted-foreground">{olympiad.difficulty}</td>
      <td className="px-4 py-3 text-muted-foreground">{olympiad.durationMin} daq</td>
      <td className="px-4 py-3 text-xs text-muted-foreground">{formatDate(olympiad.startTime)}</td>
      <td className="px-4 py-3">
        <Badge variant={statusCfg.variant} size="sm">
          <span
            className={cn(
              'h-1.5 w-1.5 rounded-full',
              statusCfg.variant === 'success' && 'bg-success',
              statusCfg.variant === 'warning' && 'bg-warning',
              statusCfg.variant === 'secondary' && 'bg-muted-foreground',
            )}
          />
          {statusCfg.label}
        </Badge>
      </td>
      <td className="px-4 py-3">
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon-sm" aria-label="Amallar">
              <MoreHorizontal className="h-4 w-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuLabel>Amallar</DropdownMenuLabel>
            <DropdownMenuItem>
              <Eye /> Ko&apos;rish
            </DropdownMenuItem>
            <DropdownMenuItem>
              <BarChart3 /> Reyting
            </DropdownMenuItem>
            {olympiad.status !== 'published' && (
              <>
                <DropdownMenuSeparator />
                <DropdownMenuItem onClick={onPublish} className="text-success focus:text-success">
                  <Send /> Chop etish
                </DropdownMenuItem>
              </>
            )}
          </DropdownMenuContent>
        </DropdownMenu>
      </td>
    </tr>
  );
}

function formatDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '—';
  return new Intl.DateTimeFormat('uz-UZ', { day: '2-digit', month: 'short', year: 'numeric' }).format(d);
}

/* ─── Row skeleton ─── */

function RowSkeleton() {
  return (
    <tr className="border-b border-border">
      <td className="px-4 py-3">
        <div className="space-y-1.5">
          <Skeleton className="h-3 w-40" />
          <Skeleton className="h-2.5 w-28" />
        </div>
      </td>
      <td className="px-4 py-3"><Skeleton className="h-5 w-16 rounded-full" /></td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-16" /></td>
      <td className="px-4 py-3"><Skeleton className="h-5 w-14 rounded-full" /></td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-12" /></td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-12" /></td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-20" /></td>
      <td className="px-4 py-3"><Skeleton className="h-5 w-20 rounded-full" /></td>
      <td className="px-4 py-3"><Skeleton className="h-7 w-7 rounded-md" /></td>
    </tr>
  );
}
