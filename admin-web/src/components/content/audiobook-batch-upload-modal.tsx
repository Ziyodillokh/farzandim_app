'use client';

// ─────────────────────────────────────────────────────────────────────
// AudiobookBatchUploadModal — ko'p qismli audiokitobni BIR MARTADA yuklash
// ─────────────────────────────────────────────────────────────────────
//
// Muammo: 50 qismli audiokitobni bitta-bitta yuklash kerak edi. Endi:
//   • bir marta hamma audio fayl tanlanadi (multiple),
//   • fayllar TABIIY tartibda saralanadi ("1, 2, 10" to'g'ri, "1, 10, 2" emas),
//   • har biri "{Kitob nomi} — {N}" sarlavha bilan ketma-ket yuklanadi
//     (bola ilovasi shu sarlavha bo'yicha bitta seriyaga guruhlaydi),
//   • umumiy + har fayl progressi, xato bo'lsa qolganini davom ettiradi va
//     xatolarni qayta yuklash mumkin.
//
// Umumiy maydonlar (muallif, tavsif, yosh, tarif, kategoriya, muqova, DON)
// barcha qismlarga bir xil qo'llanadi.

import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Headphones, ArrowUp, ArrowDown, Trash2, CheckCircle2, XCircle, Loader2 } from 'lucide-react';
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

const AUDIO_EXT = ['.mp3', '.m4a', '.aac', '.wav', '.ogg'];
const IMAGE_ACCEPT = {
  'image/jpeg': ['.jpg', '.jpeg'],
  'image/png': ['.png'],
  'image/webp': ['.webp'],
} as const;
const NO_CATEGORY = '__none__';
const MAX_AUDIO_BYTES = 524_288_000; // 500 MB

type PartStatus = 'pending' | 'uploading' | 'done' | 'error';

interface BatchPart {
  id: string;
  file: File;
  durationSec: number;
  progress: number;
  status: PartStatus;
  error?: string;
}

let _seq = 0;
const nextId = () => `p${Date.now()}_${_seq++}`;

/// Fayl nomini kengaytmasiz.
function baseName(name: string): string {
  const i = name.lastIndexOf('.');
  return i > 0 ? name.slice(0, i) : name;
}

/// Audio faylning davomiyligini (soniya) o'qiydi.
function readDuration(file: File): Promise<number> {
  return new Promise((resolve) => {
    const url = URL.createObjectURL(file);
    const audio = new Audio();
    audio.preload = 'metadata';
    audio.onloadedmetadata = () => {
      const d = Number.isFinite(audio.duration) && audio.duration > 0
        ? Math.round(audio.duration)
        : 0;
      URL.revokeObjectURL(url);
      resolve(d);
    };
    audio.onerror = () => {
      URL.revokeObjectURL(url);
      resolve(0);
    };
    audio.src = url;
  });
}

