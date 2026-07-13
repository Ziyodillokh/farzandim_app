'use client';

import { useState } from 'react';
import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query';
import { FileText, MoreHorizontal, Check, X, Trash2, Pencil, Eye, Plus, Heart } from 'lucide-react';
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
import { ArticleModal } from '@/components/content/article-modal';
import { contentApi } from '@/lib/api/admin.api';
import { cn, formatCompact, formatRelative } from '@/lib/utils';
import { getApiErrorMessage } from '@/lib/api/client';
import type { Article } from '@/types/api.types';

const STATUS_TABS = [
  { value: '', label: 'Hammasi' },
  { value: 'pending', label: 'Kutilayotgan' },
  { value: 'approved', label: 'Tasdiqlangan' },
  { value: 'rejected', label: 'Rad etilgan' },
];

export default function ArticlesPage() {
  const qc = useQueryClient();
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Article | null>(null);
  const limit = 12;

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['articles', { status, page, limit }],
    queryFn: () => contentApi.articles.list({ status, page, limit }),
    placeholderData: (p) => p,
  });

  const invalidate = () => qc.invalidateQueries({ queryKey: ['articles'] });

  const approve = useMutation({
    mutationFn: (id: string) => contentApi.articles.approve(id),
    onSuccess: () => { toast.success('Tasdiqlandi'); invalidate(); },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });
  const reject = useMutation({
    mutationFn: (id: string) => contentApi.articles.reject(id),
    onSuccess: () => { toast.success('Rad etildi'); invalidate(); },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });
  const remove = useMutation({
    mutationFn: (id: string) => contentApi.articles.remove(id),
    onSuccess: () => { toast.success("O'chirildi"); invalidate(); },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  const openCreate = () => { setEditing(null); setModalOpen(true); };
  const openEdit = (a: Article) => { setEditing(a); setModalOpen(true); };

  return (
    <div className="container mx-auto max-w-screen-2xl px-6 py-8">
      <PageHeader
        eyebrow="Kontent boshqaruvi"
        title="Maqolalar"
        count={data?.total}
        actions={
          <Button onClick={openCreate}>
            <Plus className="h-4 w-4" /> Maqola qo&apos;shish
          </Button>
        }
      />

      <ArticleModal
        article={editing}
        open={modalOpen}
        onOpenChange={setModalOpen}
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
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <Card key={i} className="p-4">
              <Skeleton className="h-5 w-3/4" />
              <Skeleton className="mt-3 h-3 w-full" />
              <Skeleton className="mt-1.5 h-3 w-5/6" />
            </Card>
          ))}
        </div>
      ) : !data || data.items.length === 0 ? (
        <Card>
          <EmptyState
            icon={<FileText />}
            title="Maqola topilmadi"
            description="Bu filtrda hozircha maqola yo'q. Yangi maqola qo'shing yoki filtrni o'zgartiring."
          />
        </Card>
      ) : (
        <div className={cn('grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3', isFetching && 'opacity-60 transition-opacity')}>
          {data.items.map((article) => (
            <ArticleCard
              key={article.id}
              article={article}
              onEdit={() => openEdit(article)}
              onApprove={() => approve.mutate(article.id)}
              onReject={() => reject.mutate(article.id)}
              onRemove={() => remove.mutate(article.id)}
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

function ArticleCard({
  article,
  onEdit,
  onApprove,
  onReject,
  onRemove,
}: {
  article: Article;
  onEdit: () => void;
  onApprove: () => void;
  onReject: () => void;
  onRemove: () => void;
}) {
  return (
    <Card className="card-glow group flex flex-col p-4">
      <div className="mb-2 flex items-start justify-between gap-2">
        <div className="min-w-0 flex-1">
          <h3 className="line-clamp-2 text-sm font-semibold leading-snug">{article.title}</h3>
        </div>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon-sm" className="-mr-1 -mt-1 shrink-0">
              <MoreHorizontal className="h-4 w-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuLabel>Amallar</DropdownMenuLabel>
            <DropdownMenuItem onClick={onEdit}><Pencil /> Tahrirlash</DropdownMenuItem>
            {article.status !== 'approved' && (
              <DropdownMenuItem onClick={onApprove} className="text-success focus:text-success">
                <Check /> Tasdiqlash
              </DropdownMenuItem>
            )}
            {article.status !== 'rejected' && (
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

      <p className="mb-3 line-clamp-3 flex-1 text-xs text-muted-foreground">{article.body}</p>

      <div className="mb-3 flex flex-wrap items-center gap-2">
        <ContentStatusBadge status={article.status} />
        {article.category && <Badge variant="outline" size="sm">{article.category}</Badge>}
        <Badge variant="outline" size="sm">{article.ageFrom}–{article.ageTo} yosh</Badge>
      </div>

      <div className="flex items-center justify-between text-xs text-muted-foreground">
        <div className="flex items-center gap-3">
          <span className="flex items-center gap-1"><Eye className="h-3 w-3" /> {formatCompact(article.views)}</span>
          <span className="flex items-center gap-1"><Heart className="h-3 w-3" /> {formatCompact(article.likes ?? 0)}</span>
        </div>
        <span>{formatRelative(article.createdAt)}</span>
      </div>
    </Card>
  );
}
