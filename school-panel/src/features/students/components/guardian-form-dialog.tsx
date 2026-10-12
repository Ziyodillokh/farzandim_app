'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { useEffect } from 'react';
import { Controller, useForm } from 'react-hook-form';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { guardianInputSchema, type GuardianInput } from '@/data/schemas/students';
import { useI18n } from '@/i18n';
import { useAddGuardian } from '../hooks';

export function GuardianFormDialog({ studentId, open, onOpenChange }: { studentId: string; open: boolean; onOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const add = useAddGuardian();
  const form = useForm<GuardianInput>({
    resolver: zodResolver(guardianInputSchema),
    defaultValues: { fullName: '', phone: '+998 ', relation: 'MOTHER' },
  });

  useEffect(() => {
    if (open) form.reset({ fullName: '', phone: '+998 ', relation: 'MOTHER' });
  }, [open, form]);

  const submit = form.handleSubmit(async (values) => {
    await add.mutateAsync({ studentId, input: values });
    onOpenChange(false);
  });

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t('students.detail.addGuardian')}</DialogTitle>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4" noValidate>
          <FormField label={t('students.fields.guardianName')} htmlFor="g-name" error={form.formState.errors.fullName}>
            <Input id="g-name" {...form.register('fullName')} autoFocus />
          </FormField>
          <FormField label={t('students.fields.guardianPhone')} htmlFor="g-phone" error={form.formState.errors.phone} hint="+998 90 123 45 67">
            <Input id="g-phone" inputMode="tel" {...form.register('phone')} />
          </FormField>
          <FormField label={t('students.fields.relation')}>
            <Controller
              control={form.control}
              name="relation"
              render={({ field }) => (
                <Select value={field.value} onValueChange={field.onChange}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {(['MOTHER', 'FATHER', 'GRANDPARENT', 'OTHER'] as const).map((r) => (
                      <SelectItem key={r} value={r}>
                        {t(`enums.relation.${r}`)}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
          </FormField>
          <DialogFooter>
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
