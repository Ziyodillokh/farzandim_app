'use client';

import { useState } from 'react';
import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query';
import { Video as VideoIcon, MoreHorizontal, Check, X, Trash2, Eye, Star, Plus, Link as LinkIcon, Play, Pencil } from 'lucide-react';
import { toast } from 'sonner';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import {
  Select, SelectTrigger, SelectValue, SelectContent, SelectItem,
} from '@/components/ui/select';
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger,
  DropdownMenuSeparator, DropdownMenuLabel,
} from '@/components/ui/dropdown-menu';
import { PageHeader } from '@/components/common/page-header';
import { ContentStatusBadge } from '@/components/common/status-badge';
import { DataPagination } from '@/components/common/data-pagination';
import { EmptyState } from '@/components/common/empty-state';
import { VideoUploadModal } from '@/components/content/video-upload-modal';
import { VideoLinkModal } from '@/components/content/video-link-modal';
import { VideoPreviewModal } from '@/components/content/video-preview-modal';
import { VideoEditModal } from '@/components/content/video-edit-modal';
import { contentApi } from '@/lib/api/admin.api';
import { cn, formatCompact, formatDuration, formatRelative } from '@/lib/utils';
import { getApiErrorMessage } from '@/lib/api/client';
import type { Video } from '@/types/api.types';

const STATUS_TABS = [
  { value: '', label: 'Hammasi' },
  { value: 'pending', label: 'Kutilayotgan' },
  { value: 'approved', label: 'Tasdiqlangan' },
  { value: 'rejected', label: 'Rad etilgan' },
];

const ALL_CATEGORIES = '__all__';

