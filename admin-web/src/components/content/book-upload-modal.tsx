'use client';

import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { FileText } from 'lucide-react';
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

const PDF_ACCEPT = {
  'application/pdf': ['.pdf'],
} as const;

const IMAGE_ACCEPT = {
  'image/jpeg': ['.jpg', '.jpeg'],
  'image/png': ['.png'],
  'image/webp': ['.webp'],
} as const;

const BOOK_CATEGORIES = [
  { value: 'school', label: 'Maktab' },
  { value: 'adabiyot', label: 'Adabiyot' },
  { value: 'tarjima', label: 'Tarjima' },
] as const;

export function BookUploadModal({
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
  const [pdfFile, setPdfFile] = useState<File | null>(null);
  const [coverFile, setCoverFile] = useState<File | null>(null);
  const [pages, setPages] = useState('1');
  const [ageFrom, setAgeFrom] = useState('7');
  const [ageTo, setAgeTo] = useState('14');
  const [category, setCategory] = useState('school');
  const [planRequired, setPlanRequired] = useState('free');
  const [progress, setProgress] = useState(0);

  const reset = () => {
    setTitle('');
    setAuthor('');
    setDescription('');
    setPdfFile(null);
    setCoverFile(null);
    setPages('1');
    setAgeFrom('7');
    setAgeTo('14');
    setCategory('school');
    setPlanRequired('free');
    setProgress(0);
  };

  const upload = useMutation({
    mutationFn: () => {
      if (!pdfFile) throw new Error('PDF fayli tanlanmagan');
      const metadata = {
        title: title.trim(),
        author: author.trim(),
        description: description.trim(),
        pages: Number(pages) || 1,
        ageFrom: Number(ageFrom),
        ageTo: Number(ageTo),
        category,
        planRequired,
        status: 'approved' as const, // yuklash = darhol bolaga ko'rinadi
      };
      return contentApi.books.upload(pdfFile, metadata, coverFile, setProgress);
    },
    onSuccess: () => {
      toast.success('Kitob yuklandi');
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
    if (!pdfFile) {
      toast.error('PDF fayli tanlanishi shart');
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
          <DialogTitle>Yangi kitob qo&apos;shish</DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="book-title">Sarlavha *</Label>
            <Input
              id="book-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              maxLength={200}
              placeholder="Kitob sarlavhasi"
              required
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="book-author">Muallif *</Label>
            <Input
              id="book-author"
              value={author}
              onChange={(e) => setAuthor(e.target.value)}
              maxLength={150}
              placeholder="Muallif ismi"
              required
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="book-description">Tavsif</Label>
            <Textarea
              id="book-description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              maxLength={4000}
              placeholder="Qisqa tavsif (ixtiyoriy)"
            />
          </div>

          <FileDropzone
            label="PDF fayli *"
            accept={PDF_ACCEPT}
            maxSizeBytes={52428800}
            file={pdfFile}
            onFile={setPdfFile}
            icon={<FileText />}
            hint="PDF, maks 50 MB"
          />

          <FileDropzone
            label="Muqova rasmi"
            accept={IMAGE_ACCEPT}
            maxSizeBytes={5 * 1024 * 1024}
            file={coverFile}
            onFile={setCoverFile}
            preview
            hint="JPG/PNG/WebP, maks 5 MB"
          />

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label htmlFor="book-pages">Sahifalar soni</Label>
              <Input
                id="book-pages"
                type="number"
                min={1}
                value={pages}
                onChange={(e) => setPages(e.target.value)}
              />
            </div>
            <div className="space-y-1.5">
              <Label>Kategoriya</Label>
              <Select value={category} onValueChange={setCategory}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {BOOK_CATEGORIES.map((opt) => (
                    <SelectItem key={opt.value} value={opt.value}>{opt.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

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
