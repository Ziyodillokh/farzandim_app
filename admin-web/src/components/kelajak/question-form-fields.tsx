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
  KELAJAK_AGE_GROUPS,
  KELAJAK_ANSWER_TYPES,
  KELAJAK_CATEGORIES,
  KELAJAK_LIMITS,
  TEXT_ANSWER_TYPE,
} from '@/lib/constants/kelajak';
import { cn } from '@/lib/utils';
import { OptionsEditor } from './options-editor';
import {
  withAnswerType,
  withCategory,
  type FormErrors,
  type FormMode,
  type QuestionForm,
  type TextDraft,
} from './question-form';
import { scoringTagSpec } from './question-scoring';

/** Radix Select bo'sh qiymatni qabul qilmaydi — "kodsiz" tanlovi shu belgi bilan. */
const EMPTY_TAG = '__none__';

/** Xato matni boshqaruv elementiga bog'lanadi (ekran o'quvchi uchun). */
const errorId = (id: string) => `${id}-error`;
const invalidProps = (id: string, error?: string) =>
  error ? { 'aria-invalid': true as const, 'aria-describedby': errorId(id) } : {};

/** Yaratish va tahrirlash dialoglari uchun umumiy forma maydonlari. */
export function QuestionFormFields({
  form,
  setForm,
  errors,
  mode,
  locked,
}: {
  form: QuestionForm;
  setForm: Dispatch<SetStateAction<QuestionForm>>;
  /** Faqat ko'rsatiladigan xatolar (birinchi saqlash urinishidan keyin). */
  errors: FormErrors;
  mode: FormMode;
  /** `answerCount > 0` — bloklanadigan maydonlar o'chiq. */
  locked: boolean;
}) {
  const patch = (p: Partial<QuestionForm>) => setForm((prev) => ({ ...prev, ...p }));
  const patchText = (lang: keyof TextDraft, value: string) =>
    setForm((prev) => ({ ...prev, text: { ...prev.text, [lang]: value } }));
  const isText = form.answerType === TEXT_ANSWER_TYPE;
  const tagSpec = isText ? null : scoringTagSpec(form.category);

  return (
    <div className="space-y-6">
      <Section title="Savol matni">
        <Field label="O'zbekcha" htmlFor="kq-text-uz" error={errors.text}
          hint={`${form.text.uz.trim().length}/${KELAJAK_LIMITS.textMax}`}>
          <Textarea id="kq-text-uz" rows={3} value={form.text.uz} maxLength={KELAJAK_LIMITS.textMax}
            {...invalidProps('kq-text-uz', errors.text)}
            onChange={(e) => patchText('uz', e.target.value)} />
        </Field>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <Field label="Ruscha (ixtiyoriy)" htmlFor="kq-text-ru">
            <Textarea id="kq-text-ru" rows={2} value={form.text.ru} maxLength={KELAJAK_LIMITS.textMax}
              onChange={(e) => patchText('ru', e.target.value)} />
          </Field>
          <Field label="Inglizcha (ixtiyoriy)" htmlFor="kq-text-en">
            <Textarea id="kq-text-en" rows={2} value={form.text.en} maxLength={KELAJAK_LIMITS.textMax}
              onChange={(e) => patchText('en', e.target.value)} />
          </Field>
        </div>
      </Section>

      <Section title="Tasnif">
        {mode === 'create' && (
          <Field label="Tashqi ID (ixtiyoriy)" htmlFor="kq-external-id" error={errors.externalId}
            hint="Bo'sh qolsa avtomatik: ADMIN-…">
            <Input id="kq-external-id" value={form.externalId} maxLength={40} placeholder="ADMIN-…"
              className="font-mono uppercase" {...invalidProps('kq-external-id', errors.externalId)}
              onChange={(e) => patch({ externalId: e.target.value.toUpperCase() })} />
          </Field>
        )}
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          <Field label="Kategoriya" htmlFor="kq-category" error={errors.category} locked={locked}>
            <Select value={form.category} onValueChange={(v) => setForm((prev) => withCategory(prev, v))}
              disabled={locked}>
              <SelectTrigger id="kq-category" {...invalidProps('kq-category', errors.category)}>
                <SelectValue placeholder="Tanlang" />
              </SelectTrigger>
              <SelectContent>
                {KELAJAK_CATEGORIES.map((c) => <SelectItem key={c.value} value={c.value}>{c.label}</SelectItem>)}
              </SelectContent>
            </Select>
          </Field>
          <Field label="Yosh guruhi" htmlFor="kq-age-group" error={errors.ageGroup} locked={locked}>
            <Select value={form.ageGroup} onValueChange={(v) => patch({ ageGroup: v })} disabled={locked}>
              <SelectTrigger id="kq-age-group" {...invalidProps('kq-age-group', errors.ageGroup)}>
                <SelectValue placeholder="Tanlang" />
              </SelectTrigger>
              <SelectContent>
                {KELAJAK_AGE_GROUPS.map((g) => <SelectItem key={g.value} value={g.value}>{g.label}</SelectItem>)}
              </SelectContent>
            </Select>
          </Field>
          <Field label="Javob turi" htmlFor="kq-answer-type" error={errors.answerType} locked={locked}>
            <Select value={form.answerType} disabled={locked}
              onValueChange={(v) => setForm((prev) => withAnswerType(prev, v))}>
              <SelectTrigger id="kq-answer-type" {...invalidProps('kq-answer-type', errors.answerType)}>
                <SelectValue placeholder="Tanlang" />
              </SelectTrigger>
              <SelectContent>
                {KELAJAK_ANSWER_TYPES.map((t) => <SelectItem key={t.value} value={t.value}>{t.label}</SelectItem>)}
              </SelectContent>
            </Select>
          </Field>
        </div>
        {tagSpec && (
          <Field label={tagSpec.label} htmlFor="kq-scoring-tag" error={errors.scoringTag} locked={locked}
            hint={tagSpec.hint}>
            <Select value={form.scoringTag || (tagSpec.emptyLabel ? EMPTY_TAG : '')} disabled={locked}
              onValueChange={(v) => patch({ scoringTag: v === EMPTY_TAG ? '' : v })}>
              <SelectTrigger id="kq-scoring-tag" {...invalidProps('kq-scoring-tag', errors.scoringTag)}>
                <SelectValue placeholder="Tanlang" />
              </SelectTrigger>
              <SelectContent>
                {tagSpec.emptyLabel && <SelectItem value={EMPTY_TAG}>{tagSpec.emptyLabel}</SelectItem>}
                {tagSpec.options.map((o) => <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>)}
              </SelectContent>
            </Select>
          </Field>
        )}
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <ToggleRow id="kq-required" label="Majburiy" checked={!isText && form.required}
            description={isText ? 'Ochiq javob har doim ixtiyoriy' : "O'tkazib yuborib bo'lmaydi"}
            disabled={isText} onChange={(v) => patch({ required: v })} />
          <ToggleRow id="kq-reverse" label="Teskari ball" checked={form.reverse} locked={locked}
            description="Yuqori qiymat = tashvish"
            disabled={locked || isText} onChange={(v) => patch({ reverse: v })} />
          <ToggleRow id="kq-active" label="Faol" checked={form.active}
            description="Bolalarga beriladi"
            onChange={(v) => patch({ active: v })} />
        </div>
      </Section>

      <Section title="Javob variantlari" locked={locked} error={errors.options} errorId={errorId('kq-options')}>
        <OptionsEditor answerType={form.answerType} options={form.options} disabled={locked}
          onChange={(options) => patch({ options })} />
      </Section>

      <Section title="Qo'shimcha">
        <Field label="Ichki izoh: keyingi qadam (bolaga ko'rsatilmaydi)" htmlFor="kq-follow-up" error={errors.followUp}>
          <Input id="kq-follow-up" value={form.followUp} maxLength={KELAJAK_LIMITS.followUpMax}
            {...invalidProps('kq-follow-up', errors.followUp)}
            onChange={(e) => patch({ followUp: e.target.value })} />
        </Field>
        <Field label="Izoh" htmlFor="kq-notes" error={errors.notes}>
          <Textarea id="kq-notes" rows={2} value={form.notes} maxLength={KELAJAK_LIMITS.noteMax}
            {...invalidProps('kq-notes', errors.notes)}
            onChange={(e) => patch({ notes: e.target.value })} />
        </Field>
        <Field label="Ko'rib chiqish izohi" htmlFor="kq-review-note" error={errors.reviewNote}
          hint="Mazmun egasi uchun: savolni nega qayta ko'rib chiqish kerak">
          <Textarea id="kq-review-note" rows={2} value={form.reviewNote} maxLength={KELAJAK_LIMITS.noteMax}
            {...invalidProps('kq-review-note', errors.reviewNote)}
            onChange={(e) => patch({ reviewNote: e.target.value })} />
        </Field>
      </Section>
    </div>
  );
}

