'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { useEffect, useMemo, useRef } from 'react';
import { Controller, useForm } from 'react-hook-form';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import type { ClassRow } from '@/data/mock/services/classes';
import { classInputSchema, type ClassInput } from '@/data/schemas/classes';
import { useSchool } from '@/features/school/hooks';
import { useI18n } from '@/i18n';
import { useCreateClass, useHomeroomOptions, useUpdateClass } from '../hooks';

const NONE = '__none__';
const GRADES = Array.from({ length: 11 }, (_, i) => i + 1);

type FormValues = { grade: number; letter: string; shiftId: string; homeroomStaffId: string | null; room: string };

const EMPTY: FormValues = { grade: 1, letter: '', shiftId: '', homeroomStaffId: null, room: '' };

export function ClassFormDialog({ open, onOpenChange, row }: { open: boolean; onOpenChange: (open: boolean) => void; row?: ClassRow }) {
  const { t } = useI18n();
  const school = useSchool();
  const homerooms = useHomeroomOptions(open);
  const create = useCreateClass();
  const update = useUpdateClass();
  const shifts = useMemo(() => school.data?.shifts ?? [], [school.data]);

  const form = useForm<FormValues>({ resolver: zodResolver(classInputSchema), defaultValues: EMPTY });

  // Forma faqat oyna OCHILGANDA to'ldiriladi — fon yangilanishlari (simulyator) kiritilganini o'chirmasin.
  const wasOpen = useRef(false);
  useEffect(() => {
    if (open && !wasOpen.current) {
      form.reset(
        row
          ? { grade: row.grade, letter: row.letter, shiftId: row.shiftId, homeroomStaffId: row.homeroomStaffId, room: row.room }
          : { ...EMPTY, shiftId: shifts[0]?.id ?? '' },
      );
    }
    wasOpen.current = open;
  }, [open, row, shifts, form]);

  useEffect(() => {
    if (open && !form.getValues('shiftId') && shifts[0]) form.setValue('shiftId', shifts[0].id);
  }, [open, shifts, form]);

  const homeroomOptions = useMemo(() => {
    const list = homerooms.data ?? [];
    if (row?.homeroomStaffId && row.homeroomName && !list.some((h) => h.id === row.homeroomStaffId)) {
      return [{ id: row.homeroomStaffId, fullName: row.homeroomName }, ...list];
    }
    return list;
  }, [homerooms.data, row]);

  const submit = form.handleSubmit(async (values) => {
    const input: ClassInput = values;
    try {
      if (row) await update.mutateAsync({ id: row.id, input });
      else await create.mutateAsync(input);
      onOpenChange(false);
    } catch {
      // xato toast orqali ko'rsatildi — oyna ochiq qoladi
    }
  });

  const { errors } = form.formState;
  const grade = form.watch('grade');
  const letter = form.watch('letter');
  const preview = `${grade}-${(letter ?? '').trim().toUpperCase() || '…'}`;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{row ? t('classes.editTitle') : t('classes.createTitle')}</DialogTitle>
          <DialogDescription>{t('classes.form.namePreview', { name: preview })}</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4" noValidate>
          <div className="grid gap-4 sm:grid-cols-3">
            <FormField label={t('classes.form.grade')} error={errors.grade}>
              <Controller
                control={form.control}
                name="grade"
                render={({ field }) => (
                  <Select value={String(field.value)} onValueChange={(v) => field.onChange(Number(v))}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {GRADES.map((g) => (
                        <SelectItem key={g} value={String(g)}>
                          {t('classes.form.gradeOption', { grade: g })}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              />
            </FormField>
            <FormField label={t('classes.form.letter')} htmlFor="class-letter" error={errors.letter}>
              <Input id="class-letter" maxLength={2} className="uppercase" placeholder="A" {...form.register('letter')} />
            </FormField>
            <FormField label={t('classes.form.room')} htmlFor="class-room" error={errors.room} optional>
              <Input id="class-room" maxLength={10} placeholder="207" {...form.register('room')} />
            </FormField>
          </div>
          <FormField label={t('classes.form.shift')} error={errors.shiftId}>
            <Controller
              control={form.control}
              name="shiftId"
              render={({ field }) => (
                <Select value={field.value} onValueChange={field.onChange}>
                  <SelectTrigger>
                    <SelectValue placeholder="—" />
                  </SelectTrigger>
                  <SelectContent>
                    {shifts.map((s) => (
                      <SelectItem key={s.id} value={s.id}>
                        {s.name} · {s.start}–{s.end}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
          </FormField>
          <FormField label={t('classes.form.homeroom')} hint={t('classes.form.homeroomHint')} error={errors.homeroomStaffId}>
            <Controller
              control={form.control}
              name="homeroomStaffId"
              render={({ field }) => (
                <Select value={field.value ?? NONE} onValueChange={(v) => field.onChange(v === NONE ? null : v)}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value={NONE}>{t('classes.form.noHomeroom')}</SelectItem>
                    {homeroomOptions.map((h) => (
                      <SelectItem key={h.id} value={h.id}>
                        {h.fullName}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
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
