'use client';

import { Layers, Plus, Trash2 } from 'lucide-react';
import { useFieldArray, type UseFormRegister } from 'react-hook-form';

import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { DEV_DOMAINS, DISPLAYS, POLARITIES, PSYCH_LIMITS, type PsychTestInput } from '@/data/schemas/assessments';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { type BuilderControl, Field, SelectField, useFieldError } from './builder-fields';

const NO_DOMAIN = '__none__';

/** Shkalalar ro'yxati: kalit, ikki tildagi nom, soha, yo'nalish, ko'rsatish usuli. */
export function ScalesEditor({ control, register }: { control: BuilderControl; register: UseFormRegister<PsychTestInput> }) {
  const { t } = useI18n();
  const err = useFieldError(control);
  const { fields, append, remove } = useFieldArray({ control, name: 'scales', keyName: '_key' });

  const addScale = () =>
    append({
      key: `scale${fields.length + 1}`,
      label: { uz: '', ru: '' },
      domain: 'REASONING',
      polarity: 'HIGHER_BETTER',
      display: 'STANDARD',
    });

  return (
    <SectionCard
      icon={<Layers />}
      title={t('assessments.builder.scales')}
      description={t('assessments.builder.scalesHint')}
      actions={
        <Button type="button" variant="soft" size="sm" onClick={addScale} disabled={fields.length >= PSYCH_LIMITS.scales}>
          <Plus />
          {t('assessments.builder.addScale')}
        </Button>
      }
      bodyClassName="space-y-3 p-5"
    >
      {err('scales') && <p className="text-xs font-medium text-destructive">{err('scales')}</p>}
      {fields.map((f, i) => (
        <div key={f._key} className={cn(TILE, 'grid gap-3 p-3.5 sm:grid-cols-2 lg:grid-cols-[120px_1fr_1fr_auto]')}>
          <Field label={t('assessments.builder.scaleKey')} htmlFor={`sc-${i}-key`} error={err(`scales.${i}.key`)}>
            <Input id={`sc-${i}-key`} className="h-9 font-mono" {...register(`scales.${i}.key`)} />
          </Field>
          <Field label={t('assessments.builder.labelUz')} htmlFor={`sc-${i}-uz`} error={err(`scales.${i}.label.uz`)}>
            <Input id={`sc-${i}-uz`} className="h-9" {...register(`scales.${i}.label.uz`)} />
          </Field>
          <Field label={t('assessments.builder.labelRu')} htmlFor={`sc-${i}-ru`} error={err(`scales.${i}.label.ru`)}>
            <Input id={`sc-${i}-ru`} className="h-9" {...register(`scales.${i}.label.ru`)} />
          </Field>
          <div className="flex items-end justify-end">
            <Button type="button" variant="ghost" size="icon-sm" disabled={fields.length <= 1} onClick={() => remove(i)} aria-label={t('assessments.builder.removeScale')} className="text-destructive hover:text-destructive">
              <Trash2 />
            </Button>
          </div>
          <div className="grid gap-3 sm:col-span-2 sm:grid-cols-3 lg:col-span-4">
            <SelectField
              control={control}
              name={`scales.${i}.domain`}
              label={t('assessments.builder.domain')}
              nullValue={NO_DOMAIN}
              choices={[{ value: NO_DOMAIN, label: t('assessments.builder.noDomain') }, ...DEV_DOMAINS.map((d) => ({ value: d, label: t(`enums.devDomain.${d}`) }))]}
            />
            <SelectField
              control={control}
              name={`scales.${i}.polarity`}
              label={t('assessments.builder.polarity')}
              choices={POLARITIES.map((p) => ({ value: p, label: t(`assessments.overview.polarity.${p}`) }))}
            />
            <SelectField
              control={control}
              name={`scales.${i}.display`}
              label={t('assessments.builder.display')}
              choices={DISPLAYS.map((d) => ({ value: d, label: t(`assessments.overview.display.${d}`) }))}
            />
          </div>
        </div>
      ))}
    </SectionCard>
  );
}
