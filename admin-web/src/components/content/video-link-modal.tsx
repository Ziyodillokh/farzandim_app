'use client';

import { useState } from 'react';
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

const NO_CATEGORY = '__none__';

export function VideoLinkModal({
  open,
  onOpenChange,
  onSuccess,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess: () => void;
}) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [url, setUrl] = useState('');
  const [thumbnail, setThumbnail] = useState('');
  const [ageFrom, setAgeFrom] = useState('0');
  const [ageTo, setAgeTo] = useState('18');
  const [planRequired, setPlanRequired] = useState('free');
  const [categoryId, setCategoryId] = useState(NO_CATEGORY);
  const [pointsReward, setPointsReward] = useState('10');

  const { data: categories } = useQuery({
    queryKey: ['categories', 'video'],
    queryFn: () => contentApi.categories.list('video'),
    enabled: open,
  });

  const reset = () => {
    setTitle('');
    setDescription('');
    setUrl('');
    setThumbnail('');
    setAgeFrom('0');
    setAgeTo('18');
    setPlanRequired('free');
    setCategoryId(NO_CATEGORY);
    setPointsReward('10');
  };

  const ytId = youtubeId(url.trim());
  // Faqat https — bola ilovasi (Android) cleartext http'ni bloklaydi, va
  // bolalar mahsuloti uchun shifrlanmagan havola xavfsiz emas.
  const isHttps = /^https:\/\//i.test(url.trim());

  const create = useMutation({
    mutationFn: () => {
      const trimmedUrl = url.trim();
      // Thumbnail kiritilmasa va YouTube bo'lsa — avtomatik YouTube muqovasi.
      const thumb = thumbnail.trim()
        || (ytId ? `https://img.youtube.com/vi/${ytId}/hqdefault.jpg` : undefined);
      return contentApi.videos.create({
        title: title.trim(),
        url: trimmedUrl,
        thumbnail: thumb ?? null,
        description: description.trim() || null,
        ageFrom: Number(ageFrom),
        ageTo: Number(ageTo),
        planRequired,
        categoryId: categoryId === NO_CATEGORY ? null : categoryId,
        // Qo'shilishi bilan bolaga (yoshiga mos bo'lsa) ko'rinadi.
        status: 'approved',
        xpReward: Number(pointsReward) || 0,
      });
    },
    onSuccess: () => {
      toast.success("Video qo'shildi");
      reset();
      onSuccess();
      onOpenChange(false);
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  const handleOpenChange = (next: boolean) => {
    if (create.isPending) return;
    if (!next) reset();
    onOpenChange(next);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) {
      toast.error('Sarlavha kiritilishi shart');
      return;
    }
    if (!isHttps) {
      toast.error('Havola https:// bilan boshlanishi kerak');
      return;
    }
    if (Number(ageTo) < Number(ageFrom)) {
      toast.error("Yosh oralig'i noto'g'ri: 'gacha' qiymati 'dan' dan kichik bo'lmasligi kerak");
      return;
    }
    create.mutate();
  };

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>Link orqali video qo&apos;shish</DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="video-link-url">Video havolasi *</Label>
            <Input
              id="video-link-url"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="https://youtu.be/... yoki https://.../dars.mp4"
              required
            />
            <p className="text-xs text-muted-foreground">
              {ytId
                ? 'YouTube havolasi aniqlandi — bola ilovasida YouTube player ochiladi.'
                : isHttps
                  ? "To'g'ridan-to'g'ri video havolasi (.mp4/.m3u8)."
                  : 'https:// YouTube (youtu.be / youtube.com) yoki to‘g‘ridan-to‘g‘ri .mp4 havolasi.'}
            </p>
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="video-link-title">Sarlavha *</Label>
            <Input
              id="video-link-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              maxLength={100}
              placeholder="Video sarlavhasi"
              required
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="video-link-desc">Tavsif</Label>
            <Textarea
              id="video-link-desc"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              maxLength={300}
              placeholder="Qisqa tavsif (ixtiyoriy)"
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="video-link-thumb">Muqova rasmi havolasi</Label>
            <Input
              id="video-link-thumb"
              value={thumbnail}
              onChange={(e) => setThumbnail(e.target.value)}
              placeholder={ytId ? 'Bo‘sh qoldirilsa YouTube muqovasi olinadi' : 'https://.../cover.jpg (ixtiyoriy)'}
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

          <div className="space-y-1.5">
            <Label htmlFor="video-link-points">DON mukofoti</Label>
            <Input
              id="video-link-points"
              type="number"
              min={0}
              value={pointsReward}
              onChange={(e) => setPointsReward(e.target.value)}
              placeholder="10"
            />
            <p className="text-xs text-muted-foreground">
              Bola videoni TO&apos;LIQ ko&apos;rgach shu miqdorda DON oladi (0 = mukofot yo&apos;q).
            </p>
          </div>

          <DialogFooter className="gap-2 pt-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => handleOpenChange(false)}
              disabled={create.isPending}
            >
              Bekor qilish
            </Button>
            <Button type="submit" loading={create.isPending}>
              Qo&apos;shish
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
