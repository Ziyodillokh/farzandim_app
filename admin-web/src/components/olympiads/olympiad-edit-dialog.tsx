'use client';

/**
 * Konkursni tahrirlash oynasi — `PATCH /admin/olympiads/:id`.
 *
 * Faqat ASOSIY maydonlar: backend `UpdateOlympiadDto` = Partial(Omit(Create,
 * ['questions'])), ya'ni savollar bu endpoint orqali o'zgarmaydi (ular uchun
 * alohida `/:id/questions` marshrutlari bor).
 *
 * Avval admin panelda tahrirlash umuman yo'q edi: `olympiadsApi.update` mavjud
 * bo'lsa-da, hech qayerdan chaqirilmasdi.
 */

import { useEffect, useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Loader2 } from 'lucide-react';

import {
  Dialog, DialogContent, DialogHeader, DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select';
import { olympiadsApi } from '@/lib/api/admin.api';
import { getApiErrorMessage } from '@/lib/api/client';
import type { Olympiad } from '@/types/api.types';

const SUBJECTS = ['Matematika', 'Ona tili', 'Ingliz tili', 'Fizika', 'Kimyo', 'IT / Mantiq'];
const TYPES = ['test', 'creative', 'mixed'] as const;
const DIFFICULTIES = ['oson', "o'rta", 'qiyin'] as const;

const TYPE_LABELS: Record<string, string> = {
  test: 'Test',
  creative: 'Ijodiy',
  mixed: 'Aralash',
};

/** ISO → `datetime-local` input formati (mahalliy vaqt, sekundsiz). */
function toLocalInput(iso: string | null | undefined): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function OlympiadEditDialog({
  olympiad,
  onOpenChange,
  onSuccess,
}: {
  /** `null` — oyna yopiq. */
  olympiad: Olympiad | null;
  onOpenChange: (v: boolean) => void;
  onSuccess: () => void;
}) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [subject, setSubject] = useState('Matematika');
  const [ageFrom, setAgeFrom] = useState(9);
  const [ageTo, setAgeTo] = useState(12);
  const [type, setType] = useState<string>('test');
  const [difficulty, setDifficulty] = useState<string>("o'rta");
  const [durationMin, setDurationMin] = useState(30);
  const [startTime, setStartTime] = useState('');
  const [endTime, setEndTime] = useState('');

  // Boshqa konkurs tanlansa maydonlarni qayta to'ldiramiz.
  useEffect(() => {
    if (!olympiad) return;
    setTitle(olympiad.title);
    setDescription(olympiad.description ?? '');
    setSubject(olympiad.subject);
    setAgeFrom(olympiad.ageFrom);
    setAgeTo(olympiad.ageTo);
    setType(olympiad.type);
    setDifficulty(olympiad.difficulty);
    setDurationMin(olympiad.durationMin);
    setStartTime(toLocalInput(olympiad.startTime));
    setEndTime(toLocalInput(olympiad.endTime));
  }, [olympiad]);

  const save = useMutation({
    mutationFn: () => {
      if (!olympiad) throw new Error('Konkurs tanlanmagan');
      return olympiadsApi.update(olympiad.id, {
        title: title.trim(),
        description: description.trim() || null,
        subject,
        ageFrom,
        ageTo,
        type: type as (typeof TYPES)[number],
        difficulty: difficulty as (typeof DIFFICULTIES)[number],
        durationMin,
        startTime: new Date(startTime).toISOString(),
        endTime: new Date(endTime).toISOString(),
      });
    },
    onSuccess: () => {
      toast.success('Saqlandi');
      onSuccess();
      onOpenChange(false);
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  // Backend ham tekshiradi (yosh/vaqt juftligi), lekin xatoni oldindan
  // ko'rsatgan ma'qul — "Saqlash" behuda 400 qaytarmasin.
  const invalid =
    !title.trim() ||
    ageFrom > ageTo ||
    !startTime ||
    !endTime ||
    new Date(startTime) >= new Date(endTime) ||
    durationMin < 1;

  return (
    <Dialog open={olympiad !== null} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Konkursni tahrirlash</DialogTitle>
        </DialogHeader>

        <div className="max-h-[60vh] space-y-4 overflow-y-auto px-0.5 py-2">
          <Field label="Konkurs nomi">
            <Input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={120} />
          </Field>

          <Field label="Tavsif">
            <Textarea value={description} onChange={(e) => setDescription(e.target.value)} maxLength={500} />
          </Field>

          <div className="grid grid-cols-2 gap-4">
            <Field label="Fan">
              <Select value={subject} onValueChange={setSubject}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {SUBJECTS.map((s) => <SelectItem key={s} value={s}>{s}</SelectItem>)}
                </SelectContent>
              </Select>
            </Field>

            <Field label="Turi">
              <Select value={type} onValueChange={setType}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {TYPES.map((t) => <SelectItem key={t} value={t}>{TYPE_LABELS[t]}</SelectItem>)}
                </SelectContent>
              </Select>
            </Field>

            <Field label="Daraja">
              <Select value={difficulty} onValueChange={setDifficulty}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {DIFFICULTIES.map((d) => <SelectItem key={d} value={d}>{d}</SelectItem>)}
                </SelectContent>
              </Select>
            </Field>

            <Field label="Davomiyligi (daqiqa)">
              <Input
                type="number"
                min={1}
                value={durationMin}
                onChange={(e) => setDurationMin(Number(e.target.value) || 0)}
              />
            </Field>

            <Field label="Yosh (dan)">
              <Input
                type="number"
                min={1}
                value={ageFrom}
                onChange={(e) => setAgeFrom(Number(e.target.value) || 0)}
              />
            </Field>

            <Field label="Yosh (gacha)">
              <Input
                type="number"
                min={1}
                value={ageTo}
                onChange={(e) => setAgeTo(Number(e.target.value) || 0)}
              />
            </Field>

            <Field label="Boshlanishi">
              <Input type="datetime-local" value={startTime} onChange={(e) => setStartTime(e.target.value)} />
            </Field>

            <Field label="Tugashi">
              <Input type="datetime-local" value={endTime} onChange={(e) => setEndTime(e.target.value)} />
            </Field>
          </div>

          {ageFrom > ageTo && (
            <p className="text-xs text-destructive">Yosh oralig&apos;i noto&apos;g&apos;ri: &quot;dan&quot; &quot;gacha&quot;dan katta.</p>
          )}
          {startTime && endTime && new Date(startTime) >= new Date(endTime) && (
            <p className="text-xs text-destructive">Tugash vaqti boshlanishdan keyin bo&apos;lishi kerak.</p>
          )}

          <p className="text-xs text-muted-foreground">
            Savollar bu yerda o&apos;zgarmaydi — ular alohida boshqariladi.
          </p>
        </div>

        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            Bekor qilish
          </Button>
          <Button onClick={() => save.mutate()} disabled={invalid || save.isPending}>
            {save.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
            Saqlash
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="space-y-1.5">
      <Label>{label}</Label>
      {children}
    </div>
  );
}
