'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { TriangleAlert } from 'lucide-react';
import { useEffect, useState } from 'react';
import { Controller, useForm } from 'react-hook-form';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Textarea } from '@/components/ui/textarea';
import { useSession } from '@/auth/use-session';
import { addDays } from '@/data/mock/calendar';
import { clockToday } from '@/data/mock/clock';
import { assignmentInputSchema, type AssignmentInput, NOTE_MAX, WRITTEN_MATERIAL_ID, WRITTEN_TITLE_MAX } from '@/data/schemas/learning';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useCreateAssignment, useLearningClassOptions, useLearningMaterials } from '../hooks';
import { gradesLabel } from '../lib/format';
import { AssignmentClassPicker } from './assignment-class-picker';

const DEFAULT_DUE_DAYS = 7;

type Kind = 'catalog' | 'written';

/** Faqat tanlangan turga tegishli maydonlar yuboriladi (katalogda sarlavha yo'q). */
function toPayload(values: AssignmentInput, kind: Kind): AssignmentInput {
  const { title, estimatedMinutes, ...rest } = values;
  return {
    ...rest,
    ...(kind === 'written' && { title: (title ?? '').trim() }),
    ...(estimatedMinutes !== undefined && { estimatedMinutes }),
  };
}

/** Topshiriq berish: katalogdan material YOKI yozma vazifa + sinflar (doira bo'yicha) + muddat. */
export function AssignmentFormDialog({ open, onOpenChange, materialId }: { open: boolean; onOpenChange: (open: boolean) => void; materialId?: string }) {
  const { t } = useI18n();
  const session = useSession();
  const materials = useLearningMaterials({});
  const classes = useLearningClassOptions();
  const create = useCreateAssignment();
  const ownClassOnly = session?.role === 'HOMEROOM';
  const [kind, setKind] = useState<Kind>('catalog');
  const form = useForm<AssignmentInput>({
    resolver: zodResolver(assignmentInputSchema),
    defaultValues: { materialId: '', classIds: [], dueDate: addDays(clockToday(), DEFAULT_DUE_DAYS), note: '', title: '' },
  });

  useEffect(() => {
    if (!open) return;
    const own = ownClassOnly ? (classes.data ?? []).map((c) => c.id) : [];
    setKind('catalog');
    form.reset({ materialId: materialId ?? '', classIds: own, dueDate: addDays(clockToday(), DEFAULT_DUE_DAYS), note: '', title: '', estimatedMinutes: undefined });
  }, [open, materialId, ownClassOnly, classes.data, form]);

  const switchKind = (next: Kind) => {
    setKind(next);
    form.setValue('materialId', next === 'written' ? WRITTEN_MATERIAL_ID : (materialId ?? ''));
    form.clearErrors();
  };

  const material = materials.data?.find((m) => m.id === form.watch('materialId'));
  const selected = form.watch('classIds');
  const mismatch = Boolean(kind === 'catalog' && material && (classes.data ?? []).some((c) => selected.includes(c.id) && !material.grades.includes(c.grade)));

  const submit = form.handleSubmit((values) => create.mutate(toPayload(values, kind), { onSuccess: () => onOpenChange(false) }));
  const { errors } = form.formState;
  const withMax = (error: { message?: string } | undefined, max: number) => (error?.message === 'errors.form.tooLong' ? { message: t('errors.form.tooLong', { max }) } : error);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>{t('learning.assignments.createTitle')}</DialogTitle>
          <DialogDescription className={ownClassOnly ? undefined : 'sr-only'}>
            {ownClassOnly ? t('learning.assignments.scopeHint') : t('learning.assignments.createTitle')}
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4" noValidate>
          <div role="group" aria-label={t('learning.assignments.kindLabel')} className="inline-flex w-fit rounded-xl bg-primary/[0.06] p-1 ring-1 ring-inset ring-border/50 dark:bg-white/[0.04]">
            {(['catalog', 'written'] as const).map((k) => (
              <button
                key={k}
                type="button"
                aria-pressed={kind === k}
                onClick={() => switchKind(k)}
                className={cn(
                  'rounded-lg px-3 py-1.5 text-sm font-medium transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
                  kind === k ? 'bg-card text-foreground shadow-soft ring-1 ring-inset ring-border/50' : 'text-muted-foreground hover:text-foreground',
                )}
              >
                {t(`learning.assignments.kinds.${k}`)}
              </button>
            ))}
          </div>

          {kind === 'catalog' ? (
            <FormField
              label={t('learning.assignments.fields.material')}
              error={errors.materialId}
              hint={material ? t('learning.assignments.gradeHint', { grades: gradesLabel(t, material.grades) }) : undefined}
            >
              <Controller
                control={form.control}
                name="materialId"
                render={({ field }) => (
                  <Select value={field.value} onValueChange={field.onChange}>
                    <SelectTrigger aria-label={t('learning.assignments.fields.material')}>
                      <SelectValue placeholder={t('learning.assignments.fields.materialPlaceholder')} />
                    </SelectTrigger>
                    <SelectContent>
                      {materials.data?.map((m) => (
                        <SelectItem key={m.id} value={m.id}>
                          {m.title} · {t(`enums.materialKind.${m.kind}`)}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              />
            </FormField>
          ) : (
            <>
              <p className="-mt-1 text-xs text-muted-foreground">{t('learning.assignments.writtenHint')}</p>
              <FormField label={t('learning.assignments.fields.title')} htmlFor="asg-title" error={withMax(errors.title, WRITTEN_TITLE_MAX)}>
                <Input id="asg-title" maxLength={WRITTEN_TITLE_MAX} placeholder={t('learning.assignments.fields.titlePlaceholder')} {...form.register('title')} />
              </FormField>
              <FormField label={t('learning.assignments.fields.instructions')} htmlFor="asg-note" error={withMax(errors.note, NOTE_MAX)} optional>
                <Textarea id="asg-note" rows={3} maxLength={NOTE_MAX} placeholder={t('learning.assignments.fields.instructionsPlaceholder')} {...form.register('note')} />
              </FormField>
            </>
          )}

          <FormField label={t('learning.assignments.fields.classes')} error={errors.classIds}>
            <Controller
              control={form.control}
              name="classIds"
              render={({ field }) => (
                <AssignmentClassPicker
                  classes={classes.data ?? []}
                  value={field.value}
                  onChange={field.onChange}
                  showBulkActions={!ownClassOnly}
                  fits={(c) => kind === 'written' || !material || material.grades.includes(c.grade)}
                />
              )}
            />
          </FormField>
          {mismatch && (
            <p className="-mt-2 flex items-center gap-2 text-xs font-medium text-warning">
              <TriangleAlert className="h-3.5 w-3.5" />
              {t('learning.assignments.gradeMismatch')}
            </p>
          )}

          <div className="grid gap-4 sm:grid-cols-2">
            <FormField label={t('learning.assignments.fields.dueDate')} htmlFor="asg-due" error={errors.dueDate}>
              <Input id="asg-due" type="date" min={clockToday()} {...form.register('dueDate')} />
            </FormField>
            <FormField label={t('learning.assignments.fields.estimatedMinutes')} htmlFor="asg-minutes" error={errors.estimatedMinutes} hint={t('learning.assignments.fields.estimatedMinutesHint')} optional>
              <Input
                id="asg-minutes"
                type="number"
                inputMode="numeric"
                min={1}
                max={240}
                {...form.register('estimatedMinutes', { setValueAs: (v: string | number | null | undefined) => (v === '' || v === null || v === undefined ? undefined : Number(v)) })}
              />
            </FormField>
          </div>
          {kind === 'catalog' && (
            <FormField label={t('learning.assignments.fields.note')} htmlFor="asg-note" error={withMax(errors.note, NOTE_MAX)} optional>
              <Textarea id="asg-note" rows={2} maxLength={NOTE_MAX} placeholder={t('learning.assignments.fields.notePlaceholder')} {...form.register('note')} />
            </FormField>
          )}

          <DialogFooter className="mt-2">
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" loading={create.isPending}>
              {t('learning.assignments.create')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
