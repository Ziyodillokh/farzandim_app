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
import { AGE_OPTIONS, PLAN_REQUIRED_OPTIONS } from '@/lib/constants/permissions';
import { youtubeId } from '@/lib/youtube';
import type { Video } from '@/types/api.types';

const NO_CATEGORY = '__none__';

/**
 * Mavjud videoni tahrirlash — asosan KATEGORIYANI o'zgartirish uchun, shu bilan
 * birga sarlavha/tavsif/muqova/yosh/tarifni ham. PATCH /admin/videos/:id.
 * Kategoriya bolaga read-time (categoryId → ContentCategory.name) yetkaziladi.
 */
export function VideoEditModal({
  video,
  open,
  onOpenChange,
  onSuccess,
}: {
  video: Video | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess: () => void;
}) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [thumbnail, setThumbnail] = useState('');
  const [ageFrom, setAgeFrom] = useState('0');
  const [ageTo, setAgeTo] = useState('18');
  const [planRequired, setPlanRequired] = useState('free');
  const [categoryId, setCategoryId] = useState(NO_CATEGORY);

  const { data: categories } = useQuery({
    queryKey: ['categories', 'video'],
    queryFn: () => contentApi.categories.list('video'),
    enabled: open,
  });

  // Modal ochilganda joriy video qiymatlaridan to'ldiramiz.
  useEffect(() => {
    if (open && video) {
      setTitle(video.title ?? '');
      setDescription(video.description ?? '');
      setThumbnail(video.thumbnail ?? '');
      setAgeFrom(String(video.ageFrom ?? 0));
      setAgeTo(String(video.ageTo ?? 18));
      setPlanRequired(video.planRequired ?? 'free');
      setCategoryId(video.categoryId ?? NO_CATEGORY);
    }
  }, [open, video]);

  // Link orqali (YouTube) video bo'lsa muqova bo'sh qoldirilsa avtomatik olinadi.
  const ytId = video ? youtubeId((video.url ?? '').trim()) : null;

  const update = useMutation({
    mutationFn: () => {
      if (!video) throw new Error('no video');
      const thumb = thumbnail.trim()
        || (ytId ? `https://img.youtube.com/vi/${ytId}/hqdefault.jpg` : null);
      return contentApi.videos.update(video.id, {
        title: title.trim(),
        description: description.trim() || null,
        thumbnail: thumb,
        ageFrom: Number(ageFrom),
        ageTo: Number(ageTo),
        planRequired,
        categoryId: categoryId === NO_CATEGORY ? null : categoryId,
      });
    },
    onSuccess: () => {
      toast.success('Video yangilandi');
      onSuccess();
      onOpenChange(false);
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  const handleOpenChange = (next: boolean) => {
    if (update.isPending) return;
    onOpenChange(next);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) {
      toast.error('Sarlavha kiritilishi shart');
      return;
    }
    if (Number(ageTo) < Number(ageFrom)) {
      toast.error("Yosh oralig'i noto'g'ri: 'gacha' 'dan' dan kichik bo'lmasin");
      return;
    }
    update.mutate();
  };

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>Videoni tahrirlash</DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="video-edit-title">Sarlavha *</Label>
            <Input
              id="video-edit-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              maxLength={100}
              required
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="video-edit-desc">Tavsif</Label>
            <Textarea
              id="video-edit-desc"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              maxLength={300}
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="video-edit-thumb">Muqova rasmi havolasi</Label>
            <Input
              id="video-edit-thumb"
              value={thumbnail}
              onChange={(e) => setThumbnail(e.target.value)}
              placeholder={ytId ? 'Bo‘sh qoldirilsa YouTube muqovasi olinadi' : 'https://.../cover.jpg'}
            />
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

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label>Tarif</Label>
              <Select value={planRequired} onValueChange={setPlanRequired}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {PLAN_REQUIRED_OPTIONS.map((opt) => (
                    <SelectItem key={opt.value} value={opt.value}>{opt.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Kategoriya</Label>
              <Select value={categoryId} onValueChange={setCategoryId}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value={NO_CATEGORY}>Kategoriyasiz</SelectItem>
                  {categories?.map((cat) => (
                    <SelectItem key={cat.id} value={cat.id}>{cat.name}</SelectItem>
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
              disabled={update.isPending}
            >
              Bekor qilish
            </Button>
            <Button type="submit" loading={update.isPending}>
              Saqlash
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
