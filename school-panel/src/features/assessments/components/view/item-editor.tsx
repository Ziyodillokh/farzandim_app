'use client';

import { ArrowDown, ArrowUp, Eye, Trash2 } from 'lucide-react';
import { Controller, useWatch, type UseFormRegister } from 'react-hook-form';

import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Switch } from '@/components/ui/switch';
import { Textarea } from '@/components/ui/textarea';
import type { PsychItem } from '@/data/contracts';
import { ITEM_TYPES, type PsychItemInput, type PsychTestInput } from '@/data/schemas/assessments';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { type BuilderControl, type BuilderPath, type Choice, Field, SelectField, useFieldError } from './builder-fields';
import { OptionsEditor } from './options-editor';

/**
 * Bitta savol: turi, ikki tildagi matn, variantlar / to'g'ri javob, shkala, teskari ball.
 * Turi almashtirilsa — savol butunlay yangilanadi (`onChangeType`).
 */
export function ItemEditor({
  control,
  register,
  index,
  total,
  scales,
  onChangeType,
  onMove,
  onRemove,
}: {
  control: BuilderControl;
  register: UseFormRegister<PsychTestInput>;
  index: number;
  total: number;
  scales: Choice[];
  onChangeType: (type: PsychItem['type']) => void;
  onMove: (to: number) => void;
  onRemove: () => void;
}) {
  const { t } = useI18n();
  const err = useFieldError(control);
  const item = useWatch({ control, name: `items.${index}` }) as PsychItemInput | undefined;
  const type = item?.type ?? 'SINGLE';
  const p = `items.${index}` as const;

  return (
    <li className={cn(TILE, 'space-y-3 p-4')} data-testid={`item-editor-${index}`}>
      <div className="flex flex-wrap items-center gap-2">
        <span className="flex h-7 min-w-7 items-center justify-center rounded-lg bg-primary/10 px-1.5 text-xs font-semibold tabular-nums text-primary">{index + 1}</span>
        <Select value={type} onValueChange={(v) => onChangeType(v as PsychItem['type'])}>
          <SelectTrigger className="h-8 w-44" aria-label={t('assessments.builder.itemType')}>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {ITEM_TYPES.map((x) => (
              <SelectItem key={x} value={x}>
                {t(`assessments.items.type.${x}`)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <code className="text-2xs text-muted-foreground">{item?.id}</code>
        <div className="ml-auto flex gap-1">
          <Button type="button" variant="ghost" size="icon-sm" disabled={index === 0} onClick={() => onMove(index - 1)} aria-label={t('assessments.builder.moveUp')}>
            <ArrowUp />
          </Button>
          <Button type="button" variant="ghost" size="icon-sm" disabled={index === total - 1} onClick={() => onMove(index + 1)} aria-label={t('assessments.builder.moveDown')}>
            <ArrowDown />
          </Button>
          <Button type="button" variant="ghost" size="icon-sm" onClick={onRemove} aria-label={t('assessments.builder.remove')} className="text-destructive hover:text-destructive">
            <Trash2 />
          </Button>
        </div>
      </div>

      {item?.type === 'SINGLE' && item.stimulus && (
        <p className="flex items-center gap-1.5 rounded-lg bg-primary/[0.06] px-3 py-2 text-xs ring-1 ring-inset ring-primary/15">
          <Eye className="h-3.5 w-3.5 text-primary" />
          {t('assessments.items.stimulus', { sec: item.stimulus.showSec })}
        </p>
      )}

      <div className="grid gap-3 sm:grid-cols-2">
        <Field label={t('assessments.builder.textUz')} htmlFor={`it-${index}-uz`} error={err(`${p}.text.uz`)}>
          <Textarea id={`it-${index}-uz`} rows={2} {...register(`${p}.text.uz`)} />
        </Field>
        <Field label={t('assessments.builder.textRu')} htmlFor={`it-${index}-ru`} error={err(`${p}.text.ru`)}>
          <Textarea id={`it-${index}-ru`} rows={2} {...register(`${p}.text.ru`)} />
        </Field>
      </div>

      {type !== 'MULTI' && (
        <div className="flex flex-wrap items-end gap-4">
          <SelectField control={control} name={`${p}.scale` as BuilderPath} choices={scales} label={t('assessments.builder.scale')} className="w-48" error={err(`${p}.scale`)} />
          {type === 'LIKERT' && (
            <Controller
              control={control}
              name={`${p}.reverse` as BuilderPath}
              render={({ field }) => (
                <div className="flex items-center gap-2 pb-1.5">
                  <Switch id={`it-${index}-rev`} checked={field.value === true} onCheckedChange={field.onChange} />
                  <Label htmlFor={`it-${index}-rev`} className="text-sm">
                    {t('assessments.builder.reverse')}
                    <span className="block text-xs font-normal text-muted-foreground">{t('assessments.builder.reverseHint')}</span>
                  </Label>
                </div>
              )}
            />
          )}
        </div>
      )}

      {type !== 'LIKERT' && <OptionsEditor key={type} control={control} register={register} index={index} type={type} scales={scales} />}
    </li>
  );
}
