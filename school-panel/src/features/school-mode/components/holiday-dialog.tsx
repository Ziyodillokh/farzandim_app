'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { useEffect } from 'react';
import { useForm } from 'react-hook-form';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { holidayInputSchema, type HolidayInput } from '@/data/schemas/school';
import { useI18n } from '@/i18n';
import { useAddHoliday } from '../hooks';

/** Bayram kunini qo'shish (sana + nomi). */
export function HolidayDialog({ open, onOpenChange, defaultDate }: { open: boolean; onOpenChange: (open: boolean) => void; defaultDate: string }) {
  const { t } = useI18n();
  const add = useAddHoliday();
  const form = useForm<HolidayInput>({ resolver: zodResolver(holidayInputSchema), defaultValues: { date: defaultDate, name: '' } });

  useEffect(() => {
    if (open) form.reset({ date: defaultDate, name: '' });
  }, [open, defaultDate, form]);

  const submit = form.handleSubmit((values) => add.mutate(values, { onSuccess: () => onOpenChange(false) }));
  const { errors } = form.formState;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t('schoolMode.holidays.add')}</DialogTitle>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4" noValidate>
          <FormField label={t('schoolMode.holidays.date')} htmlFor="holiday-date" error={errors.date}>
            <Input id="holiday-date" type="date" {...form.register('date')} />
          </FormField>
          <FormField label={t('schoolMode.holidays.name')} htmlFor="holiday-name" error={errors.name}>
            <Input id="holiday-name" placeholder={t('schoolMode.holidays.namePlaceholder')} maxLength={60} {...form.register('name')} />
          </FormField>
          <DialogFooter className="mt-2">
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" loading={add.isPending}>
              {t('common.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
