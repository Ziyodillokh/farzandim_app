'use client';

import { useState } from 'react';
import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query';
import { FolderTree, Plus, Video, Headphones, BookOpen } from 'lucide-react';
import { toast } from 'sonner';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Skeleton } from '@/components/ui/skeleton';
import {
  Dialog, DialogContent, DialogHeader, DialogFooter, DialogTitle, DialogDescription, DialogClose,
} from '@/components/ui/dialog';
import { PageHeader } from '@/components/common/page-header';
import { EmptyState } from '@/components/common/empty-state';
import { contentApi } from '@/lib/api/admin.api';
import { cn } from '@/lib/utils';
import { getApiErrorMessage } from '@/lib/api/client';
import type { ContentCategory } from '@/types/api.types';

type Kind = 'video' | 'audiobook' | 'book';

const KIND_META: Record<Kind, { label: string; icon: typeof Video; variant: 'info' | 'warning' | 'success' }> = {
  video: { label: 'Video', icon: Video, variant: 'info' },
  audiobook: { label: 'Audiokitob', icon: Headphones, variant: 'warning' },
  book: { label: 'Kitob', icon: BookOpen, variant: 'success' },
};

const KIND_FILTERS: Array<{ value: '' | Kind; label: string }> = [
  { value: '', label: 'Hammasi' },
  { value: 'video', label: 'Video' },
  { value: 'audiobook', label: 'Audiokitob' },
  { value: 'book', label: 'Kitob' },
];

const KIND_ORDER: Kind[] = ['video', 'audiobook', 'book'];

