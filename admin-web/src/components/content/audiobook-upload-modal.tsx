'use client';

import { useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { Headphones } from 'lucide-react';
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

const AUDIO_ACCEPT = {
  'audio/mpeg': ['.mp3'],
  'audio/mp4': ['.m4a'],
  'audio/aac': ['.aac'],
  'audio/wav': ['.wav'],
  'audio/ogg': ['.ogg'],
} as const;

const IMAGE_ACCEPT = {
  'image/jpeg': ['.jpg', '.jpeg'],
  'image/png': ['.png'],
  'image/webp': ['.webp'],
} as const;

const NO_CATEGORY = '__none__';

export function AudiobookUploadModal({
  open,
  onOpenChange,
  onSuccess,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess: () => void;
}) {
  const [title, setTitle] = useState('');
  const [author, setAuthor] = useState('');
  const [description, setDescription] = useState('');
  const [audioFile, setAudioFile] = useState<File | null>(null);
  const [thumbnailFile, setThumbnailFile] = useState<File | null>(null);
  const [ageFrom, setAgeFrom] = useState('0');
  const [ageTo, setAgeTo] = useState('18');
  const [planRequired, setPlanRequired] = useState('free');
  const [partsCount, setPartsCount] = useState('1');
  const [pointsReward, setPointsReward] = useState('10');
  const [categoryId, setCategoryId] = useState(NO_CATEGORY);
  const [progress, setProgress] = useState(0);

  const { data: categories } = useQuery({
    queryKey: ['categories', 'audiobook'],
    queryFn: () => contentApi.categories.list('audiobook'),
    enabled: open,
  });

  const reset = () => {
    setTitle('');
    setAuthor('');
    setDescription('');
    setAudioFile(null);
    setThumbnailFile(null);
    setAgeFrom('0');
    setAgeTo('18');
    setPlanRequired('free');
    setPartsCount('1');
    setPointsReward('10');
    setCategoryId(NO_CATEGORY);
    setProgress(0);
  };

  const upload = useMutation({
    mutationFn: () => {
      if (!audioFile) throw new Error('Audio fayli tanlanmagan');
      const metadata = {
        title: title.trim(),
        author: author.trim(),
        description: description.trim(),
        ageFrom: Number(ageFrom),
        ageTo: Number(ageTo),
        planRequired,
        categoryId: categoryId === NO_CATEGORY ? undefined : categoryId,
        partsCount: Number(partsCount) || 1,
        pointsReward: Number(pointsReward) || 0,
        status: 'approved' as const, // yuklash = darhol bolaga ko'rinadi
      };
      return contentApi.audiobooks.upload(audioFile, metadata, thumbnailFile, setProgress);
    },
    onSuccess: () => {
      toast.success('Audiokitob yuklandi');
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
    if (!author.trim()) {
      toast.error('Muallif kiritilishi shart');
      return;
    }
    if (!audioFile) {
      toast.error('Audio fayli tanlanishi shart');
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
          <DialogTitle>Yangi audiokitob qo&apos;shish</DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="audiobook-title">Sarlavha *</Label>
            <Input
              id="audiobook-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              maxLength={200}
              placeholder="Audiokitob sarlavhasi"
              required
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="audiobook-author">Muallif *</Label>
            <Input
              id="audiobook-author"
              value={author}
              onChange={(e) => setAuthor(e.target.value)}
              maxLength={200}
              placeholder="Muallif ismi"
              required
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="audiobook-description">Tavsif</Label>
            <Textarea
              id="audiobook-description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              maxLength={2000}
              placeholder="Qisqa tavsif (ixtiyoriy)"
            />
          </div>

          <FileDropzone
            label="Audio fayli *"
            accept={AUDIO_ACCEPT}
            maxSizeBytes={524288000}
            file={audioFile}
            onFile={setAudioFile}
            icon={<Headphones />}
            hint="MP3/M4A/AAC/WAV/OGG, maks 500 MB"
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

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label htmlFor="audiobook-parts">Qismlar soni</Label>
              <Input
                id="audiobook-parts"
                type="number"
                min={1}
                value={partsCount}
                onChange={(e) => setPartsCount(e.target.value)}
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="audiobook-points">Ball mukofoti</Label>
              <Input
                id="audiobook-points"
                type="number"
                min={0}
                value={pointsReward}
                onChange={(e) => setPointsReward(e.target.value)}
              />
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
