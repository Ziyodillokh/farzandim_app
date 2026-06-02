'use client';

import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Check, ChevronLeft, ChevronRight, Plus, Trash2, Loader2 } from 'lucide-react';
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

function emptyQuestion(): OlympiadQuestionInput {
  return { text: '', options: ['', '', '', ''], correctIndex: 0, points: 10 };
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

  // Step 1
  const [durationMin, setDurationMin] = useState(30);

  // Step 2
  const [questions, setQuestions] = useState<OlympiadQuestionInput[]>([emptyQuestion()]);

  // Step 3
  const [type, setType] = useState('test');
  const [difficulty, setDifficulty] = useState("o'rta");
  const [maxAttempts, setMaxAttempts] = useState(1);
  const [xpReward, setXpReward] = useState(50);
  const [shuffleQuestions, setShuffleQuestions] = useState(true);
  const [shuffleAnswers, setShuffleAnswers] = useState(true);
  const [hideResults, setHideResults] = useState(false);
  const [allowBack, setAllowBack] = useState(true);
  const [certificateEnabled, setCertificateEnabled] = useState(true);

  const reset = () => {
    setStep(0); setTitle("Iste'dod Uchquni"); setDescription(''); setSubject('Matematika');
    setAgeFrom(9); setAgeTo(12); setDurationMin(30); setQuestions([emptyQuestion()]);
    setType('test'); setDifficulty("o'rta"); setMaxAttempts(1); setXpReward(50);
    setShuffleQuestions(true); setShuffleAnswers(true); setHideResults(false);
    setAllowBack(true); setCertificateEnabled(true);
  };

  const create = useMutation({
    mutationFn: () => {
      const now = new Date();
      const start = new Date(now.getTime() + 24 * 60 * 60 * 1000);
      const end = new Date(start.getTime() + durationMin * 60 * 1000);
      const payload: OlympiadCreatePayload = {
        title, description, subject, ageFrom, ageTo, type, difficulty,
        startTime: start.toISOString(), endTime: end.toISOString(),
        durationMin, maxAttempts, xpReward,
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
    if (step === 2) return questions.every((q) => q.text.trim() && q.options.every((o) => o.trim()));
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
              <Field label="Fan">
                <Select value={subject} onValueChange={setSubject}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>{SUBJECTS.map((s) => <SelectItem key={s} value={s}>{s}</SelectItem>)}</SelectContent>
                </Select>
              </Field>
              <div className="grid grid-cols-2 gap-4">
                <Field label="Yosh (dan)">
                  <Input type="number" min={3} max={18} value={ageFrom} onChange={(e) => setAgeFrom(+e.target.value)} />
                </Field>
                <Field label="Yosh (gacha)">
                  <Input type="number" min={3} max={18} value={ageTo} onChange={(e) => setAgeTo(+e.target.value)} />
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
                Boshlanish vaqti avtomatik ertangi kunga, tugash vaqti davomiylik asosida belgilanadi.
                Keyinroq tahrirlashingiz mumkin.
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
                  <div className="space-y-2">
                    {q.options.map((opt, oi) => (
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
                          placeholder={`Variant ${String.fromCharCode(65 + oi)}`}
                          value={opt}
                          onChange={(e) => setQuestions((qs) => qs.map((x, i) => i === qi
                            ? { ...x, options: x.options.map((o, j) => j === oi ? e.target.value : o) } : x))}
                        />
                      </div>
                    ))}
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
                <Field label="Urinishlar soni">
                  <Input type="number" min={1} max={10} value={maxAttempts} onChange={(e) => setMaxAttempts(+e.target.value)} />
                </Field>
                <Field label="XP mukofoti">
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
