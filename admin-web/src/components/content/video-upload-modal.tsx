'use client';

import { useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { Video as VideoIcon } from 'lucide-react';
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

export function VideoUploadModal({
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
  const [videoFile, setVideoFile] = useState<File | null>(null);
  const [thumbnailFile, setThumbnailFile] = useState<File | null>(null);
  const [ageFrom, setAgeFrom] = useState('0');
  const [ageTo, setAgeTo] = useState('18');
  const [planRequired, setPlanRequired] = useState('free');
  const [categoryId, setCategoryId] = useState(NO_CATEGORY);
  const [progress, setProgress] = useState(0);

  const { data: categories } = useQuery({
    queryKey: ['categories', 'video'],
    queryFn: () => contentApi.categories.list('video'),
    enabled: open,
  });

  const reset = () => {
    setTitle('');
    setDescription('');
    setVideoFile(null);
    setThumbnailFile(null);
    setAgeFrom('0');
    setAgeTo('18');
    setPlanRequired('free');
    setCategoryId(NO_CATEGORY);
    setProgress(0);
  };

  const upload = useMutation({
    mutationFn: () => {
      if (!videoFile) throw new Error('Video fayli tanlanmagan');
      const metadata = {
        title: title.trim(),
        description: description.trim(),
        ageFrom: Number(ageFrom),
        ageTo: Number(ageTo),
        planRequired,
        categoryId: categoryId === NO_CATEGORY ? undefined : categoryId,
        status: 'approved' as const, // yuklash = darhol bolaga ko'rinadi
        featured: false,
      };
      return contentApi.videos.upload(videoFile, metadata, thumbnailFile, setProgress);
    },
    onSuccess: () => {
      toast.success('Video yuklandi');
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
    if (upload.isPending) return;
    if (!next) reset();
    onOpenChange(next);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) {
      toast.error('Sarlavha kiritilishi shart');
      return;
    }
    if (!videoFile) {
      toast.error('Video fayli tanlanishi shart');
      return;
    }
    if (Number(ageTo) < Number(ageFrom)) {
      toast.error("Yosh oralig'i noto'g'ri: 'gacha' qiymati 'dan' qiymatidan kichik bo'lmasligi kerak");
      return;
    }
    upload.mutate();
  };

  const showProgress = upload.isPending && progress > 0;

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>Yangi video qo&apos;shish</DialogTitle>
        </DialogHeader>

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
              disabled={upload.isPending}
            >
              Bekor qilish
            </Button>
            <Button type="submit" loading={upload.isPending}>
              Yuklash
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
