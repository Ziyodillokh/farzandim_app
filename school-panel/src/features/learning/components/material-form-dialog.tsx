'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { Link2 } from 'lucide-react';
import { useEffect } from 'react';
import { Controller, useForm } from 'react-hook-form';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Textarea } from '@/components/ui/textarea';
import type { LearningMaterial } from '@/data/contracts';
import {
  MATERIAL_BODY_MAX,
  MATERIAL_LINK_MAX,
  MATERIAL_TITLE_MAX,
  MATERIAL_TITLE_MIN,
  materialInputSchema,
  type MaterialInput,
  SUBJECTS,
} from '@/data/schemas/learning';
import { SELECTED_SOFT, TILE_BUTTON } from '@/features/messages/styles';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useSaveMaterial } from '../hooks';

const GRADES = Array.from({ length: 11 }, (_, i) => i + 1);
const DEFAULT_MINUTES = 15;

const emptyValues = (): MaterialInput => ({ title: '', subject: 'MATH', grades: [], body: '', linkUrl: '', estimatedMinutes: DEFAULT_MINUTES });

const toValues = (m: LearningMaterial): MaterialInput => ({
  title: m.title,
  subject: m.subject,
  grades: [...m.grades],
  body: m.body ?? '',
  linkUrl: m.linkUrl ?? '',
  estimatedMinutes: m.durationMin,
});

/**
 * Maktabning o'z materiali: sarlavha, fan, sinflar, matn (bola ilovasida o'qiladi), ixtiyoriy https havola
 * (video, hujjat) va taxminiy vaqt. Saqlangach "Tayinlash" bilan sinflarga yuboriladi.
 */
export function MaterialFormDialog({
  open,
  onOpenChange,
  material,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Berilsa — tahrirlash. */
  material?: LearningMaterial | null;
}) {
  const { t } = useI18n();
  const save = useSaveMaterial();
  const form = useForm<MaterialInput>({ resolver: zodResolver(materialInputSchema), defaultValues: emptyValues() });
  const errors = form.formState.errors;
  const body = form.watch('body') ?? '';

  useEffect(() => {
    if (open) form.reset(material ? toValues(material) : emptyValues());
  }, [open, material, form]);

  const submit = form.handleSubmit(async (values) => {
    try {
      await save.mutateAsync({ id: material?.id, input: { ...values, linkUrl: values.linkUrl?.trim() ?? '' } });
      onOpenChange(false);
    } catch {
      // Xato toast orqali ko'rsatildi.
    }
  });

  const withMax = (error: { message?: string } | undefined, max: number) => {
    if (error?.message === 'errors.form.tooLong') return { message: t('errors.form.tooLong', { max }) };
    if (error?.message === 'errors.form.tooShort') return { message: t('errors.form.tooShort', { min: MATERIAL_TITLE_MIN }) };
    return error;
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>{material ? t('learning.materials.form.editTitle') : t('learning.materials.form.createTitle')}</DialogTitle>
          <DialogDescription>{t('learning.materials.form.description')}</DialogDescription>
        </DialogHeader>

        <form id="material-form" className="space-y-4" onSubmit={(e) => void submit(e)}>
          <FormField label={t('learning.materials.form.title')} htmlFor="mat-title" error={withMax(errors.title, MATERIAL_TITLE_MAX)}>
            <Input id="mat-title" maxLength={MATERIAL_TITLE_MAX} placeholder={t('learning.materials.form.titlePlaceholder')} {...form.register('title')} />
          </FormField>

          <div className="grid gap-4 sm:grid-cols-2">
            <FormField label={t('learning.materials.subject')} error={errors.subject}>
              <Controller
                control={form.control}
                name="subject"
                render={({ field }) => (
                  <Select value={field.value} onValueChange={field.onChange}>
                    <SelectTrigger aria-label={t('learning.materials.subject')}>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {SUBJECTS.map((s) => (
                        <SelectItem key={s} value={s}>
                          {t(`enums.subject.${s}`)}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              />
            </FormField>
            <FormField label={t('learning.materials.form.minutes')} htmlFor="mat-minutes" error={errors.estimatedMinutes}>
              <Input id="mat-minutes" type="number" inputMode="numeric" min={1} max={240} {...form.register('estimatedMinutes', { valueAsNumber: true })} />
            </FormField>
          </div>

          <FormField label={t('learning.materials.form.grades')} error={errors.grades as { message?: string } | undefined}>
            <Controller
              control={form.control}
              name="grades"
              render={({ field }) => (
                <div className="flex flex-wrap gap-1.5" role="group" aria-label={t('learning.materials.form.grades')}>
                  {GRADES.map((g) => {
                    const on = field.value.includes(g);
                    return (
                      <button
                        key={g}
                        type="button"
                        aria-pressed={on}
                        onClick={() => field.onChange(on ? field.value.filter((x) => x !== g) : [...field.value, g].sort((a, b) => a - b))}
                        className={cn(TILE_BUTTON, 'h-9 min-w-9 px-2.5 text-sm font-medium tabular-nums', on && SELECTED_SOFT)}
                      >
                        {g}
                      </button>
                    );
                  })}
                </div>
              )}
            />
          </FormField>

          <FormField
            label={t('learning.materials.form.body')}
            htmlFor="mat-body"
            error={withMax(errors.body, MATERIAL_BODY_MAX)}
            hint={`${body.length} / ${MATERIAL_BODY_MAX}`}
          >
            <Textarea id="mat-body" rows={7} maxLength={MATERIAL_BODY_MAX} placeholder={t('learning.materials.form.bodyPlaceholder')} {...form.register('body')} />
          </FormField>

          <FormField label={t('learning.materials.form.link')} htmlFor="mat-link" error={withMax(errors.linkUrl, MATERIAL_LINK_MAX)} hint={t('learning.materials.form.linkHint')} optional>
            <div className="relative">
              <Link2 className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input id="mat-link" type="url" inputMode="url" className="pl-9" maxLength={MATERIAL_LINK_MAX} placeholder="https://" {...form.register('linkUrl')} />
            </div>
          </FormField>
        </form>

        <DialogFooter className="gap-2">
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button type="submit" form="material-form" loading={save.isPending}>
            {material ? t('common.save') : t('learning.materials.form.create')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
