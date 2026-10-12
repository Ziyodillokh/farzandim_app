'use client';

import { Check, Plus, X } from 'lucide-react';
import { Controller, useFieldArray, useWatch, type UseFormRegister } from 'react-hook-form';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { PSYCH_LIMITS, type PsychTestInput } from '@/data/schemas/assessments';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { nextOptionKey } from '../../lib/builder';
import { type BuilderControl, type BuilderPath, type Choice, SelectField, useFieldError } from './builder-fields';

type OptionValue = { key: string; text: { uz: string; ru: string }; scale?: string };

/** Javob variantlari: SINGLE — to'g'ri javob belgisi, MULTI — har variantning shkalasi. */
export function OptionsEditor({
  control,
  register,
  index,
  type,
  scales,
}: {
  control: BuilderControl;
  register: UseFormRegister<PsychTestInput>;
  index: number;
  type: 'SINGLE' | 'MULTI';
  scales: Choice[];
}) {
  const { t } = useI18n();
  const err = useFieldError(control);
  const base = `items.${index}.options` as 'items.0.options';
  const { fields, append, remove } = useFieldArray({ control, name: base, keyName: '_key' });
  const options = (useWatch({ control, name: base }) ?? []) as OptionValue[];
  const max = type === 'MULTI' ? PSYCH_LIMITS.multiOptions : PSYCH_LIMITS.options;

  const add = () => {
    const key = nextOptionKey(options.map((o) => o.key));
    const option: OptionValue = { key, text: { uz: '', ru: '' }, ...(type === 'MULTI' ? { scale: scales[0]?.value ?? 'total' } : {}) };
    append(option as never);
  };

  return (
    <div className="space-y-2">
      <p className="text-xs font-medium text-muted-foreground">{t('assessments.builder.options')}</p>
      {err(base) && <p className="text-xs font-medium text-destructive">{err(base)}</p>}
      {err(`items.${index}.correct`) && <p className="text-xs font-medium text-destructive">{err(`items.${index}.correct`)}</p>}
      {fields.map((f, j) => (
        <div key={f._key} className="flex flex-wrap items-start gap-2 sm:flex-nowrap">
          {type === 'SINGLE' ? (
            <Controller
              control={control}
              name={`items.${index}.correct` as BuilderPath}
              render={({ field }) => {
                const on = field.value === options[j]?.key;
                return (
                  <button
                    type="button"
                    onClick={() => field.onChange(options[j]?.key)}
                    aria-pressed={on}
                    aria-label={`${t('assessments.builder.correct')}: ${options[j]?.key ?? ''}`}
                    title={t('assessments.builder.correct')}
                    className={cn(
                      'mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full font-mono text-xs font-semibold ring-1 ring-inset transition-colors',
                      on ? 'bg-success text-white ring-success' : 'bg-white/60 text-muted-foreground ring-border hover:ring-success/50 dark:bg-white/[0.04]',
                    )}
                  >
                    {on ? <Check className="h-4 w-4" /> : options[j]?.key}
                  </button>
                );
              }}
            />
          ) : (
            <span className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary/10 font-mono text-xs font-semibold text-primary">{options[j]?.key}</span>
          )}
          <div className="grid min-w-0 flex-1 gap-2 sm:grid-cols-2">
            <div>
              <Input className="h-9" placeholder={t('assessments.builder.optionUz')} aria-label={t('assessments.builder.optionUz')} {...register(`items.${index}.options.${j}.text.uz` as 'items.0.options.0.text.uz')} />
              {err(`${base}.${j}.text.uz`) && <p className="mt-1 text-xs text-destructive">{err(`${base}.${j}.text.uz`)}</p>}
            </div>
            <div>
              <Input className="h-9" placeholder={t('assessments.builder.optionRu')} aria-label={t('assessments.builder.optionRu')} {...register(`items.${index}.options.${j}.text.ru` as 'items.0.options.0.text.ru')} />
              {err(`${base}.${j}.text.ru`) && <p className="mt-1 text-xs text-destructive">{err(`${base}.${j}.text.ru`)}</p>}
            </div>
          </div>
          {type === 'MULTI' && (
            <SelectField control={control} name={`${base}.${j}.scale` as BuilderPath} choices={scales} label={t('assessments.builder.scale')} className="w-36 [&>label]:sr-only" error={err(`${base}.${j}.scale`)} />
          )}
          <Button type="button" variant="ghost" size="icon-sm" className="mt-0.5" disabled={fields.length <= 2} onClick={() => remove(j)} aria-label={t('assessments.builder.removeOption')}>
            <X />
          </Button>
        </div>
      ))}
      <Button type="button" variant="ghost" size="sm" onClick={add} disabled={fields.length >= max}>
        <Plus />
        {t('assessments.builder.addOption')}
      </Button>
    </div>
  );
}
