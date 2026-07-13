'use client';

import { useEffect, useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { toast } from 'sonner';
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import {
  Select, SelectTrigger, SelectValue, SelectContent, SelectItem,
} from '@/components/ui/select';
import { contentApi } from '@/lib/api/admin.api';
import { getApiErrorMessage } from '@/lib/api/client';
import { AGE_OPTIONS } from '@/lib/constants/permissions';
import type { Article } from '@/types/api.types';

const NO_CATEGORY = '__none__';

/**
 * Maqola qo'shish/tahrirlash — title + markdown body + kategoriya + yosh.
 * Kategoriya VIDEO kategoriyalaridan tanlanadi (nom saqlanadi) — shunda maqola
 * bola ilovasida o'sha kategoriyadagi video tavsiyalari ichida ko'rinadi.
 * POST /admin/articles (yangi) yoki PATCH /admin/articles/:id (tahrir).
 */
export function ArticleModal({
  article,
  open,
  onOpenChange,
  onSuccess,
}: {
  article: Article | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess: () => void;
}) {
  const isEdit = !!article;
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [category, setCategory] = useState(NO_CATEGORY);
  const [ageFrom, setAgeFrom] = useState('0');
  const [ageTo, setAgeTo] = useState('18');

  const { data: categories } = useQuery({
    queryKey: ['categories', 'video'],
    queryFn: () => contentApi.categories.list('video'),
    enabled: open,
  });

  const reset = () => {
    setTitle('');
    setBody('');
    setCategory(NO_CATEGORY);
    setAgeFrom('0');
    setAgeTo('18');
  };

  // Tahrir rejimida joriy qiymatlardan to'ldiramiz.
  useEffect(() => {
    if (open && article) {
      setTitle(article.title ?? '');
      setBody(article.body ?? '');
      setCategory(article.category && article.category.length > 0
        ? article.category
        : NO_CATEGORY);
      setAgeFrom(String(article.ageFrom ?? 0));
      setAgeTo(String(article.ageTo ?? 18));
    } else if (open && !article) {
      reset();
    }
  }, [open, article]);

  const payload = () => ({
    title: title.trim(),
    body: body.trim(),
    category: category === NO_CATEGORY ? null : category,
    ageFrom: Number(ageFrom),
    ageTo: Number(ageTo),
    status: 'approved' as const,
  });

  const save = useMutation({
    mutationFn: () =>
      isEdit
        ? contentApi.articles.update(article!.id, payload())
        : contentApi.articles.create(payload()),
    onSuccess: () => {
      toast.success(isEdit ? 'Maqola yangilandi' : "Maqola qo'shildi");
      reset();
      onSuccess();
      onOpenChange(false);
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  const handleOpenChange = (next: boolean) => {
    if (save.isPending) return;
    if (!next) reset();
    onOpenChange(next);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) {
      toast.error('Sarlavha kiritilishi shart');
      return;
    }
    if (!body.trim()) {
      toast.error('Matn kiritilishi shart');
      return;
    }
    if (Number(ageTo) < Number(ageFrom)) {
      toast.error("Yosh oralig'i noto'g'ri: 'gacha' 'dan' dan kichik bo'lmasin");
      return;
    }
    save.mutate();
  };

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>
            {isEdit ? 'Maqolani tahrirlash' : "Yangi maqola qo'shish"}
          </DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="article-title">Sarlavha *</Label>
            <Input
              id="article-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              maxLength={200}
              placeholder="Maqola sarlavhasi"
              required
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="article-body">Matn (Markdown) *</Label>
            <Textarea
              id="article-body"
              value={body}
              onChange={(e) => setBody(e.target.value)}
              placeholder="Maqola matni... (Markdown qo'llab-quvvatlanadi)"
              className="min-h-[220px]"
            />
          </div>

          <div className="space-y-1.5">
            <Label>Kategoriya</Label>
            <Select value={category} onValueChange={setCategory}>
              <SelectTrigger><SelectValue placeholder="Kategoriya tanlang" /></SelectTrigger>
              <SelectContent>
                <SelectItem value={NO_CATEGORY}>Kategoriyasiz</SelectItem>
                {categories?.map((cat) => (
                  <SelectItem key={cat.id} value={cat.name}>{cat.name}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <p className="text-xs text-muted-foreground">
              Maqola shu kategoriyadagi videolar tavsiyasi ichida ko&apos;rinadi.
            </p>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label>Yoshi (dan)</Label>
              <Select value={ageFrom} onValueChange={setAgeFrom}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {AGE_OPTIONS.map((age) => (
                    <SelectItem key={age} value={String(age)}>{age} yosh</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Yoshi (gacha)</Label>
              <Select value={ageTo} onValueChange={setAgeTo}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {AGE_OPTIONS.map((age) => (
                    <SelectItem key={age} value={String(age)}>{age} yosh</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <DialogFooter className="gap-2 pt-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => handleOpenChange(false)}
              disabled={save.isPending}
            >
              Bekor qilish
            </Button>
            <Button type="submit" loading={save.isPending}>
              {isEdit ? 'Saqlash' : "Qo'shish"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
