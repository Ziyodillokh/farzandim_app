'use client';

import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import {
  Check,
  ChevronLeft,
  ChevronRight,
  Plus,
  Trash2,
  Loader2,
  ImagePlus,
  X,
} from 'lucide-react';
import {
  Dialog, DialogContent, DialogHeader, DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select';
import { olympiadsApi, type OlympiadCreatePayload, type OlympiadQuestionInput } from '@/lib/api/admin.api';
import { getApiErrorMessage } from '@/lib/api/client';
import { cn } from '@/lib/utils';

const SUBJECTS = ['Matematika', 'Ona tili', 'Ingliz tili', 'Fizika', 'Kimyo', 'IT / Mantiq'];
const STEPS = ['Asosiy', 'Vaqt', 'Savollar', 'Sozlamalar'];

const API_BASE = process.env.NEXT_PUBLIC_API_URL || '';
const questionImageUrl = (key: string) => `${API_BASE}/olympiad-images/${key}`;

function emptyQuestion(): OlympiadQuestionInput {
  return {
    text: '',
    options: ['', '', '', ''],
    optionImages: ['', '', '', ''],
    correctIndex: 0,
    points: 10,
    imageKey: null,
  };
}

export function OlympiadWizard({
  open,
  onOpenChange,
  onSuccess,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  onSuccess: () => void;
}) {
  const [step, setStep] = useState(0);

  // Step 0
  const [title, setTitle] = useState("Iste'dod Uchquni");
  const [description, setDescription] = useState('');
  const [subject, setSubject] = useState('Matematika');
  const [ageFrom, setAgeFrom] = useState(9);
  const [ageTo, setAgeTo] = useState(12);
  const [coverKey, setCoverKey] = useState<string | null>(null);
  const [uploadingCover, setUploadingCover] = useState(false);

  const handleCoverImage = async (file?: File | null) => {
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) {
      toast.error('Rasm juda katta (maks 5 MB)');
      return;
    }
    setUploadingCover(true);
    try {
      const { key } = await olympiadsApi.uploadQuestionImage(file);
      setCoverKey(key);
    } catch (e) {
      toast.error(getApiErrorMessage(e));
    } finally {
      setUploadingCover(false);
    }
  };

  // Step 1
  const [durationMin, setDurationMin] = useState(30);

  // Step 2
  const [questions, setQuestions] = useState<OlympiadQuestionInput[]>([emptyQuestion()]);
  const [uploadingIdx, setUploadingIdx] = useState<number | null>(null);

  const handleQuestionImage = async (qi: number, file?: File | null) => {
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) {
      toast.error('Rasm juda katta (maks 5 MB)');
      return;
    }
    setUploadingIdx(qi);
    try {
      const { key } = await olympiadsApi.uploadQuestionImage(file);
      setQuestions((qs) => qs.map((x, i) => (i === qi ? { ...x, imageKey: key } : x)));
    } catch (e) {
      toast.error(getApiErrorMessage(e));
    } finally {
      setUploadingIdx(null);
    }
  };

  // Har VARIANT uchun ixtiyoriy rasm (matematik formula/diagramma javoblar).
  const [uploadingOpt, setUploadingOpt] = useState<string | null>(null);

  const handleOptionImage = async (qi: number, oi: number, file?: File | null) => {
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) {
      toast.error('Rasm juda katta (maks 5 MB)');
      return;
    }
    setUploadingOpt(`${qi}-${oi}`);
    try {
      const { key } = await olympiadsApi.uploadQuestionImage(file);
      setQuestions((qs) =>
        qs.map((x, i) =>
          i === qi
            ? {
                ...x,
                optionImages: (x.optionImages ?? x.options.map(() => '')).map(
                  (v, j) => (j === oi ? key : v),
                ),
              }
            : x,
        ),
      );
    } catch (e) {
      toast.error(getApiErrorMessage(e));
    } finally {
      setUploadingOpt(null);
    }
  };

  // Step 3
  const [type, setType] = useState('test');
  const [difficulty, setDifficulty] = useState("o'rta");
  const [xpReward, setXpReward] = useState(50);
  const [shuffleQuestions, setShuffleQuestions] = useState(true);
  const [shuffleAnswers, setShuffleAnswers] = useState(true);
  const [hideResults, setHideResults] = useState(false);
  const [allowBack, setAllowBack] = useState(true);
  const [certificateEnabled, setCertificateEnabled] = useState(true);

  const reset = () => {
    setStep(0); setTitle("Iste'dod Uchquni"); setDescription(''); setSubject('Matematika');
    setAgeFrom(9); setAgeTo(12); setCoverKey(null); setDurationMin(30); setQuestions([emptyQuestion()]);
    setType('test'); setDifficulty("o'rta"); setXpReward(50);
    setShuffleQuestions(true); setShuffleAnswers(true); setHideResults(false);
    setAllowBack(true); setCertificateEnabled(true);
  };

  const create = useMutation({
    mutationFn: () => {
      const now = new Date();
      // Konkurs DARHOL ochiq bo'lsin: yaratilib (publish qilingach) bola
      // darhol qatnasha oladi. startTime = hozir (1 daq bufer — soat farqi
      // tufayli "scheduled" bo'lib qolmasin), endTime = +30 kun (MAVJUDLIK
      // oynasi). MUHIM: `durationMin` — bu HAR URINISH uchun vaqt chegarasi
      // (savollarga javob berish), mavjudlik oynasi EMAS. Avval end =
      // start + durationMin edi → konkurs atigi 30 daq va ERTAGA ochilardi,
      // shu sabab bola qatnasha olmasdi.
      const start = new Date(now.getTime() - 60 * 1000);
      const end = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
      const payload: OlympiadCreatePayload = {
        title, description, subject, ageFrom, ageTo, type, difficulty,
        coverKey,
        startTime: start.toISOString(), endTime: end.toISOString(),
        durationMin, xpReward,
        shuffleQuestions, shuffleAnswers, hideResults, allowBack, certificateEnabled,
        questions,
      };
      return olympiadsApi.create(payload);
    },
    onSuccess: () => {
      toast.success('Konkurs yaratildi (qoralama)');
      onSuccess();
      onOpenChange(false);
      reset();
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  const canNext = () => {
    if (step === 0) return title.trim().length > 0 && ageTo >= ageFrom;
    if (step === 1) return durationMin >= 5 && durationMin <= 300;
    if (step === 2)
      return (
        questions.length > 0 &&
        questions.every(
          (q) =>
            q.text.trim().length > 0 &&
            q.options.length >= 2 &&
            // Har variant MATN yoki RASM bilan to'ldirilgan bo'lishi kerak.
            q.options.every(
              (o, oi) =>
                o.trim().length > 0 || (q.optionImages?.[oi] ?? '').length > 0,
            ) &&
            q.correctIndex >= 0 &&
            q.correctIndex < q.options.length,
        )
      );
    return true;
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Yangi konkurs</DialogTitle>
        </DialogHeader>

        {/* Stepper */}
        <div className="flex items-center gap-2">
          {STEPS.map((label, i) => (
            <div key={label} className="flex flex-1 items-center gap-2">
              <div
                className={cn(
                  'flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs font-bold transition-colors',
                  i < step ? 'bg-primary text-primary-foreground'
                    : i === step ? 'bg-primary text-primary-foreground ring-4 ring-primary/20'
                      : 'bg-muted text-muted-foreground',
                )}
              >
                {i < step ? <Check className="h-3.5 w-3.5" /> : i + 1}
              </div>
              <span className={cn('hidden text-xs font-medium sm:inline', i === step ? 'text-foreground' : 'text-muted-foreground')}>
                {label}
              </span>
              {i < STEPS.length - 1 && <div className="h-px flex-1 bg-border" />}
            </div>
          ))}
        </div>

        <div className="max-h-[55vh] overflow-y-auto px-0.5 py-2">
          {step === 0 && (
            <div className="space-y-4">
              <Field label="Konkurs nomi">
                <Input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={120} />
              </Field>
              <Field label="Tavsif">
                <Textarea value={description} onChange={(e) => setDescription(e.target.value)} maxLength={500} />
              </Field>
              <Field label="Banner rasmi (ixtiyoriy)">
                <input
                  type="file"
                  accept="image/*"
                  id="olympiad-cover"
                  className="hidden"
                  onChange={(e) => {
                    void handleCoverImage(e.target.files?.[0]);
                    e.target.value = '';
                  }}
                />
                {coverKey ? (
                  <div className="relative inline-block w-full">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={questionImageUrl(coverKey)}
                      alt="Banner"
                      className="max-h-40 w-full rounded-lg border border-border object-cover"
                    />
                    <button
                      type="button"
                      onClick={() => setCoverKey(null)}
                      className="absolute -right-2 -top-2 rounded-full bg-destructive p-1 text-white shadow-soft"
                      title="Bannerni o'chirish"
                    >
                      <X className="h-3.5 w-3.5" />
                    </button>
                  </div>
                ) : uploadingCover ? (
                  <div className="flex items-center gap-2 text-sm text-muted-foreground">
                    <Loader2 className="h-4 w-4 animate-spin" /> Banner yuklanmoqda...
                  </div>
                ) : (
                  <label
                    htmlFor="olympiad-cover"
                    className="flex cursor-pointer items-center justify-center gap-2 rounded-lg border border-dashed border-border px-3 py-6 text-sm text-muted-foreground transition-colors hover:border-primary hover:text-primary"
                  >
                    <ImagePlus className="h-4 w-4" /> Banner yuklash (ixtiyoriy)
                  </label>
                )}
                <p className="mt-1 text-xs text-muted-foreground">
                  Bola dashboard&apos;idagi test karuselida ko&apos;rinadi. Bo&apos;sh qoldirilsa fan ikonkasi ishlatiladi.
                </p>
              </Field>
              <Field label="Fan">
                <Select value={subject} onValueChange={setSubject}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>{SUBJECTS.map((s) => <SelectItem key={s} value={s}>{s}</SelectItem>)}</SelectContent>
                </Select>
              </Field>
              <div className="grid grid-cols-2 gap-4">
                <Field label="Yosh (dan)">
                  <Input type="number" min={0} max={25} value={ageFrom} onChange={(e) => setAgeFrom(+e.target.value)} />
                </Field>
                <Field label="Yosh (gacha)">
                  <Input type="number" min={0} max={25} value={ageTo} onChange={(e) => setAgeTo(+e.target.value)} />
                </Field>
              </div>
            </div>
          )}

          {step === 1 && (
            <div className="space-y-4">
              <Field label="Davomiyligi (daqiqa)">
                <Input type="number" min={5} max={300} value={durationMin} onChange={(e) => setDurationMin(+e.target.value)} />
              </Field>
              <p className="rounded-lg bg-muted/50 p-3 text-sm text-muted-foreground">
                Davomiylik — bola boshlagandan keyin savollarga javob berish uchun
                vaqt chegarasi. Konkurs nashr qilingach DARHOL ochiq bo'ladi va
                30 kun davomida qatnashish mumkin (vaqtni keyin tahrirlashingiz mumkin).
              </p>
            </div>
          )}

          {step === 2 && (
            <div className="space-y-4">
              {questions.map((q, qi) => (
                <div key={qi} className="rounded-xl border border-border p-4">
                  <div className="mb-3 flex items-center justify-between">
                    <span className="text-sm font-semibold">Savol {qi + 1}</span>
                    {questions.length > 1 && (
                      <Button variant="ghost" size="icon-sm" onClick={() => setQuestions((qs) => qs.filter((_, i) => i !== qi))}>
                        <Trash2 className="h-4 w-4 text-destructive" />
                      </Button>
                    )}
                  </div>
                  <Textarea
                    placeholder="Savol matni"
                    value={q.text}
                    onChange={(e) => setQuestions((qs) => qs.map((x, i) => i === qi ? { ...x, text: e.target.value } : x))}
                    className="mb-3"
                  />

                  {/* Savol rasmi (ixtiyoriy) — matematik funksiyalar kabi
                      yozib bo'lmaydigan savollar uchun. Avtomatik MinIO. */}
                  <div className="mb-3">
                    <input
                      type="file"
                      accept="image/*"
                      id={`q-img-${qi}`}
                      className="hidden"
                      onChange={(e) => {
                        void handleQuestionImage(qi, e.target.files?.[0]);
                        e.target.value = '';
                      }}
                    />
                    {q.imageKey ? (
                      <div className="relative inline-block">
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img
                          src={questionImageUrl(q.imageKey)}
                          alt="Savol rasmi"
                          className="max-h-44 rounded-lg border border-border object-contain"
                        />
                        <button
                          type="button"
                          onClick={() => setQuestions((qs) => qs.map((x, i) => i === qi ? { ...x, imageKey: null } : x))}
                          className="absolute -right-2 -top-2 rounded-full bg-destructive p-1 text-white shadow-soft"
                          title="Rasmni o'chirish"
                        >
                          <X className="h-3.5 w-3.5" />
                        </button>
                      </div>
                    ) : uploadingIdx === qi ? (
                      <div className="flex items-center gap-2 text-sm text-muted-foreground">
                        <Loader2 className="h-4 w-4 animate-spin" /> Rasm yuklanmoqda...
                      </div>
                    ) : (
                      <label
                        htmlFor={`q-img-${qi}`}
                        className="inline-flex cursor-pointer items-center gap-2 rounded-lg border border-dashed border-border px-3 py-2 text-sm text-muted-foreground transition-colors hover:border-primary hover:text-primary"
                      >
                        <ImagePlus className="h-4 w-4" /> Rasm yuklash (ixtiyoriy)
                      </label>
                    )}
                  </div>

                  <div className="space-y-2">
                    {q.options.map((opt, oi) => {
                      const optImg = q.optionImages?.[oi] ?? '';
                      return (
                        <div key={oi} className="flex items-center gap-2">
                          <button
                            type="button"
                            onClick={() => setQuestions((qs) => qs.map((x, i) => i === qi ? { ...x, correctIndex: oi } : x))}
                            className={cn(
                              'flex h-6 w-6 shrink-0 items-center justify-center rounded-full border-2 text-xs font-bold transition-colors',
                              q.correctIndex === oi ? 'border-success bg-success text-success-foreground' : 'border-border text-muted-foreground',
                            )}
                            title="To'g'ri javob"
                          >
                            {q.correctIndex === oi ? <Check className="h-3.5 w-3.5" /> : String.fromCharCode(65 + oi)}
                          </button>
                          <Input
                            placeholder={optImg ? '(rasm) — matn ixtiyoriy' : `Variant ${String.fromCharCode(65 + oi)}`}
                            value={opt}
                            onChange={(e) => setQuestions((qs) => qs.map((x, i) => i === qi
                              ? { ...x, options: x.options.map((o, j) => j === oi ? e.target.value : o) } : x))}
                          />
                          {/* Variantga IXTIYORIY rasm (matematik javob) */}
                          <input
                            type="file"
                            accept="image/*"
                            id={`q-${qi}-opt-${oi}`}
                            className="hidden"
                            onChange={(e) => {
                              void handleOptionImage(qi, oi, e.target.files?.[0]);
                              e.target.value = '';
                            }}
                          />
                          {optImg ? (
                            <div className="relative shrink-0">
                              {/* eslint-disable-next-line @next/next/no-img-element */}
                              <img
                                src={questionImageUrl(optImg)}
                                alt="Variant rasmi"
                                className="h-9 w-9 rounded border border-border object-cover"
                              />
                              <button
                                type="button"
                                title="Rasmni o'chirish"
                                onClick={() => setQuestions((qs) => qs.map((x, i) => i === qi
                                  ? { ...x, optionImages: (x.optionImages ?? x.options.map(() => '')).map((v, j) => j === oi ? '' : v) } : x))}
                                className="absolute -right-1.5 -top-1.5 rounded-full bg-destructive p-0.5 text-white"
                              >
                                <X className="h-3 w-3" />
                              </button>
                            </div>
                          ) : uploadingOpt === `${qi}-${oi}` ? (
                            <Loader2 className="h-4 w-4 shrink-0 animate-spin text-muted-foreground" />
                          ) : (
                            <label
                              htmlFor={`q-${qi}-opt-${oi}`}
                              title="Variantga rasm (ixtiyoriy)"
                              className="flex h-9 w-9 shrink-0 cursor-pointer items-center justify-center rounded border border-dashed border-border text-muted-foreground transition-colors hover:border-primary hover:text-primary"
                            >
                              <ImagePlus className="h-4 w-4" />
                            </label>
                          )}
                        </div>
                      );
                    })}
                  </div>
                  <div className="mt-3 flex items-center gap-2">
                    <Label className="text-xs">Ball:</Label>
                    <Input
                      type="number" min={1} max={100} value={q.points}
                      onChange={(e) => setQuestions((qs) => qs.map((x, i) => i === qi ? { ...x, points: +e.target.value } : x))}
                      className="h-8 w-20"
                    />
                  </div>
                </div>
              ))}
              <Button variant="outline" onClick={() => setQuestions((qs) => [...qs, emptyQuestion()])} className="w-full">
                <Plus className="h-4 w-4" /> Savol qo&apos;shish
              </Button>
            </div>
          )}

          {step === 3 && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <Field label="Turi">
                  <Select value={type} onValueChange={setType}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="test">Test</SelectItem>
                      <SelectItem value="creative">Ijodiy</SelectItem>
                      <SelectItem value="mixed">Aralash</SelectItem>
                    </SelectContent>
                  </Select>
                </Field>
                <Field label="Qiyinligi">
                  <Select value={difficulty} onValueChange={setDifficulty}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="oson">Oson</SelectItem>
                      <SelectItem value="o'rta">O&apos;rta</SelectItem>
                      <SelectItem value="qiyin">Qiyin</SelectItem>
                    </SelectContent>
                  </Select>
                </Field>
                <Field label="DON mukofoti">
                  <Input type="number" min={0} max={1000} value={xpReward} onChange={(e) => setXpReward(+e.target.value)} />
                </Field>
              </div>
              <div className="space-y-3 rounded-xl border border-border p-4">
                <Toggle label="Savollarni aralashtirish" checked={shuffleQuestions} onChange={setShuffleQuestions} />
                <Toggle label="Javoblarni aralashtirish" checked={shuffleAnswers} onChange={setShuffleAnswers} />
                <Toggle label="Natijalarni yashirish" checked={hideResults} onChange={setHideResults} />
                <Toggle label="Orqaga qaytishga ruxsat" checked={allowBack} onChange={setAllowBack} />
                <Toggle label="Sertifikat berish" checked={certificateEnabled} onChange={setCertificateEnabled} />
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between border-t border-border pt-4">
          <Button variant="ghost" onClick={() => (step === 0 ? onOpenChange(false) : setStep((s) => s - 1))}>
            {step === 0 ? 'Bekor' : <><ChevronLeft className="h-4 w-4" /> Orqaga</>}
          </Button>
          {step < STEPS.length - 1 ? (
            <Button onClick={() => canNext() ? setStep((s) => s + 1) : toast.error('Maydonlarni to\'ldiring')}>
              Keyingi <ChevronRight className="h-4 w-4" />
            </Button>
          ) : (
            <Button onClick={() => create.mutate()} disabled={create.isPending}>
              {create.isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Check className="h-4 w-4" />}
              Yaratish
            </Button>
          )}
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

function Toggle({ label, checked, onChange }: { label: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-sm">{label}</span>
      <Switch checked={checked} onCheckedChange={onChange} />
    </div>
  );
}
