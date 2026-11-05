'use client';

import type { Dispatch, ReactNode, SetStateAction } from 'react';
import { Lock } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { Textarea } from '@/components/ui/textarea';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  GRADE_OPTIONS,
  LEARNING_SUBJECTS,
  MIN_TOPIC_QUESTIONS,
  TOPIC_KEY_MAX,
} from '@/lib/constants/learning';
import { cn } from '@/lib/utils';
import type { LearningSubject } from '@/types/api.types';
import {
  withKey,
  withTitleUz,
  type TextDraft,
  type TopicForm,
  type TopicFormErrors,
  type TopicFormMode,
} from './topic-form';

/** Xato matni boshqaruv elementiga bog'lanadi (ekran o'quvchi uchun). */
const errorId = (id: string) => `${id}-error`;
const invalidProps = (id: string, error?: string) =>
  error ? { 'aria-invalid': true as const, 'aria-describedby': errorId(id) } : {};

/** Xatoli boshqaruv elementi qizil chegara oladi (`aria-invalid` orqali). */
const INVALID_STYLE = 'aria-[invalid=true]:border-destructive';

const GOAL_HINT = 'Bola mavzu sahifasida koʻradigan oʻquv maqsadi';

/** Yaratish va tahrirlash dialogi uchun umumiy forma maydonlari. */
export function TopicFormFields({
  form,
  setForm,
  errors,
  mode,
}: {
  form: TopicForm;
  setForm: Dispatch<SetStateAction<TopicForm>>;
  /** Faqat ko'rsatiladigan xatolar (birinchi saqlash urinishidan keyin + server xatosi). */
  errors: TopicFormErrors;
  mode: TopicFormMode;
}) {
  const patch = (p: Partial<TopicForm>) => setForm((prev) => ({ ...prev, ...p }));
  const patchText = (field: 'title' | 'goal', lang: keyof TextDraft, value: string) =>
    setForm((prev) => ({ ...prev, [field]: { ...prev[field], [lang]: value } }));
  const isEdit = mode === 'edit';

  return (
    <div className="space-y-6">
      <Section title="Mavzu nomi">
        <Field label="Fan" htmlFor="lt-subject" error={errors.subject} locked={isEdit}
          hint={isEdit ? "Fan keyin o'zgarmaydi" : undefined}>
          <Select value={form.subject} disabled={isEdit}
            onValueChange={(v) => patch({ subject: v as LearningSubject })}>
            <SelectTrigger id="lt-subject" className={INVALID_STYLE}
              {...invalidProps('lt-subject', errors.subject)}>
              <SelectValue placeholder="Tanlang" />
            </SelectTrigger>
            <SelectContent>
              {LEARNING_SUBJECTS.map((s) => (
                <SelectItem key={s.value} value={s.value}>{s.label}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </Field>
        <Field label="O'zbekcha" htmlFor="lt-title-uz" error={errors.title}>
          <Input id="lt-title-uz" value={form.title.uz} placeholder="Masalan, Oddiy kasrlar"
            className={INVALID_STYLE}
            {...invalidProps('lt-title-uz', errors.title)}
            onChange={(e) => setForm((prev) => withTitleUz(prev, e.target.value))} />
        </Field>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <Field label="Ruscha (ixtiyoriy)" htmlFor="lt-title-ru">
            <Input id="lt-title-ru" value={form.title.ru}
              onChange={(e) => patchText('title', 'ru', e.target.value)} />
          </Field>
          <Field label="Inglizcha (ixtiyoriy)" htmlFor="lt-title-en">
            <Input id="lt-title-en" value={form.title.en}
              onChange={(e) => patchText('title', 'en', e.target.value)} />
          </Field>
        </div>
        <Field label="Kalit" htmlFor="lt-key" error={errors.key}
          hint={`${form.key.length}/${TOPIC_KEY_MAX}`}>
          <Input id="lt-key" value={form.key} maxLength={TOPIC_KEY_MAX} autoComplete="off"
            spellCheck={false} className={cn('font-mono', INVALID_STYLE)}
            aria-describedby={errors.key ? errorId('lt-key') : 'lt-key-help'}
            aria-invalid={errors.key ? true : undefined}
            onChange={(e) => setForm((prev) => withKey(prev, e.target.value, mode))} />
          <p id="lt-key-help" className="text-2xs text-muted-foreground">
            {form.keyTouched
              ? isEdit
                ? "Mavzuning barqaror identifikatori — faqat zarur bo'lsa o'zgartiring."
                : "Qo'lda kiritildi. Maydonni bo'sh qoldirsangiz, nomdan avtomatik tuziladi."
              : "O'zbekcha nomdan avtomatik tuzildi — kerak bo'lsa o'zgartiring."}
          </p>
        </Field>
      </Section>

      <Section title="O'quv maqsadi (ixtiyoriy)">
        <p className="-mt-1 text-xs text-muted-foreground">{GOAL_HINT}.</p>
        <Field label="O'zbekcha" htmlFor="lt-goal-uz">
          <Textarea id="lt-goal-uz" rows={2} value={form.goal.uz}
            onChange={(e) => patchText('goal', 'uz', e.target.value)} />
        </Field>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <Field label="Ruscha" htmlFor="lt-goal-ru">
            <Textarea id="lt-goal-ru" rows={2} value={form.goal.ru}
              onChange={(e) => patchText('goal', 'ru', e.target.value)} />
          </Field>
          <Field label="Inglizcha" htmlFor="lt-goal-en">
            <Textarea id="lt-goal-en" rows={2} value={form.goal.en}
              onChange={(e) => patchText('goal', 'en', e.target.value)} />
          </Field>
        </div>
      </Section>

      <Section title="Sinflar va holat">
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <GradeField id="lt-min-grade" label="Boshlang'ich sinf" value={form.minGrade}
            error={errors.minGrade} onChange={(v) => patch({ minGrade: v })} />
          <GradeField id="lt-max-grade" label="Yuqori sinf" value={form.maxGrade}
            error={errors.maxGrade} onChange={(v) => patch({ maxGrade: v })} />
        </div>
        <div className="flex items-center justify-between gap-3 rounded-lg border border-border px-3 py-2.5">
          <div className="min-w-0">
            <Label htmlFor="lt-status">Bolalarga ko&apos;rsatish</Label>
            <p id="lt-status-description" className="mt-0.5 text-2xs text-muted-foreground">
              Mavzu kamida {MIN_TOPIC_QUESTIONS} ta faol savol to&apos;plagandan keyingina bolaga
              taklif qilinadi. Yashirilsa, ilovada umuman ko&apos;rinmaydi.
            </p>
          </div>
          <Switch id="lt-status" checked={form.status === 'ACTIVE'}
            aria-describedby="lt-status-description"
            onCheckedChange={(on) => patch({ status: on ? 'ACTIVE' : 'HIDDEN' })} />
        </div>
      </Section>
    </div>
  );
}

function GradeField({ id, label, value, error, onChange }: {
  id: string; label: string; value: string; error?: string; onChange: (v: string) => void;
}) {
  return (
    <Field label={label} htmlFor={id} error={error}>
      <Select value={value} onValueChange={onChange}>
        <SelectTrigger id={id} className={INVALID_STYLE} {...invalidProps(id, error)}>
          <SelectValue placeholder="Tanlang" />
        </SelectTrigger>
        <SelectContent>
          {GRADE_OPTIONS.map((g) => (
            <SelectItem key={g} value={String(g)}>{g}-sinf</SelectItem>
          ))}
        </SelectContent>
      </Select>
    </Field>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <fieldset className="space-y-4">
      <legend className="mb-1 text-sm font-semibold">{title}</legend>
      {children}
    </fieldset>
  );
}

function Field({ label, htmlFor, error, hint, locked, children }: {
  label: string; htmlFor: string; error?: string; hint?: string; locked?: boolean; children: ReactNode;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex items-center justify-between gap-2">
        <Label htmlFor={htmlFor} className="flex items-center gap-1.5">
          {label}
          {locked && <Lock className="h-3 w-3 text-muted-foreground" aria-hidden />}
        </Label>
        {hint && <span className="text-2xs text-muted-foreground">{hint}</span>}
      </div>
      {children}
      {error && (
        <p id={errorId(htmlFor)} role="alert" className="text-xs text-destructive">{error}</p>
      )}
    </div>
  );
}
