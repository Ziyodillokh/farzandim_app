'use client';

// ─────────────────────────────────────────────────────────────────────
// AudiobookEditModal — audiokitobning BARCHA maydonlarini ko'rish va
// tahrirlash
// ─────────────────────────────────────────────────────────────────────
//
// NEGA KERAK (2026-09-05): panelda audiokitobni tahrirlash imkoni
// UMUMAN yo'q edi — faqat tasdiqlash/rad etish/o'chirish. Ayniqsa
// `planRequired` (tarif) yashirin edi: u bolaga ko'rinish-ko'rinmaslikni
// AYNAN hal qiladi (backend `planRequired IN allowedPlans(ota-ona tarifi)`
// bilan filtrlaydi), lekin ro'yxatda ko'rsatilmasdi ham, o'zgartirib ham
// bo'lmasdi. Noto'g'ri tarif bilan yuklangan kitobni tuzatishning yagona
// yo'li — o'chirib qayta yuklash edi.
//
// Backend `PATCH /admin/audiobooks/:id` (UpdateAudiobookDto) allaqachon
// tayyor edi; bu oyna faqat shuni ishlatadi.

import { useEffect, useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { Headphones, Info } from 'lucide-react';
import { toast } from 'sonner';
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import {
  Select, SelectTrigger, SelectValue, SelectContent, SelectItem,
} from '@/components/ui/select';
import { contentApi } from '@/lib/api/admin.api';
import { getApiErrorMessage } from '@/lib/api/client';
import { AGE_OPTIONS, PLAN_REQUIRED_OPTIONS } from '@/lib/constants/permissions';
import type { Audiobook } from '@/types/api.types';

const NO_CATEGORY = '__none__';

const STATUS_OPTIONS = [
  { value: 'approved', label: 'Tasdiqlangan — bolaga ko’rinadi' },
  { value: 'pending', label: 'Kutilayotgan — ko’rinmaydi' },
  { value: 'rejected', label: 'Rad etilgan — ko’rinmaydi' },
  { value: 'hidden', label: 'Yashirilgan — ko’rinmaydi' },
];

/** Sekundni "1 soat 05 daq" ko'rinishiga aylantiradi. */
function formatDuration(sec?: number | null): string {
  if (!sec || sec <= 0) return 'noma’lum';
  const h = Math.floor(sec / 3600);
  const m = Math.round((sec % 3600) / 60);
  return h > 0 ? `${h} soat ${String(m).padStart(2, '0')} daq` : `${m} daq`;
}

export function AudiobookEditModal({
  book,
  open,
  onOpenChange,
  onSuccess,
}: {
  book: Audiobook;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess: () => void;
}) {
  const [title, setTitle] = useState(book.title);
  const [author, setAuthor] = useState(book.author);
  const [description, setDescription] = useState(book.description ?? '');
  const [ageFrom, setAgeFrom] = useState(String(book.ageFrom));
  const [ageTo, setAgeTo] = useState(String(book.ageTo));
  const [planRequired, setPlanRequired] = useState(book.planRequired);
  const [status, setStatus] = useState<string>(book.status);
  const [xpReward, setXpReward] = useState(String(book.xpReward ?? 0));
  const [categoryId, setCategoryId] = useState(book.categoryId ?? NO_CATEGORY);

  // Oyna qayta ochilganda maydonlar eng so'nggi qiymatdan boshlansin
  // (ro'yxat yangilangach eski state qolib ketmasin).
  useEffect(() => {
    if (!open) return;
    setTitle(book.title);
    setAuthor(book.author);
    setDescription(book.description ?? '');
    setAgeFrom(String(book.ageFrom));
    setAgeTo(String(book.ageTo));
    setPlanRequired(book.planRequired);
    setStatus(book.status);
    setXpReward(String(book.xpReward ?? 0));
    setCategoryId(book.categoryId ?? NO_CATEGORY);
  }, [open, book]);

  const { data: categories } = useQuery({
    queryKey: ['categories', 'audiobook'],
    queryFn: () => contentApi.categories.list('audiobook'),
    enabled: open,
  });

  const save = useMutation({
    mutationFn: () =>
      contentApi.audiobooks.update(book.id, {
        title: title.trim(),
        author: author.trim(),
        description: description.trim(),
        ageFrom: Number(ageFrom),
        ageTo: Number(ageTo),
        planRequired,
        status: status as Audiobook['status'],
        xpReward: Number(xpReward) || 0,
        categoryId: categoryId === NO_CATEGORY ? null : categoryId,
      }),
    onSuccess: () => {
      toast.success('Saqlandi');
      onSuccess();
      onOpenChange(false);
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  const onSave = () => {
    if (!title.trim()) return toast.error('Nomi bo’sh bo’lmasin');
    if (!author.trim()) return toast.error('Muallif bo’sh bo’lmasin');
    if (Number(ageTo) < Number(ageFrom)) {
      return toast.error('Yosh oralig’i noto’g’ri');
    }
    save.mutate();
  };

  // Bolaga ko'rinish shartlari — uchalasi ham bajarilishi kerak.
  const visibleToChild = status === 'approved';
  const isPaidOnly = planRequired !== 'free';

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Headphones className="h-5 w-5" /> Audiokitobni tahrirlash
          </DialogTitle>
        </DialogHeader>

        {/* ── Ko'rinish holati — eng muhim ma'lumot, tepada ── */}
        <div className="rounded-lg border border-border bg-muted/40 p-3 text-sm">
          <div className="mb-2 flex items-center gap-2 font-medium">
            <Info className="h-4 w-4" /> Bolaga ko&apos;rinadimi?
          </div>
          <div className="flex flex-wrap gap-2">
            <Badge variant={visibleToChild ? 'success' : 'destructive'} size="sm">
              {visibleToChild ? 'Holat: tasdiqlangan' : 'Holat: tasdiqlanmagan'}
            </Badge>
            <Badge variant={isPaidOnly ? 'warning' : 'success'} size="sm">
              {isPaidOnly
                ? `Tarif: ${planRequired} — faqat obunachiga`
                : 'Tarif: bepul — hammaga'}
            </Badge>
            <Badge variant="outline" size="sm">
              Yosh: {ageFrom}–{ageTo}
            </Badge>
          </div>
          {isPaidOnly && (
            <p className="mt-2 text-xs text-warning">
              Bepul tarifdagi ota-onaning bolasi bu kitobni KO&apos;RMAYDI.
              Hammaga ochish uchun tarifni &laquo;Barchasi&raquo; qiling.
            </p>
          )}
        </div>

        <div className="grid gap-4 py-2">
          <div className="grid gap-2">
            <Label>Nomi</Label>
            <Input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={200} />
          </div>

          <div className="grid gap-2">
            <Label>Muallif</Label>
            <Input value={author} onChange={(e) => setAuthor(e.target.value)} maxLength={150} />
          </div>

          <div className="grid gap-2">
            <Label>Tavsif</Label>
            <Textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              maxLength={4000}
              rows={3}
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="grid gap-2">
              <Label>Yoshdan</Label>
              <Select value={ageFrom} onValueChange={setAgeFrom}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {AGE_OPTIONS.map((age) => (
                    <SelectItem key={age} value={String(age)}>{age} yosh</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="grid gap-2">
              <Label>Yoshgacha</Label>
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
            <div className="grid gap-2">
              <Label>Tarif</Label>
              <Select value={planRequired} onValueChange={setPlanRequired}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {PLAN_REQUIRED_OPTIONS.map((p) => (
                    <SelectItem key={p.value} value={p.value}>{p.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="grid gap-2">
              <Label>Holat</Label>
              <Select value={status} onValueChange={setStatus}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {STATUS_OPTIONS.map((s) => (
                    <SelectItem key={s.value} value={s.value}>{s.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="grid gap-2">
              <Label>Kategoriya</Label>
              <Select value={categoryId} onValueChange={setCategoryId}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value={NO_CATEGORY}>Yo&apos;q</SelectItem>
                  {(categories ?? []).map((c) => (
                    <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="grid gap-2">
              <Label>DON ball</Label>
              <Input
                type="number"
                min={0}
                value={xpReward}
                onChange={(e) => setXpReward(e.target.value)}
              />
            </div>
          </div>

          {/* ── O'zgartirib bo'lmaydigan ma'lumot ── */}
          <div className="grid grid-cols-2 gap-x-4 gap-y-1 rounded-lg border border-border p-3 text-xs text-muted-foreground">
            <span>Qismlar soni</span>
            <span className="text-right">{book.partsCount ?? 1}</span>
            <span>Davomiyligi</span>
            <span className="text-right">{formatDuration(book.durationSec)}</span>
            <span>Tinglangan</span>
            <span className="text-right">{book.listens ?? 0}</span>
            <span>ID</span>
            <span className="truncate text-right font-mono">{book.id}</span>
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Bekor qilish
          </Button>
          <Button onClick={onSave} disabled={save.isPending}>
            {save.isPending ? 'Saqlanmoqda…' : 'Saqlash'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