/* ─── Yordamchi bloklar ─── */

function LockMark({ className }: { className?: string }) {
  return (
    <span role="img" aria-label="Bloklangan" className="inline-flex">
      <Lock className={cn('h-3 w-3', className)} aria-hidden />
    </span>
  );
}

function Section({ title, locked, error, errorId: id, children }: {
  title: string; locked?: boolean; error?: string; errorId?: string; children: ReactNode;
}) {
  return (
    <section className="space-y-3">
      <h3 className="flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
        {title}
        {locked && <LockMark />}
      </h3>
      {children}
      {error && <p id={id} role="alert" className="text-xs text-destructive">{error}</p>}
    </section>
  );
}

function Field({ label, htmlFor, error, hint, locked, children }: {
  label: string; htmlFor?: string; error?: string; hint?: string; locked?: boolean; children: ReactNode;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex items-center justify-between gap-2">
        <Label htmlFor={htmlFor} className="flex items-center gap-1.5">
          {label}
          {locked && <LockMark className="text-muted-foreground" />}
        </Label>
        {hint && <span className="text-2xs text-muted-foreground">{hint}</span>}
      </div>
      {children}
      {error && (
        <p id={htmlFor ? errorId(htmlFor) : undefined} className="text-xs text-destructive">{error}</p>
      )}
    </div>
  );
}

function ToggleRow({ id, label, description, checked, onChange, disabled, locked }: {
  id: string; label: string; description: string; checked: boolean;
  onChange: (v: boolean) => void; disabled?: boolean; locked?: boolean;
}) {
  return (
    <div className={cn('flex items-center justify-between gap-3 rounded-lg border border-border px-3 py-2.5',
      disabled && 'opacity-60')}>
      <div className="min-w-0">
        <Label htmlFor={id} className="flex items-center gap-1.5">
          {label}
          {locked && <LockMark className="text-muted-foreground" />}
        </Label>
        <p id={`${id}-description`} className="mt-0.5 text-2xs text-muted-foreground">{description}</p>
      </div>
      <Switch id={id} checked={checked} onCheckedChange={onChange} disabled={disabled}
        aria-describedby={`${id}-description`} />
    </div>
  );
}
