'use client';

import { useState } from 'react';
import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query';
import { Headphones, MoreHorizontal, Check, X, Trash2, Eye, Layers, Plus } from 'lucide-react';
import { toast } from 'sonner';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger,
  DropdownMenuSeparator, DropdownMenuLabel,
} from '@/components/ui/dropdown-menu';
import { PageHeader } from '@/components/common/page-header';
import { ContentStatusBadge } from '@/components/common/status-badge';
import { DataPagination } from '@/components/common/data-pagination';
import { EmptyState } from '@/components/common/empty-state';
import { AudiobookUploadModal } from '@/components/content/audiobook-upload-modal';
import { contentApi } from '@/lib/api/admin.api';
import { cn, formatCompact, formatRelative } from '@/lib/utils';
import { getApiErrorMessage } from '@/lib/api/client';
import type { Audiobook } from '@/types/api.types';

const STATUS_TABS = [
  { value: '', label: 'Hammasi' },
  { value: 'pending', label: 'Kutilayotgan' },
  { value: 'approved', label: 'Tasdiqlangan' },
  { value: 'rejected', label: 'Rad etilgan' },
];

export default function AudiobooksPage() {
  const qc = useQueryClient();
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const [uploadOpen, setUploadOpen] = useState(false);
  const limit = 12;

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['audiobooks', { status, page, limit }],
    queryFn: () => contentApi.audiobooks.list({ status, page, limit }),
    placeholderData: (p) => p,
  });

  const invalidate = () => qc.invalidateQueries({ queryKey: ['audiobooks'] });

  const approve = useMutation({
    mutationFn: (id: string) => contentApi.audiobooks.approve(id),
    onSuccess: () => { toast.success('Tasdiqlandi'); invalidate(); },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });
  const reject = useMutation({
    mutationFn: (id: string) => contentApi.audiobooks.reject(id),
    onSuccess: () => { toast.success('Rad etildi'); invalidate(); },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });
  const remove = useMutation({
    mutationFn: (id: string) => contentApi.audiobooks.remove(id),
    onSuccess: () => { toast.success("O'chirildi"); invalidate(); },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  return (
    <div className="container mx-auto max-w-screen-2xl px-6 py-8">
      <PageHeader
        eyebrow="Kontent boshqaruvi"
        title="Audiokitoblar"
        count={data?.total}
        actions={
          <Button onClick={() => setUploadOpen(true)}>
            <Plus className="h-4 w-4" /> Audiokitob qo&apos;shish
          </Button>
        }
      />

      <AudiobookUploadModal
        open={uploadOpen}
        onOpenChange={setUploadOpen}
        onSuccess={invalidate}
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

      {isLoading ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {Array.from({ length: 8 }).map((_, i) => (
            <Card key={i} className="overflow-hidden">
              <Skeleton className="aspect-[4/3] w-full" />
              <div className="space-y-2 p-4">
                <Skeleton className="h-4 w-3/4" />
                <Skeleton className="h-3 w-1/2" />
              </div>
            </Card>
          ))}
        </div>
      ) : !data || data.items.length === 0 ? (
        <Card>
          <EmptyState
            icon={<Headphones />}
            title="Audiokitob topilmadi"
            description="Bu filtrda hozircha audiokitob yo'q. Yangi audiokitob qo'shing yoki filtrni o'zgartiring."
          />
        </Card>
      ) : (
        <div className={cn('grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4', isFetching && 'opacity-60 transition-opacity')}>
          {data.items.map((book) => (
            <AudiobookCard
              key={book.id}
              book={book}
              onApprove={() => approve.mutate(book.id)}
              onReject={() => reject.mutate(book.id)}
              onRemove={() => remove.mutate(book.id)}
            />
          ))}
        </div>
      )}

      {data && data.totalPages > 1 && (
        <div className="mt-4">
          <Card>
            <DataPagination page={data.page} totalPages={data.totalPages} total={data.total} limit={limit} onPageChange={setPage} />
          </Card>
        </div>
      )}
    </div>
  );
}

function AudiobookCard({
  book,
  onApprove,
  onReject,
  onRemove,
}: {
  book: Audiobook;
  onApprove: () => void;
  onReject: () => void;
  onRemove: () => void;
}) {
  return (
    <Card className="card-glow group overflow-hidden">
      <div className="relative aspect-[4/3] w-full overflow-hidden bg-muted">
        {book.thumbnail ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={book.thumbnail} alt={book.title} className="h-full w-full object-cover transition-transform group-hover:scale-105" />
        ) : (
          <div className="flex h-full w-full items-center justify-center">
            <Headphones className="h-10 w-10 text-muted-foreground/40" />
          </div>
        )}
        {book.partsCount > 0 && (
          <span className="absolute bottom-2 right-2 flex items-center gap-1 rounded-md bg-foreground/80 px-1.5 py-0.5 text-2xs font-semibold text-background">
            <Layers className="h-3 w-3" /> {book.partsCount} qism
          </span>
        )}
      </div>

      <div className="p-4">
        <div className="mb-2 flex items-start justify-between gap-2">
          <div className="min-w-0 flex-1">
            <h3 className="line-clamp-2 text-sm font-semibold leading-snug">{book.title}</h3>
            <p className="mt-0.5 truncate text-xs text-muted-foreground">{book.author}</p>
          </div>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon-sm" className="-mr-1 -mt-1 shrink-0">
                <MoreHorizontal className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuLabel>Amallar</DropdownMenuLabel>
              <DropdownMenuItem><Eye /> Ko&apos;rish</DropdownMenuItem>
              {book.status !== 'approved' && (
                <DropdownMenuItem onClick={onApprove} className="text-success focus:text-success">
                  <Check /> Tasdiqlash
                </DropdownMenuItem>
              )}
              {book.status !== 'rejected' && (
                <DropdownMenuItem onClick={onReject}>
                  <X /> Rad etish
                </DropdownMenuItem>
              )}
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={onRemove} className="text-destructive focus:text-destructive">
                <Trash2 /> O&apos;chirish
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>

        <div className="mb-3 flex items-center gap-2">
          <ContentStatusBadge status={book.status} />
          <Badge variant="outline" size="sm">{book.ageFrom}–{book.ageTo} yosh</Badge>
        </div>

        <div className="flex items-center justify-between text-xs text-muted-foreground">
          <span className="flex items-center gap-1"><Headphones className="h-3 w-3" /> {formatCompact(book.listens)}</span>
          <span>{formatRelative(book.createdAt)}</span>
        </div>
      </div>
    </Card>
  );
}
