'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { TriangleAlert } from 'lucide-react';
import { useEffect } from 'react';
import { Controller, useForm } from 'react-hook-form';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Textarea } from '@/components/ui/textarea';
import { useSession } from '@/auth/use-session';
import { addDays } from '@/data/mock/calendar';
import { clockToday } from '@/data/mock/clock';
import { assignmentInputSchema, type AssignmentInput } from '@/data/schemas/learning';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useCreateAssignment, useLearningClassOptions, useLearningMaterials } from '../hooks';
import { gradesLabel } from '../lib/format';

const DEFAULT_DUE_DAYS = 7;

/** Topshiriq berish: material + sinflar (doira bo'yicha) + muddat + izoh. */
export function AssignmentFormDialog({ open, onOpenChange, materialId }: { open: boolean; onOpenChange: (open: boolean) => void; materialId?: string }) {
  const { t } = useI18n();
  const session = useSession();
  const materials = useLearningMaterials({});
  const classes = useLearningClassOptions();
  const create = useCreateAssignment();
  const ownClassOnly = session?.role === 'HOMEROOM';
  const form = useForm<AssignmentInput>({
    resolver: zodResolver(assignmentInputSchema),
    defaultValues: { materialId: '', classIds: [], dueDate: addDays(clockToday(), DEFAULT_DUE_DAYS), note: '' },
  });

  useEffect(() => {
    if (!open) return;
    const own = ownClassOnly ? (classes.data ?? []).map((c) => c.id) : [];
    form.reset({ materialId: materialId ?? '', classIds: own, dueDate: addDays(clockToday(), DEFAULT_DUE_DAYS), note: '' });
  }, [open, materialId, ownClassOnly, classes.data, form]);

  const material = materials.data?.find((m) => m.id === form.watch('materialId'));
  const selected = form.watch('classIds');
  const mismatch = Boolean(
    material && (classes.data ?? []).some((c) => selected.includes(c.id) && !material.grades.includes(c.grade)),
  );

  const submit = form.handleSubmit((values) => create.mutate(values, { onSuccess: () => onOpenChange(false) }));
  const { errors } = form.formState;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>{t('learning.assignments.createTitle')}</DialogTitle>
          {ownClassOnly && <DialogDescription>{t('learning.assignments.scopeHint')}</DialogDescription>}
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4" noValidate>
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

          <FormField label={t('learning.assignments.fields.classes')} error={errors.classIds}>
            <Controller
              control={form.control}
              name="classIds"
              render={({ field }) => (
                <div>
                  {!ownClassOnly && (
                    <div className="mb-2 flex gap-2">
                      <Button type="button" variant="ghost" size="sm" onClick={() => field.onChange((classes.data ?? []).filter((c) => !material || material.grades.includes(c.grade)).map((c) => c.id))}>
                        {t('learning.assignments.selectAll')}
                      </Button>
                      <Button type="button" variant="ghost" size="sm" onClick={() => field.onChange([])}>
                        {t('learning.assignments.clear')}
                      </Button>
                    </div>
                  )}
                  <div className="grid grid-cols-3 gap-2 sm:grid-cols-6">
                    {(classes.data ?? []).map((c) => {
                      const checked = field.value.includes(c.id);
                      const fits = !material || material.grades.includes(c.grade);
                      return (
                        <label
                          key={c.id}
                          className={cn(
                            'flex cursor-pointer items-center gap-2 rounded-lg border px-2.5 py-2 text-sm transition-colors',
                            checked && 'border-primary/40 bg-primary/[0.05]',
                            !fits && 'opacity-60',
                          )}
                        >
                          <Checkbox
                            checked={checked}
                            onCheckedChange={(on) => field.onChange(on === true ? [...field.value, c.id] : field.value.filter((x) => x !== c.id))}
                          />
                          {c.name}
                        </label>
                      );
                    })}
                  </div>
                </div>
              )}
            />
          </FormField>
          {mismatch && (
            <p className="-mt-2 flex items-center gap-2 text-xs font-medium text-warning">
              <TriangleAlert className="h-3.5 w-3.5" />
              {t('learning.assignments.gradeMismatch')}
            </p>
          )}

          <FormField label={t('learning.assignments.fields.dueDate')} htmlFor="asg-due" error={errors.dueDate}>
            <Input id="asg-due" type="date" min={clockToday()} {...form.register('dueDate')} className="sm:w-48" />
          </FormField>
          <FormField label={t('learning.assignments.fields.note')} htmlFor="asg-note" error={errors.note} optional>
            <Textarea id="asg-note" rows={2} maxLength={300} placeholder={t('learning.assignments.fields.notePlaceholder')} {...form.register('note')} />
          </FormField>

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