export function AudiobookBatchUploadModal({
  open,
  onOpenChange,
  onSuccess,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess: () => void;
}) {
  const [seriesTitle, setSeriesTitle] = useState('');
  const [author, setAuthor] = useState('');
  const [description, setDescription] = useState('');
  const [thumbnailFile, setThumbnailFile] = useState<File | null>(null);
  const [ageFrom, setAgeFrom] = useState('0');
  const [ageTo, setAgeTo] = useState('18');
  const [planRequired, setPlanRequired] = useState('free');
  const [categoryId, setCategoryId] = useState(NO_CATEGORY);
  const [pointsReward, setPointsReward] = useState('10');
  const [startNumber, setStartNumber] = useState('1');
  const [parts, setParts] = useState<BatchPart[]>([]);
  const [uploading, setUploading] = useState(false);

  const { data: categories } = useQuery({
    queryKey: ['categories', 'audiobook'],
    queryFn: () => contentApi.categories.list('audiobook'),
    enabled: open,
  });

  const start = Number(startNumber) || 1;

  // Qism sarlavhasi: "{Kitob nomi} — {N}". Bola ilovasi shu naqsh bo'yicha
  // seriyaga guruhlaydi (regex: nom + ajratgich + raqam).
  const partTitle = (index: number) => `${seriesTitle.trim()} - ${start + index}`;

  const doneCount = useMemo(
    () => parts.filter((p) => p.status === 'done').length,
    [parts],
  );
  const errorCount = useMemo(
    () => parts.filter((p) => p.status === 'error').length,
    [parts],
  );

  const reset = () => {
    setSeriesTitle('');
    setAuthor('');
    setDescription('');
    setThumbnailFile(null);
    setAgeFrom('0');
    setAgeTo('18');
    setPlanRequired('free');
    setCategoryId(NO_CATEGORY);
    setPointsReward('10');
    setStartNumber('1');
    setParts([]);
    setUploading(false);
  };

  // Fayllar tanlanganda — TABIIY tartibda saralab, davomiyliklarini o'qiymiz.
  const addFiles = async (fileList: FileList | null) => {
    if (!fileList || fileList.length === 0) return;
    const incoming = Array.from(fileList).filter((f) => {
      const lower = f.name.toLowerCase();
      const okExt = AUDIO_EXT.some((e) => lower.endsWith(e));
      if (!okExt) return false;
      if (f.size > MAX_AUDIO_BYTES) {
        toast.error(`"${f.name}" 500 MB dan katta — o'tkazib yuborildi`);
        return false;
      }
      return true;
    });
    if (incoming.length === 0) return;

    // Tabiiy (raqamli) tartib: "9-qism" < "10-qism".
    incoming.sort((a, b) =>
      a.name.localeCompare(b.name, undefined, { numeric: true, sensitivity: 'base' }),
    );

    const newParts: BatchPart[] = incoming.map((file) => ({
      id: nextId(),
      file,
      durationSec: 0,
      progress: 0,
      status: 'pending',
    }));
    setParts((prev) => [...prev, ...newParts]);

    // Davomiyliklarni fon rejimida o'qiymiz (yuklashni bloklamaydi).
    for (const p of newParts) {
      readDuration(p.file).then((d) => {
        setParts((prev) =>
          prev.map((x) => (x.id === p.id ? { ...x, durationSec: d } : x)),
        );
      });
    }
  };

  const move = (index: number, dir: -1 | 1) => {
    setParts((prev) => {
      const next = [...prev];
      const j = index + dir;
      if (j < 0 || j >= next.length) return prev;
      [next[index], next[j]] = [next[j], next[index]];
      return next;
    });
  };

  const removePart = (id: string) => {
    setParts((prev) => prev.filter((p) => p.id !== id));
  };

  const setPart = (id: string, patch: Partial<BatchPart>) => {
    setParts((prev) => prev.map((p) => (p.id === id ? { ...p, ...patch } : p)));
  };

  const validate = (): string | null => {
    if (!seriesTitle.trim()) return 'Kitob nomi kiritilishi shart';
    if (!author.trim()) return 'Muallif kiritilishi shart';
    if (parts.length === 0) return 'Kamida bitta audio fayl tanlang';
    if (Number(ageTo) < Number(ageFrom)) {
      return "Yosh oralig'i noto'g'ri: 'gacha' 'dan'dan kichik bo'lmasin";
    }
    return null;
  };

  const runUpload = async () => {
    const err = validate();
    if (err) {
      toast.error(err);
      return;
    }
    setUploading(true);

    // Tartib va sarlavha yuklash paytida o'zgarmaydi (boshqaruv bloklangan) —
    // shuning uchun sarlavha uchun snapshot indeksdan foydalanamiz.
    const snapshot = parts;
    const total = snapshot.length;
    // Faqat hali yuklanmagan (pending yoki xato) qismlar — qayta urinishda
    // muvaffaqiyatlilar takrorlanmaydi.
    const queue = snapshot.filter((p) => p.status !== 'done');
    const alreadyDone = total - queue.length;

    // Natijani LOKAL hisoblaymiz — React state (`parts`) sikl ichida eskiradi.
    let failed = 0;

    for (const part of queue) {
      const orderIndex = snapshot.findIndex((p) => p.id === part.id);
      setPart(part.id, { status: 'uploading', progress: 0, error: undefined });

      const metadata = {
        title: partTitle(orderIndex),
        author: author.trim(),
        description: description.trim(),
        ageFrom: Number(ageFrom),
        ageTo: Number(ageTo),
        planRequired,
        categoryId: categoryId === NO_CATEGORY ? undefined : categoryId,
        partsCount: total,
        xpReward: Number(pointsReward) || 0,
        durationSec: part.durationSec > 0 ? part.durationSec : undefined,
        status: 'approved' as const,
      };

      try {
        await contentApi.audiobooks.upload(
          part.file,
          metadata,
          thumbnailFile,
          (p) => setPart(part.id, { progress: p }),
        );
        setPart(part.id, { status: 'done', progress: 100 });
      } catch (e) {
        failed += 1;
        setPart(part.id, { status: 'error', error: getApiErrorMessage(e) });
      }
    }

    setUploading(false);

    const succeeded = alreadyDone + (queue.length - failed);
    if (failed === 0) {
      toast.success(`${total} ta qism yuklandi`);
      onSuccess();
      reset();
      onOpenChange(false);
    } else {
      toast.error(`${succeeded}/${total} yuklandi — ${failed} tasi xato`);
      onSuccess(); // muvaffaqiyatlilari darhol ro'yxatga qo'shilsin
    }
  };

  const handleOpenChange = (next: boolean) => {
    if (uploading) return; // yuklash paytida yopilmaydi
    if (!next) reset();
    onOpenChange(next);
  };

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>Ko&apos;p qismli audiokitob (birdan yuklash)</DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor="series-title">Kitob nomi *</Label>
              <Input
                id="series-title"
                value={seriesTitle}
                onChange={(e) => setSeriesTitle(e.target.value)}
                maxLength={180}
                placeholder="Masalan: Alpomish"
                disabled={uploading}
              />
              <p className="text-xs text-muted-foreground">
                Har qism &quot;{seriesTitle.trim() || 'Kitob nomi'} - N&quot; bo&apos;lib
                saqlanadi (bolada bitta seriya bo&apos;lib guruhlanadi).
              </p>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="series-author">Muallif *</Label>
              <Input
                id="series-author"
                value={author}
                onChange={(e) => setAuthor(e.target.value)}
                maxLength={200}
                placeholder="Muallif ismi"
                disabled={uploading}
              />
            </div>
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="series-desc">Tavsif</Label>
            <Textarea
              id="series-desc"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              maxLength={2000}
              placeholder="Qisqa tavsif (barcha qismlarга bir xil)"
              disabled={uploading}
            />
          </div>

          {/* Ko'p audio fayl tanlash */}
          <div className="space-y-1.5">
            <Label>Audio fayllar * (bir vaqtda bir nechta tanlang)</Label>
            <label
              className={`flex cursor-pointer flex-col items-center justify-center gap-2 rounded-lg border border-dashed border-border px-4 py-6 text-center transition-colors hover:bg-muted/50 ${uploading ? 'pointer-events-none opacity-60' : ''}`}
            >
              <Headphones className="h-6 w-6 text-muted-foreground" />
              <span className="text-sm font-medium">
                Bosing yoki bir nechta audio faylni tanlang
              </span>
              <span className="text-xs text-muted-foreground">
                MP3/M4A/AAC/WAV/OGG · har biri maks 500 MB · fayl nomi bo&apos;yicha
                tartiblanadi
              </span>
              <input
                type="file"
                accept={AUDIO_EXT.join(',')}
                multiple
                className="hidden"
                disabled={uploading}
                onChange={(e) => {
                  void addFiles(e.target.files);
                  e.target.value = ''; // qayta tanlash uchun
                }}
              />
            </label>
          </div>

          {/* Qismlar ro'yxati (tartib + tahrir) */}
          {parts.length > 0 && (
            <div className="space-y-1.5">
              <div className="flex items-center justify-between">
                <Label>Qismlar tartibi ({parts.length} ta)</Label>
                {!uploading && (
                  <button
                    type="button"
                    className="text-xs text-muted-foreground hover:text-destructive"
                    onClick={() => setParts([])}
                  >
                    Hammasini tozalash
                  </button>
                )}
              </div>
              <div className="max-h-72 space-y-1.5 overflow-y-auto rounded-lg border border-border p-2">
                {parts.map((p, i) => (
                  <div
                    key={p.id}
                    className="flex items-center gap-2 rounded-md bg-muted/40 px-2 py-1.5"
                  >
                    <span className="w-8 shrink-0 text-center text-xs font-semibold text-muted-foreground">
                      {start + i}
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium">{partTitle(i)}</p>
                      <p className="truncate text-xs text-muted-foreground">
                        {p.file.name}
                        {p.durationSec > 0 &&
                          ` · ${Math.floor(p.durationSec / 60)}:${String(p.durationSec % 60).padStart(2, '0')}`}
                      </p>
                      {p.status === 'uploading' && (
                        <div className="mt-1 h-1 w-full overflow-hidden rounded-full bg-muted">
                          <div
                            className="h-full rounded-full bg-primary transition-all"
                            style={{ width: `${p.progress}%` }}
                          />
                        </div>
                      )}
                      {p.status === 'error' && (
                        <p className="truncate text-xs text-destructive">{p.error}</p>
                      )}
                    </div>
                    {/* Holat / boshqaruv */}
                    {p.status === 'done' ? (
                      <CheckCircle2 className="h-4 w-4 shrink-0 text-success" />
                    ) : p.status === 'uploading' ? (
                      <Loader2 className="h-4 w-4 shrink-0 animate-spin text-primary" />
                    ) : p.status === 'error' ? (
                      <XCircle className="h-4 w-4 shrink-0 text-destructive" />
                    ) : uploading ? (
                      <span className="w-4" />
                    ) : (
                      <div className="flex shrink-0 items-center">
                        <button
                          type="button"
                          className="rounded p-1 text-muted-foreground hover:bg-muted disabled:opacity-30"
                          disabled={i === 0}
                          onClick={() => move(i, -1)}
                        >
                          <ArrowUp className="h-3.5 w-3.5" />
                        </button>
                        <button
                          type="button"
                          className="rounded p-1 text-muted-foreground hover:bg-muted disabled:opacity-30"
                          disabled={i === parts.length - 1}
                          onClick={() => move(i, 1)}
                        >
                          <ArrowDown className="h-3.5 w-3.5" />
                        </button>
                        <button
                          type="button"
                          className="rounded p-1 text-muted-foreground hover:bg-muted hover:text-destructive"
                          onClick={() => removePart(p.id)}
                        >
                          <Trash2 className="h-3.5 w-3.5" />
                        </button>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          <FileDropzone
            label="Muqova rasmi (barcha qismlarga)"
            accept={IMAGE_ACCEPT}
            maxSizeBytes={8 * 1024 * 1024}
            file={thumbnailFile}
            onFile={setThumbnailFile}
            preview
            hint="JPG/PNG/WebP, maks 8 MB"
          />

          <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
            <div className="space-y-1.5">
              <Label>Yoshi (dan)</Label>
              <Select value={ageFrom} onValueChange={setAgeFrom} disabled={uploading}>
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
              <Select value={ageTo} onValueChange={setAgeTo} disabled={uploading}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {AGE_OPTIONS.map((age) => (
                    <SelectItem key={age} value={String(age)}>{age} yosh</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="batch-start">Boshlang&apos;ich raqam</Label>
              <Input
                id="batch-start"
                type="number"
                min={1}
                value={startNumber}
                onChange={(e) => setStartNumber(e.target.value)}
                disabled={uploading}
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
            <div className="space-y-1.5">
              <Label>Tarif</Label>
              <Select value={planRequired} onValueChange={setPlanRequired} disabled={uploading}>
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
              <Select value={categoryId} onValueChange={setCategoryId} disabled={uploading}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value={NO_CATEGORY}>Kategoriyasiz</SelectItem>
                  {categories?.map((cat) => (
                    <SelectItem key={cat.id} value={cat.id}>{cat.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="batch-points">DON mukofoti (har qism)</Label>
              <Input
                id="batch-points"
                type="number"
                min={0}
                value={pointsReward}
                onChange={(e) => setPointsReward(e.target.value)}
                disabled={uploading}
              />
            </div>
          </div>

          {uploading && (
            <div className="rounded-lg bg-muted/40 px-3 py-2 text-sm text-muted-foreground">
              Yuklanmoqda… {doneCount}/{parts.length} tayyor
              {errorCount > 0 && ` · ${errorCount} xato`}
            </div>
          )}
        </div>

        <DialogFooter className="gap-2 pt-2">
          <Button
            type="button"
            variant="outline"
            onClick={() => handleOpenChange(false)}
            disabled={uploading}
          >
            {errorCount > 0 && !uploading ? 'Yopish' : 'Bekor qilish'}
          </Button>
          <Button type="button" loading={uploading} onClick={() => void runUpload()}>
            {errorCount > 0 && !uploading
              ? `Xatolarni qayta yuklash (${errorCount})`
              : `${parts.length || ''} qismni yuklash`.trim()}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