export default function VideosPage() {
  const qc = useQueryClient();
  const [status, setStatus] = useState('');
  const [categoryId, setCategoryId] = useState(ALL_CATEGORIES);
  const [page, setPage] = useState(1);
  const [uploadOpen, setUploadOpen] = useState(false);
  const [linkOpen, setLinkOpen] = useState(false);
  const limit = 12;

  const { data: categories } = useQuery({
    queryKey: ['categories', 'video'],
    queryFn: () => contentApi.categories.list('video'),
  });

  const activeCategoryId = categoryId === ALL_CATEGORIES ? undefined : categoryId;

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['videos', { status, categoryId, page, limit }],
    queryFn: () =>
      contentApi.videos.list({
        status,
        categoryId: activeCategoryId,
        page,
        limit,
      }),
    placeholderData: (p) => p,
  });

  const invalidate = () => qc.invalidateQueries({ queryKey: ['videos'] });

  const approve = useMutation({
    mutationFn: (id: string) => contentApi.videos.approve(id),
    onSuccess: () => { toast.success('Tasdiqlandi'); invalidate(); },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });
  const reject = useMutation({
    mutationFn: (id: string) => contentApi.videos.reject(id),
    onSuccess: () => { toast.success('Rad etildi'); invalidate(); },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });
  const remove = useMutation({
    mutationFn: (id: string) => contentApi.videos.remove(id),
    onSuccess: () => { toast.success("O'chirildi"); invalidate(); },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  return (
    <div className="container mx-auto max-w-screen-2xl px-6 py-8">
      <PageHeader
        eyebrow="Kontent boshqaruvi"
        title="Videolar"
        count={data?.total}
        actions={
          <div className="flex gap-2">
            <Button variant="outline" onClick={() => setLinkOpen(true)}>
              <LinkIcon className="h-4 w-4" /> Link orqali
            </Button>
            <Button onClick={() => setUploadOpen(true)}>
              <Plus className="h-4 w-4" /> Fayl yuklash
            </Button>
          </div>
        }
      />

      <VideoUploadModal
        open={uploadOpen}
        onOpenChange={setUploadOpen}
        onSuccess={invalidate}
      />

      <VideoLinkModal
        open={linkOpen}
        onOpenChange={setLinkOpen}
        onSuccess={invalidate}
      />

      {/* Filtrlar: status tab'lari + kategoriya bo'yicha filter */}
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap gap-1.5">
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
        <div className="w-full sm:w-56">
          <Select
            value={categoryId}
            onValueChange={(v) => { setCategoryId(v); setPage(1); }}
          >
            <SelectTrigger>
              <SelectValue placeholder="Kategoriya" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={ALL_CATEGORIES}>Barcha kategoriyalar</SelectItem>
              {categories?.map((cat) => (
                <SelectItem key={cat.id} value={cat.id}>{cat.name}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {Array.from({ length: 8 }).map((_, i) => (
            <Card key={i} className="overflow-hidden">
              <Skeleton className="aspect-video w-full" />
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
            icon={<VideoIcon />}
            title="Video topilmadi"
            description="Bu filtrda hozircha video yo'q. Yangi video qo'shing yoki filtrni o'zgartiring."
          />
        </Card>
      ) : (
        <div className={cn('grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4', isFetching && 'opacity-60 transition-opacity')}>
          {data.items.map((video) => (
            <VideoCard
              key={video.id}
              video={video}
              onApprove={() => approve.mutate(video.id)}
              onReject={() => reject.mutate(video.id)}
              onRemove={() => remove.mutate(video.id)}
              onEdited={invalidate}
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

function VideoCard({
  video,
  onApprove,
  onReject,
  onRemove,
  onEdited,
}: {
  video: Video;
  onApprove: () => void;
  onReject: () => void;
  onRemove: () => void;
  onEdited: () => void;
}) {
  const [previewOpen, setPreviewOpen] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  return (
    <Card className="card-glow group overflow-hidden">
      <button
        type="button"
        onClick={() => setPreviewOpen(true)}
        className="relative block aspect-video w-full overflow-hidden bg-muted"
        aria-label="Videoni ko'rish"
      >
        {video.thumbnail ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={video.thumbnail} alt={video.title} className="h-full w-full object-cover transition-transform group-hover:scale-105" />
        ) : (
          <div className="flex h-full w-full items-center justify-center">
            <VideoIcon className="h-10 w-10 text-muted-foreground/40" />
          </div>
        )}
        {video.durationSec && (
          <span className="absolute bottom-2 right-2 rounded-md bg-foreground/80 px-1.5 py-0.5 text-2xs font-semibold text-background">
            {formatDuration(video.durationSec * 1000)}
          </span>
        )}
        {video.featured && (
          <span className="absolute left-2 top-2 flex items-center gap-1 rounded-md bg-primary px-1.5 py-0.5 text-2xs font-semibold text-primary-foreground">
            <Star className="h-3 w-3" /> TOP
          </span>
        )}
        {/* Play overlay — bosilsa preview ochiladi */}
        <span className="absolute inset-0 flex items-center justify-center bg-black/0 transition-colors group-hover:bg-black/30">
          <span className="flex h-12 w-12 items-center justify-center rounded-full bg-foreground/80 text-background opacity-0 transition-opacity group-hover:opacity-100">
            <Play className="h-5 w-5 translate-x-0.5" />
          </span>
        </span>
      </button>

      <div className="p-4">
        <div className="mb-2 flex items-start justify-between gap-2">
          <h3 className="line-clamp-2 flex-1 text-sm font-semibold leading-snug">{video.title}</h3>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon-sm" className="-mr-1 -mt-1 shrink-0">
                <MoreHorizontal className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuLabel>Amallar</DropdownMenuLabel>
              <DropdownMenuItem onClick={() => setPreviewOpen(true)}><Eye /> Ko&apos;rish</DropdownMenuItem>
              <DropdownMenuItem onClick={() => setEditOpen(true)}><Pencil /> Tahrirlash</DropdownMenuItem>
              {video.status !== 'approved' && (
                <DropdownMenuItem onClick={onApprove} className="text-success focus:text-success">
                  <Check /> Tasdiqlash
                </DropdownMenuItem>
              )}
              {video.status !== 'rejected' && (
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
          <ContentStatusBadge status={video.status} />
          <Badge variant="outline" size="sm">{video.ageFrom}–{video.ageTo} yosh</Badge>
        </div>

        <div className="flex items-center justify-between text-xs text-muted-foreground">
          <span className="flex items-center gap-3">
            <span className="flex items-center gap-1"><Eye className="h-3 w-3" /> {formatCompact(video.views)}</span>
            <span className="flex items-center gap-1">❤ {formatCompact(video.likes)}</span>
          </span>
          <span>{formatRelative(video.createdAt)}</span>
        </div>
      </div>

      <VideoPreviewModal
        video={video}
        open={previewOpen}
        onOpenChange={setPreviewOpen}
      />

      <VideoEditModal
        video={video}
        open={editOpen}
        onOpenChange={setEditOpen}
        onSuccess={onEdited}
      />
    </Card>
  );
}