export default function CategoriesPage() {
  const qc = useQueryClient();
  const [kind, setKind] = useState<'' | Kind>('');
  const [createOpen, setCreateOpen] = useState(false);

  const { data, isLoading } = useQuery({
    queryKey: ['categories', kind],
    queryFn: () => contentApi.categories.list(kind || undefined),
  });

  const grouped = KIND_ORDER.map((k) => ({
    kind: k,
    items: (data ?? [])
      .filter((c) => c.kind === k)
      .sort((a, b) => a.sortOrder - b.sortOrder),
  })).filter((g) => g.items.length > 0);

  return (
    <div className="container mx-auto max-w-screen-2xl px-6 py-8">
      <PageHeader
        eyebrow="Kontent boshqaruvi"
        title="Kategoriyalar"
        count={data?.length}
        actions={
          <Button onClick={() => setCreateOpen(true)}>
            <Plus className="h-4 w-4" /> Yangi kategoriya
          </Button>
        }
      />

      {/* Kind tabs */}
      <div className="mb-4 flex flex-wrap gap-1.5">
        {KIND_FILTERS.map((tab) => (
          <button
            key={tab.value}
            onClick={() => setKind(tab.value)}
            className={cn(
              'rounded-lg px-3.5 py-1.5 text-sm font-medium transition-colors',
              kind === tab.value
                ? 'bg-primary text-primary-foreground shadow-soft'
                : 'bg-card text-muted-foreground hover:bg-accent hover:text-foreground',
            )}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {isLoading ? (
        <Card className="overflow-hidden">
          <div className="divide-y divide-border">
            {Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="flex items-center gap-3 px-4 py-3">
                <Skeleton className="h-8 w-8 rounded-lg" />
                <div className="flex-1 space-y-1.5">
                  <Skeleton className="h-3.5 w-40" />
                  <Skeleton className="h-2.5 w-24" />
                </div>
                <Skeleton className="h-5 w-16 rounded-full" />
              </div>
            ))}
          </div>
        </Card>
      ) : grouped.length === 0 ? (
        <Card>
          <EmptyState
            icon={<FolderTree />}
            title="Kategoriya topilmadi"
            description="Bu turda hozircha kategoriya yo'q. Yangi kategoriya qo'shing."
            action={
              <Button onClick={() => setCreateOpen(true)}>
                <Plus className="h-4 w-4" /> Yangi kategoriya
              </Button>
            }
          />
        </Card>
      ) : (
        <div className="space-y-6">
          {grouped.map((group) => {
            const meta = KIND_META[group.kind];
            const Icon = meta.icon;
            return (
              <div key={group.kind}>
                <div className="mb-2 flex items-center gap-2">
                  <Icon className="h-4 w-4 text-muted-foreground" />
                  <h3 className="text-sm font-semibold">{meta.label}</h3>
                  <span className="text-xs text-muted-foreground">({group.items.length})</span>
                </div>
                <Card className="overflow-hidden">
                  <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="border-b border-border bg-muted/30 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                          <th className="px-4 py-3 text-left">Tur</th>
                          <th className="px-4 py-3 text-left">Nomi</th>
                          <th className="px-4 py-3 text-left">Slug</th>
                          <th className="px-4 py-3 text-right">Tartib</th>
                        </tr>
                      </thead>
                      <tbody>
                        {group.items.map((cat) => (
                          <CategoryRow key={cat.id} category={cat} />
                        ))}
                      </tbody>
                    </table>
                  </div>
                </Card>
              </div>
            );
          })}
        </div>
      )}

      <CreateCategoryDialog
        open={createOpen}
        onOpenChange={setCreateOpen}
        onCreated={() => qc.invalidateQueries({ queryKey: ['categories'] })}
      />
    </div>
  );
}

function CategoryRow({ category }: { category: ContentCategory }) {
  const meta = KIND_META[category.kind];
  return (
    <tr className="border-b border-border last:border-0 transition-colors hover:bg-accent/40">
      <td className="px-4 py-3">
        <Badge variant={meta.variant} size="sm">{meta.label}</Badge>
      </td>
      <td className="px-4 py-3 font-semibold">{category.name}</td>
      <td className="px-4 py-3 font-mono text-xs text-muted-foreground">{category.slug}</td>
      <td className="px-4 py-3 text-right tabular-nums text-muted-foreground">{category.sortOrder}</td>
    </tr>
  );
}

function CreateCategoryDialog({
  open,
  onOpenChange,
  onCreated,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onCreated: () => void;
}) {
  const [name, setName] = useState('');
  const [slug, setSlug] = useState('');
  const [kind, setKind] = useState<Kind>('video');

  const reset = () => {
    setName('');
    setSlug('');
    setKind('video');
  };

  const create = useMutation({
    mutationFn: () => contentApi.categories.create({ name, slug, kind }),
    onSuccess: () => {
      toast.success("Kategoriya qo'shildi");
      onCreated();
      reset();
      onOpenChange(false);
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !slug.trim()) {
      toast.error("Nomi va slug to'ldirilishi shart");
      return;
    }
    create.mutate();
  };

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (!o) reset();
        onOpenChange(o);
      }}
    >
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Yangi kategoriya</DialogTitle>
          <DialogDescription>Kontent uchun yangi kategoriya yarating.</DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="cat-name">Nomi</Label>
            <Input
              id="cat-name"
              placeholder="Masalan: Ertaklar"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="cat-slug">Slug</Label>
            <Input
              id="cat-slug"
              placeholder="masalan: ertaklar"
              value={slug}
              onChange={(e) => setSlug(e.target.value)}
            />
          </div>

          <div className="space-y-1.5">
            <Label>Turi</Label>
            <div className="flex flex-wrap gap-1.5">
              {KIND_ORDER.map((k) => (
                <button
                  key={k}
                  type="button"
                  onClick={() => setKind(k)}
                  className={cn(
                    'rounded-lg px-3.5 py-1.5 text-sm font-medium transition-colors',
                    kind === k
                      ? 'bg-primary text-primary-foreground shadow-soft'
                      : 'bg-card text-muted-foreground hover:bg-accent hover:text-foreground border border-border',
                  )}
                >
                  {KIND_META[k].label}
                </button>
              ))}
            </div>
          </div>

          <DialogFooter className="gap-2">
            <DialogClose asChild>
              <Button type="button" variant="outline">Bekor qilish</Button>
            </DialogClose>
            <Button type="submit" loading={create.isPending}>Saqlash</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
