'use client';

import { useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { Video as VideoIcon, Upload, Link as LinkIcon } from 'lucide-react';
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
import { FileDropzone } from '@/components/common/file-dropzone';
import { contentApi } from '@/lib/api/admin.api';
import { getApiErrorMessage } from '@/lib/api/client';
import { AGE_OPTIONS, PLAN_REQUIRED_OPTIONS } from '@/lib/constants/permissions';
import { cn } from '@/lib/utils';

const VIDEO_ACCEPT = {
  'video/mp4': ['.mp4'],
  'video/webm': ['.webm'],
  'video/quicktime': ['.mov'],
} as const;

const IMAGE_ACCEPT = {
  'image/jpeg': ['.jpg', '.jpeg'],
  'image/png': ['.png'],
  'image/webp': ['.webp'],
} as const;

const NO_CATEGORY = '__none__';

type Mode = 'file' | 'link';

/** Oddiy URL validatsiyasi — http(s) bo'lishi shart. */
function isValidUrl(value: string): boolean {
  try {
    const u = new URL(value.trim());
    return u.protocol === 'http:' || u.protocol === 'https:';
  } catch {
    return false;
  }
}

export function VideoUploadModal({
  open,
  onOpenChange,
  onSuccess,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess: () => void;
}) {
  const [mode, setMode] = useState<Mode>('file');
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [videoFile, setVideoFile] = useState<File | null>(null);
  const [thumbnailFile, setThumbnailFile] = useState<File | null>(null);
  // Link rejimi maydonlari
  const [videoUrl, setVideoUrl] = useState('');
  const [thumbnailUrl, setThumbnailUrl] = useState('');
  const [ageFrom, setAgeFrom] = useState('0');
  const [ageTo, setAgeTo] = useState('18');
  const [planRequired, setPlanRequired] = useState('free');
  const [categoryId, setCategoryId] = useState(NO_CATEGORY);
  const [pointsReward, setPointsReward] = useState('10');
  const [progress, setProgress] = useState(0);

  const { data: categories } = useQuery({
    queryKey: ['categories', 'video'],
    queryFn: () => contentApi.categories.list('video'),
    enabled: open,
  });

  const reset = () => {
    setMode('file');
    setTitle('');
    setDescription('');
    setVideoFile(null);
    setThumbnailFile(null);
    setVideoUrl('');
    setThumbnailUrl('');
    setAgeFrom('0');
    setAgeTo('18');
    setPlanRequired('free');
    setCategoryId(NO_CATEGORY);
    setPointsReward('10');
    setProgress(0);
  };

  const baseMeta = () => ({
    title: title.trim(),
    description: description.trim(),
    ageFrom: Number(ageFrom),
    ageTo: Number(ageTo),
    planRequired,
    categoryId: categoryId === NO_CATEGORY ? undefined : categoryId,
    status: 'approved' as const, // yuklash = darhol bolaga ko'rinadi
    featured: false,
    xpReward: Number(pointsReward) || 0,
  });

  const save = useMutation({
    mutationFn: () => {
      if (mode === 'link') {
        // URL orqali — fayl yuklamasdan to'g'ridan-to'g'ri yaratamiz.
        return contentApi.videos.create({
          ...baseMeta(),
          url: videoUrl.trim(),
          ...(thumbnailUrl.trim() ? { thumbnail: thumbnailUrl.trim() } : {}),
        });
      }
      if (!videoFile) throw new Error('Video fayli tanlanmagan');
      return contentApi.videos.upload(videoFile, baseMeta(), thumbnailFile, setProgress);
    },
    onSuccess: () => {
      toast.success(mode === 'link' ? "Video havola orqali qo'shildi" : 'Video yuklandi');
      reset();
      onSuccess();
      onOpenChange(false);
    },
    onError: (e) => {
      setProgress(0);
      toast.error(getApiErrorMessage(e));
    },
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
    if (mode === 'link') {
      if (!videoUrl.trim()) {
        toast.error('Video havolasi kiritilishi shart');
        return;
      }
      if (!isValidUrl(videoUrl)) {
        toast.error("Video havolasi noto'g'ri (http:// yoki https:// bilan boshlanishi kerak)");
        return;
      }
      if (thumbnailUrl.trim() && !isValidUrl(thumbnailUrl)) {
        toast.error("Muqova havolasi noto'g'ri");
        return;
      }
    } else if (!videoFile) {
      toast.error('Video fayli tanlanishi shart');
      return;
    }
    if (Number(ageTo) < Number(ageFrom)) {
      toast.error("Yosh oralig'i noto'g'ri: 'gacha' qiymati 'dan' qiymatidan kichik bo'lmasligi kerak");
      return;
    }
    save.mutate();
  };

  const showProgress = mode === 'file' && save.isPending && progress > 0;

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>Yangi video qo&apos;shish</DialogTitle>
        </DialogHeader>

        {/* ── Rejim tanlovi: Fayl / Link ── */}
        <div className="grid grid-cols-2 gap-2 rounded-lg bg-muted p-1">
          <button
            type="button"
            onClick={() => setMode('file')}
            disabled={save.isPending}
            className={cn(
              'flex items-center justify-center gap-2 rounded-md py-2 text-sm font-medium transition-colors',
              mode === 'file'
                ? 'bg-background text-foreground shadow-sm'
                : 'text-muted-foreground hover:text-foreground',
            )}
          >
            <Upload className="h-4 w-4" />
            Fayl yuklash
          </button>
          <button
            type="button"
            onClick={() => setMode('link')}
            disabled={save.isPending}
            className={cn(
              'flex items-center justify-center gap-2 rounded-md py-2 text-sm font-medium transition-colors',
              mode === 'link'
                ? 'bg-background text-foreground shadow-sm'
                : 'text-muted-foreground hover:text-foreground',
            )}
          >
            <LinkIcon className="h-4 w-4" />
            Havola (URL)
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="video-title">Sarlavha *</Label>
            <Input
              id="video-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              maxLength={100}
              placeholder="Video sarlavhasi"
              required
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="video-description">Tavsif</Label>
            <Textarea
              id="video-description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              maxLength={300}
              placeholder="Qisqa tavsif (ixtiyoriy)"
            />
          </div>

          {mode === 'file' ? (
            <>
              <FileDropzone
                label="Video fayli *"
                accept={VIDEO_ACCEPT}
                maxSizeBytes={1073741824}
                file={videoFile}
                onFile={setVideoFile}
                icon={<VideoIcon />}
                hint="MP4/WebM/MOV, maks 1 GB"
              />
              <FileDropzone
                label="Muqova rasmi"
                accept={IMAGE_ACCEPT}
                maxSizeBytes={8 * 1024 * 1024}
                file={thumbnailFile}
                onFile={setThumbnailFile}
                preview
                hint="JPG/PNG/WebP, maks 8 MB"
              />
            </>
          ) : (
            <>
              <div className="space-y-1.5">
                <Label htmlFor="video-url">Video havolasi (URL) *</Label>
                <Input
                  id="video-url"
                  type="url"
                  inputMode="url"
                  value={videoUrl}
                  onChange={(e) => setVideoUrl(e.target.value)}
                  placeholder="https://.../video.mp4"
                />
                <p className="text-xs text-muted-foreground">
                  To&apos;g&apos;ridan-to&apos;g&apos;ri video havolasi (MP4/HLS) yoki tashqi CDN manzili.
                </p>
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="thumb-url">Muqova havolasi (URL)</Label>
                <Input
                  id="thumb-url"
                  type="url"
                  inputMode="url"
                  value={thumbnailUrl}
                  onChange={(e) => setThumbnailUrl(e.target.value)}
                  placeholder="https://.../cover.jpg (ixtiyoriy)"
                />
              </div>
            </>
          )}

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label>Yoshi (dan)</Label>
              <Select value={ageFrom} onValueChange={setAgeFrom}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
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
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
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
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
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
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
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
            <Label htmlFor="video-points">DON mukofoti</Label>
            <Input
              id="video-points"
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

          {showProgress && (
            <div className="space-y-1.5">
              <div className="flex items-center justify-between text-xs text-muted-foreground">
                <span>Yuklanmoqda...</span>
                <span>{progress}%</span>
              </div>
              <div className="h-2 w-full overflow-hidden rounded-full bg-muted">
                <div
                  className="h-full rounded-full bg-primary transition-all"
                  style={{ width: `${progress}%` }}
                />
              </div>
            </div>
          )}

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
              {mode === 'link' ? "Havola orqali qo'shish" : 'Yuklash'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
