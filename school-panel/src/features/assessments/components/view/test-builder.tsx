'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { CheckCircle2, CircleDot, ListChecks, Plus, Save, Settings2 } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { Controller, useFieldArray, useForm, useWatch } from 'react-hook-form';
import { toast } from 'sonner';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { EmptyState } from '@/components/common/empty-state';
import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import type { PsychItem } from '@/data/contracts';
import type { PsychTestDetail } from '@/data/mock/services/assessments';
import { ITEM_TYPES, PSYCH_KINDS, PSYCH_LIMITS, psychTestInputSchema, type PsychTestInput } from '@/data/schemas/assessments';
import { useI18n } from '@/i18n';
import { useUpdateTest } from '../../hooks';
import { changeItemType, newItem, nextItemId, normsForScales, toInput } from '../../lib/builder';
import { GradesPicker } from '../grades-picker';
import { Field, SelectField, useFieldError } from './builder-fields';
import { ItemEditor } from './item-editor';
import { ScalesEditor } from './scales-editor';

const sameJson = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);

/** Forma qiymatlari — me'yorlarsiz (ular alohida tabda); saqlashda testning me'yorlari qo'shiladi. */
function formValues(test: PsychTestDetail): PsychTestInput {
  return { ...toInput(test), norms: {} };
}

function GeneralCard({ form }: { form: ReturnType<typeof useForm<PsychTestInput>> }) {
  const { t } = useI18n();
  const err = useFieldError(form.control);
  const { register, control } = form;
  return (
    <SectionCard icon={<Settings2 />} title={t('assessments.builder.general')} bodyClassName="grid gap-4 p-5 sm:grid-cols-2">
      <Field label={t('assessments.builder.titleUz')} htmlFor="b-title-uz" error={err('title.uz')}>
        <Input id="b-title-uz" {...register('title.uz')} />
      </Field>
      <Field label={t('assessments.builder.titleRu')} htmlFor="b-title-ru" error={err('title.ru')}>
        <Input id="b-title-ru" {...register('title.ru')} />
      </Field>
      <Field label={t('assessments.builder.descriptionUz')} htmlFor="b-desc-uz" error={err('description.uz')}>
        <Textarea id="b-desc-uz" rows={2} {...register('description.uz')} />
      </Field>
      <Field label={t('assessments.builder.descriptionRu')} htmlFor="b-desc-ru" error={err('description.ru')}>
        <Textarea id="b-desc-ru" rows={2} {...register('description.ru')} />
      </Field>
      <Field label={t('assessments.builder.instructionsUz')} htmlFor="b-ins-uz" error={err('instructions.uz')}>
        <Textarea id="b-ins-uz" rows={2} {...register('instructions.uz')} />
      </Field>
      <Field label={t('assessments.builder.instructionsRu')} htmlFor="b-ins-ru" error={err('instructions.ru')}>
        <Textarea id="b-ins-ru" rows={2} {...register('instructions.ru')} />
      </Field>
      <div className="grid gap-4 sm:col-span-2 sm:grid-cols-[1fr_160px]">
        <SelectField control={control} name="kind" label={t('assessments.builder.kind')} choices={PSYCH_KINDS.map((k) => ({ value: k, label: t(`enums.psychKind.${k}`) }))} />
        <Field label={t('assessments.builder.timeLimit')} htmlFor="b-time" error={err('timeLimitMin')}>
          <Input id="b-time" type="number" min={1} max={120} {...register('timeLimitMin', { setValueAs: (v: string) => (v === '' || v === null ? null : Number(v)) })} />
        </Field>
      </div>
      <Field label={t('assessments.builder.grades')} error={err('grades')} className="sm:col-span-2">
        <Controller control={control} name="grades" render={({ field }) => <GradesPicker value={field.value} onChange={field.onChange} />} />
      </Field>
    </SectionCard>
  );
}

