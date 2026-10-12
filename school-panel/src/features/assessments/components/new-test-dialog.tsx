'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { z } from 'zod';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { msg, requiredText } from '@/data/schemas/common';
import { PSYCH_KINDS } from '@/data/schemas/assessments';
import { translate, useI18n } from '@/i18n';
import { useCreateTest } from '../hooks';
import { defaultScale } from '../lib/builder';
import { fieldMessage } from '../lib/labels';
import { GradesPicker } from './grades-picker';
import { viewHref } from './test-card';

const schema = z.object({
  titleUz: requiredText(120),
  titleRu: requiredText(120),
  kind: z.enum(PSYCH_KINDS),
  grades: z.array(z.number().int().min(1).max(11)).min(1, msg.atLeastOne),
  timeLimitMin: z.coerce.number().int().min(1).max(120),
});
type Values = z.input<typeof schema>;
const DEFAULTS: Values = { titleUz: '', titleRu: '', kind: 'CUSTOM', grades: [5, 6, 7, 8, 9], timeLimitMin: 10 };

/** "Yangi test" — qoralama yaratib, konstruktorga o'tadi. */
export function NewTestDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const router = useRouter();
  const create = useCreateTest();
  const form = useForm<Values>({ resolver: zodResolver(schema), defaultValues: DEFAULTS });
  const { errors } = form.formState;

  useEffect(() => {
    if (open) form.reset(DEFAULTS);
  }, [open, form]);

  const submit = form.handleSubmit((v) => {
    const label = { uz: translate('uz', 'assessments.newTest.defaultScale'), ru: translate('ru', 'assessments.newTest.defaultScale') };
    create.mutate(
      {
        title: { uz: v.titleUz, ru: v.titleRu },
        description: { uz: '', ru: '' },
        instructions: { uz: '', ru: '' },
        kind: v.kind,
        grades: v.grades,
        timeLimitMin: Number(v.timeLimitMin),
        scales: [defaultScale(v.kind, label)],
        items: [],
        scoring: { method: 'PER_SCALE' },
        norms: {},
      },
      {
        onSuccess: (test) => {
          onOpenChange(false);
          router.push(viewHref(test.id, 'items'));
        },
      },
    );
  });

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{t('assessments.newTest.title')}</DialogTitle>
          <DialogDescription>{t('assessments.newTest.description')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4" noValidate>
          <div className="grid gap-4 sm:grid-cols-2">
            <FormField label={t('assessments.builder.titleUz')} htmlFor="nt-title-uz" error={{ message: fieldMessage(t, errors.titleUz?.message) }}>
              <Input id="nt-title-uz" {...form.register('titleUz')} />
            </FormField>
            <FormField label={t('assessments.builder.titleRu')} htmlFor="nt-title-ru" error={{ message: fieldMessage(t, errors.titleRu?.message) }}>
              <Input id="nt-title-ru" {...form.register('titleRu')} />
            </FormField>
          </div>
          <div className="grid gap-4 sm:grid-cols-[1fr_140px]">
            <FormField label={t('assessments.builder.kind')}>
              <Controller
                control={form.control}
                name="kind"
                render={({ field }) => (
                  <Select value={field.value} onValueChange={field.onChange}>
                    <SelectTrigger aria-label={t('assessments.builder.kind')}>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {PSYCH_KINDS.map((k) => (
                        <SelectItem key={k} value={k}>
                          {t(`enums.psychKind.${k}`)}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              />
            </FormField>
            <FormField label={t('assessments.builder.timeLimit')} htmlFor="nt-time" error={{ message: fieldMessage(t, errors.timeLimitMin?.message) }}>
              <Input id="nt-time" type="number" min={1} max={120} {...form.register('timeLimitMin')} />
            </FormField>
          </div>
          <FormField label={t('assessments.builder.grades')} error={{ message: fieldMessage(t, errors.grades?.message) }}>
            <Controller control={form.control} name="grades" render={({ field }) => <GradesPicker value={field.value} onChange={field.onChange} />} />
          </FormField>
          <DialogFooter className="mt-2">
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" loading={create.isPending}>
              {t('assessments.newTest.create')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
