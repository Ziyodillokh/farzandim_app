'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { useEffect } from 'react';
import { Controller, useForm } from 'react-hook-form';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Switch } from '@/components/ui/switch';
import { Textarea } from '@/components/ui/textarea';
import type { AgeGroup, CareQuestion } from '@/data/contracts';
import { AGE_GROUPS, CARE_TOPICS, careQuestionInputSchema, type CareQuestionInput } from '@/data/schemas/care';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useCreateQuestion, useUpdateQuestion } from '../hooks';

const EMPTY: CareQuestionInput = { text: { uz: '', ru: '' }, topic: 'WELLBEING', ageGroups: [...AGE_GROUPS], reverse: false, active: true };

function ToggleRow({ label, hint, checked, onChange }: { label: string; hint: string; checked: boolean; onChange: (value: boolean) => void }) {
  return (
    <label className="flex cursor-pointer items-start justify-between gap-4 rounded-lg border p-3">
      <span>
        <span className="block text-sm font-medium">{label}</span>
        <span className="mt-0.5 block text-xs text-muted-foreground">{hint}</span>
      </span>
      <Switch checked={checked} onCheckedChange={onChange} aria-label={label} />
    </label>
  );
}

/** Savollar banki: yangi savol yoki tahrirlash (matn uz/ru, mavzu, yosh, teskari, faol). */
export function QuestionFormDialog({ open, onOpenChange, question }: { open: boolean; onOpenChange: (open: boolean) => void; question?: CareQuestion }) {
  const { t } = useI18n();
  const create = useCreateQuestion();
  const update = useUpdateQuestion();
  const form = useForm<CareQuestionInput>({ resolver: zodResolver(careQuestionInputSchema), defaultValues: EMPTY });

  useEffect(() => {
    if (!open) return;
    form.reset(
      question
        ? { text: { ...question.text }, topic: question.topic, ageGroups: question.ageGroups, reverse: question.reverse, active: question.active }
        : EMPTY,
    );
  }, [open, question, form]);

  const submit = form.handleSubmit((values) => {
    const done = { onSuccess: () => onOpenChange(false) };
    if (question) update.mutate({ id: question.id, input: values }, done);
    else create.mutate(values, done);
  });

  const { errors } = form.formState;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>{question ? t('care.questions.editTitle') : t('care.questions.createTitle')}</DialogTitle>
          <DialogDescription>{t('care.questions.scaleHint')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4" noValidate>
          <FormField label={t('care.questions.fields.textUz')} htmlFor="q-uz" error={errors.text?.uz}>
            <Textarea id="q-uz" rows={2} {...form.register('text.uz')} />
          </FormField>
          <FormField label={t('care.questions.fields.textRu')} htmlFor="q-ru" error={errors.text?.ru}>
            <Textarea id="q-ru" rows={2} lang="ru" {...form.register('text.ru')} />
          </FormField>
          <FormField label={t('care.questions.fields.topic')}>
            <Controller
              control={form.control}
              name="topic"
              render={({ field }) => (
                <Select value={field.value} onValueChange={field.onChange}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {CARE_TOPICS.map((x) => (
                      <SelectItem key={x} value={x}>{t(`enums.careTopic.${x}`)}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
          </FormField>
          <FormField label={t('care.questions.fields.ageGroups')} error={errors.ageGroups}>
            <Controller
              control={form.control}
              name="ageGroups"
              render={({ field }) => (
                <div className="flex flex-wrap gap-2">
                  {AGE_GROUPS.map((g) => {
                    const checked = field.value.includes(g);
                    return (
                      <label key={g} className={cn('flex cursor-pointer items-center gap-2 rounded-lg border px-3 py-2 text-sm', checked && 'border-primary/40 bg-primary/[0.05]')}>
                        <Checkbox
                          checked={checked}
                          onCheckedChange={(on) => field.onChange((on === true ? [...field.value, g] : field.value.filter((x) => x !== g)) as AgeGroup[])}
                        />
                        {t(`enums.ageGroup.${g}`)}
                      </label>
                    );
                  })}
                </div>
              )}
            />
          </FormField>
          <Controller
            control={form.control}
            name="reverse"
            render={({ field }) => (
              <ToggleRow label={t('care.questions.fields.reverse')} hint={t('care.questions.fields.reverseHint')} checked={field.value} onChange={field.onChange} />
            )}
          />
          <Controller
            control={form.control}
            name="active"
            render={({ field }) => (
              <ToggleRow label={t('care.questions.fields.active')} hint={t('care.questions.fields.activeHint')} checked={field.value} onChange={field.onChange} />
            )}
          />
          <DialogFooter className="mt-2">
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" loading={create.isPending || update.isPending}>
              {t('common.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