/** Test konstruktori (CUSTOM / IMPORTED): savollar `useFieldArray` bilan; nashr etilgan testda — yangi versiya tasdig'i. */
export function TestBuilder({ test }: { test: PsychTestDetail }) {
  const { t } = useI18n();
  const update = useUpdateTest();
  const form = useForm<PsychTestInput>({ resolver: zodResolver(psychTestInputSchema), defaultValues: formValues(test) });
  const items = useFieldArray({ control: form.control, name: 'items', keyName: '_key' });
  const scaleValues = useWatch({ control: form.control, name: 'scales' });
  const [pending, setPending] = useState<PsychTestInput | null>(null);
  const err = useFieldError(form.control);

  useEffect(() => {
    form.reset(formValues(test));
  }, [test, form]);

  const scaleChoices = useMemo(
    () => (scaleValues ?? []).filter((s) => s.key).map((s) => ({ value: s.key, label: s.label?.uz ? `${s.label.uz} (${s.key})` : s.key })),
    [scaleValues],
  );
  const firstScale = scaleChoices[0]?.value ?? 'total';

  const save = (input: PsychTestInput) =>
    update.mutate(
      { id: test.id, input },
      {
        onSuccess: () => {
          setPending(null);
        },
      },
    );

  const submit = form.handleSubmit(
    (values) => {
      const input = { ...values, norms: normsForScales(test.norms, values.scales) };
      const structural = !sameJson(values.items, test.items) || !sameJson(values.scales, test.scales);
      if (test.status === 'PUBLISHED' && structural) setPending(input);
      else save(input);
    },
    () => toast.error(t('assessments.builder.invalid')),
  );

  const addItem = (type: PsychItem['type']) => items.append(newItem(type, nextItemId(form.getValues('items')), firstScale));
  const dirty = form.formState.isDirty;

  return (
    <form onSubmit={submit} className="space-y-6" noValidate>
      <GeneralCard form={form} />
      <ScalesEditor control={form.control} register={form.register} />
      <SectionCard
        icon={<ListChecks />}
        title={t('assessments.builder.items')}
        description={t('assessments.builder.itemsHint')}
        bodyClassName="space-y-3 p-5"
      >
        {err('items') && <p className="text-xs font-medium text-destructive">{err('items')}</p>}
        {items.fields.length === 0 ? (
          <EmptyState icon={<ListChecks />} title={t('assessments.builder.noItems')} description={t('assessments.builder.noItemsHint')} className="py-8" />
        ) : (
          <ol className="space-y-3">
            {items.fields.map((f, i) => (
              <ItemEditor
                key={f._key}
                control={form.control}
                register={form.register}
                index={i}
                total={items.fields.length}
                scales={scaleChoices}
                onChangeType={(type) => items.update(i, changeItemType(form.getValues(`items.${i}`), type, firstScale))}
                onMove={(to) => items.move(i, to)}
                onRemove={() => items.remove(i)}
              />
            ))}
          </ol>
        )}
        <div className="flex flex-wrap gap-2 pt-1">
          {ITEM_TYPES.map((type) => (
            <Button key={type} type="button" variant="soft" size="sm" onClick={() => addItem(type)} disabled={items.fields.length >= PSYCH_LIMITS.items} data-testid={`add-item-${type}`}>
              <Plus />
              {t('assessments.builder.addItem')}: {t(`assessments.items.type.${type}`)}
            </Button>
          ))}
        </div>
      </SectionCard>

      <div className="glass-bar sticky bottom-4 z-10 flex flex-wrap items-center justify-between gap-3 rounded-2xl px-4 py-3">
        <span className="flex items-center gap-2 text-sm text-muted-foreground">
          {dirty ? <CircleDot className="h-4 w-4 text-warning" /> : <CheckCircle2 className="h-4 w-4 text-success" />}
          {dirty ? t('assessments.builder.dirty') : t('assessments.builder.clean')}
        </span>
        <Button type="submit" loading={update.isPending} data-testid="builder-save">
          <Save />
          {t('assessments.builder.save')}
        </Button>
      </div>

      <ConfirmDialog
        open={pending !== null}
        onOpenChange={(open) => !open && setPending(null)}
        title={t('assessments.builder.versionTitle')}
        description={t('assessments.builder.versionDescription', { next: test.version + 1 })}
        confirmLabel={t('assessments.builder.versionConfirm', { next: test.version + 1 })}
        loading={update.isPending}
        onConfirm={() => pending && save(pending)}
      />
    </form>
  );
}
