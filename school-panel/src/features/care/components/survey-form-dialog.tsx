'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { useEffect, useMemo, useState } from 'react';
import { Controller, useForm } from 'react-hook-form';

import { FormField } from '@/components/common/form-field';
import { FilterSelect } from '@/components/common/toolbar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { ScrollArea } from '@/components/ui/scroll-area';
import type { AgeGroup, CareSurvey, CareTopic } from '@/data/contracts';
import { addDays, weekStart } from '@/data/mock/calendar';
import { clockToday } from '@/data/mock/clock';
import { AGE_GROUPS, CARE_TOPICS, careSurveyInputSchema, MAX_SURVEY_QUESTIONS, type CareSurveyInput } from '@/data/schemas/care';
import { useI18n } from '@/i18n';
import { TILE } from '@/features/dashboard/lib/tile';
import { cn } from '@/lib/utils';
import { useCareQuestions, useCreateSurvey, useUpdateSurvey } from '../hooks';

const SECONDS_PER_QUESTION = 25;

function emptyValues(): CareSurveyInput {
  return { title: '', weekStart: weekStart(addDays(clockToday(), 7)), ageGroups: [...AGE_GROUPS], questionIds: [] };
}

/** Yangi so'rovnoma yoki qoralamani tahrirlash (faqat psixolog). */
export function SurveyFormDialog({ open, onOpenChange, survey }: { open: boolean; onOpenChange: (open: boolean) => void; survey?: CareSurvey }) {
  const { t, locale } = useI18n();
  const questions = useCareQuestions();
  const create = useCreateSurvey();
  const update = useUpdateSurvey();
  const [topic, setTopic] = useState<CareTopic | undefined>();
  const form = useForm<CareSurveyInput>({ resolver: zodResolver(careSurveyInputSchema), defaultValues: emptyValues() });
  const ageGroups = form.watch('ageGroups');
  const selected = form.watch('questionIds');

  useEffect(() => {
    if (!open) return;
    setTopic(undefined);
    form.reset(survey ? { title: survey.title, weekStart: survey.weekStart, ageGroups: survey.ageGroups, questionIds: survey.questionIds } : emptyValues());
  }, [open, survey, form]);

  const eligible = useMemo(
    () => (questions.data ?? []).filter((q) => q.active && q.ageGroups.some((g) => ageGroups.includes(g))),
    [questions.data, ageGroups],
  );

  // Yosh guruhi o'zgarsa — mos kelmay qolgan savollar tanlovdan olinadi.
  useEffect(() => {
    const valid = new Set(eligible.map((q) => q.id));
    const current = form.getValues('questionIds');
    if (questions.data && current.some((id) => !valid.has(id))) form.setValue('questionIds', current.filter((id) => valid.has(id)));
  }, [eligible, form, questions.data]);

  const visible = eligible.filter((q) => !topic || q.topic === topic);
  const minutes = Math.max(1, Math.round((selected.length * SECONDS_PER_QUESTION) / 60));

  const submit = form.handleSubmit((values) => {
    const done = { onSuccess: () => onOpenChange(false) };
    if (survey) update.mutate({ id: survey.id, input: values }, done);
    else create.mutate(values, done);
  });

  const toggle = (list: string[], id: string, on: boolean) => (on ? [...list, id] : list.filter((x) => x !== id));
  const { errors } = form.formState;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>{survey ? t('care.surveys.editTitle') : t('care.surveys.createTitle')}</DialogTitle>
          <DialogDescription>{t('care.surveys.consentNote')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4" noValidate>
          <div className="grid gap-4 sm:grid-cols-[1fr_180px]">
            <FormField label={t('care.surveys.fields.title')} htmlFor="survey-title" error={errors.title}>
              <Input id="survey-title" {...form.register('title')} />
            </FormField>
            <FormField label={t('care.surveys.fields.weekStart')} htmlFor="survey-week" error={errors.weekStart}>
              <Input id="survey-week" type="date" {...form.register('weekStart')} />
            </FormField>
          </div>

          <FormField label={t('care.surveys.fields.ageGroups')} error={errors.ageGroups}>
            <Controller
              control={form.control}
              name="ageGroups"
              render={({ field }) => (
                <div className="flex flex-wrap gap-2">
                  {AGE_GROUPS.map((g) => (
                    <label key={g} className={cn(TILE, 'flex cursor-pointer items-center gap-2 px-3 py-2 text-sm transition-colors', field.value.includes(g) && 'ring-primary/40 bg-primary/[0.07] dark:bg-primary/[0.12]')}>
                      <Checkbox checked={field.value.includes(g)} onCheckedChange={(on) => field.onChange(toggle(field.value, g, on === true) as AgeGroup[])} />
                      {t(`enums.ageGroup.${g}`)}
                    </label>
                  ))}
                </div>
              )}
            />
          </FormField>

          <FormField label={t('care.surveys.fields.questions')} error={errors.questionIds}>
            <div className="mb-2 flex flex-wrap items-center gap-2">
              <FilterSelect
                value={topic}
                onChange={(v) => setTopic(v as CareTopic | undefined)}
                options={CARE_TOPICS.map((x) => ({ value: x, label: t(`enums.careTopic.${x}`) }))}
                allLabel={`${t('care.surveys.fields.topicFilter')}: ${t('common.all')}`}
                className="h-9 sm:w-60"
              />
              <span className="ml-auto text-xs tabular-nums text-muted-foreground">
                {t('care.surveys.selected', { count: selected.length, max: MAX_SURVEY_QUESTIONS })} · {t('care.surveys.duration', { min: minutes })}
              </span>
            </div>
            <Controller
              control={form.control}
              name="questionIds"
              render={({ field }) => (
                <ScrollArea className={cn(TILE, 'h-64')}>
                  {visible.length === 0 ? (
                    <p className="p-6 text-center text-sm text-muted-foreground">{t('care.surveys.noQuestions')}</p>
                  ) : (
                    <ul className="divide-y divide-border/50 dark:divide-white/[0.06]">
                      {visible.map((q) => {
                        const checked = field.value.includes(q.id);
                        const full = !checked && field.value.length >= MAX_SURVEY_QUESTIONS;
                        return (
                          <li key={q.id}>
                            <label className={cn('flex cursor-pointer items-start gap-3 px-3 py-2.5 transition-colors hover:bg-primary/[0.04] dark:hover:bg-white/[0.04]', full && 'cursor-not-allowed opacity-50')}>
                              <Checkbox className="mt-0.5" checked={checked} disabled={full} onCheckedChange={(on) => field.onChange(toggle(field.value, q.id, on === true))} />
                              <span className="flex-1 text-sm">
                                {q.text[locale]}
                                <span className="mt-1 flex flex-wrap gap-1.5">
                                  <Badge variant="secondary" size="sm">{t(`enums.careTopic.${q.topic}`)}</Badge>
                                  {q.reverse && <Badge variant="outline" size="sm">{t('care.questions.reverse')}</Badge>}
                                </span>
                              </span>
                            </label>
                          </li>
                        );
                      })}
                    </ul>
                  )}
                </ScrollArea>
              )}
            />
          </FormField>

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
