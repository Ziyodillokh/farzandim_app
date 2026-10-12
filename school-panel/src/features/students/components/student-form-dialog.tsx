'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { useEffect, useRef } from 'react';
import { Controller, useForm } from 'react-hook-form';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Separator } from '@/components/ui/separator';
import type { Student } from '@/data/contracts';
import { studentCreateSchema, type StudentCreateInput } from '@/data/schemas/students';
import { useI18n } from '@/i18n';
import { useClassOptions, useCreateStudent, useUpdateStudent } from '../hooks';

type FormValues = StudentCreateInput & { guardianName?: string; guardianPhone?: string; guardianRelation?: 'MOTHER' | 'FATHER' | 'GRANDPARENT' | 'OTHER' };

const EMPTY: FormValues = {
  lastName: '',
  firstName: '',
  middleName: '',
  gender: 'MALE',
  birthDate: '2014-01-01',
  classId: '',
  device: 'ANDROID',
  guardianName: '',
  guardianPhone: '+998 ',
  guardianRelation: 'MOTHER',
};

/** Yangi o'quvchi yoki tahrirlash (student berilsa). */
export function StudentFormDialog({
  open,
  onOpenChange,
  student,
  defaultClassId,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  student?: Student;
  defaultClassId?: string;
}) {
  const { t } = useI18n();
  const classes = useClassOptions();
  const create = useCreateStudent();
  const update = useUpdateStudent();
  const editing = Boolean(student);

  const form = useForm<FormValues>({
    resolver: zodResolver(studentCreateSchema.omit({ guardian: true })),
    defaultValues: EMPTY,
  });

  // Formani faqat ochilganda to'ldiramiz: jonli simulyator so'rovlarni tez-tez
  // yangilaydi va `student` obyekti almashadi — yozilayotgan matn o'chmasin.
  const wasOpen = useRef(false);
  useEffect(() => {
    if (open && !wasOpen.current) {
      form.reset(
        student
          ? { ...EMPTY, ...student, middleName: student.middleName }
          : { ...EMPTY, classId: defaultClassId ?? classes.data?.[0]?.id ?? '' },
      );
    }
    wasOpen.current = open;
  }, [open, student, defaultClassId, classes.data, form]);

  // Sinflar ro'yxati kechroq yuklansa — faqat bo'sh sinf maydonini to'ldiramiz.
  useEffect(() => {
    const first = classes.data?.[0]?.id;
    if (open && !student && first && !form.getValues('classId')) form.setValue('classId', defaultClassId ?? first);
  }, [open, student, defaultClassId, classes.data, form]);

  const submit = form.handleSubmit(async (values) => {
    const { guardianName, guardianPhone, guardianRelation, ...fields } = values;
    if (student) {
      await update.mutateAsync({ id: student.id, input: fields });
    } else {
      const hasGuardian = Boolean(guardianName?.trim()) && (guardianPhone?.replace(/\D/g, '').length ?? 0) > 3;
      await create.mutateAsync({
        ...fields,
        guardian: hasGuardian ? { fullName: guardianName ?? '', phone: guardianPhone ?? '', relation: guardianRelation ?? 'OTHER' } : undefined,
      });
    }
    onOpenChange(false);
  });

  const { errors } = form.formState;
  const pending = create.isPending || update.isPending;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>{editing ? t('students.editTitle') : t('students.createTitle')}</DialogTitle>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4" noValidate>
          <div className="grid gap-4 sm:grid-cols-2">
            <FormField label={t('students.fields.lastName')} htmlFor="lastName" error={errors.lastName}>
              <Input id="lastName" {...form.register('lastName')} />
            </FormField>
            <FormField label={t('students.fields.firstName')} htmlFor="firstName" error={errors.firstName}>
              <Input id="firstName" {...form.register('firstName')} />
            </FormField>
          </div>
          <FormField label={t('students.fields.middleName')} htmlFor="middleName" error={errors.middleName} optional>
            <Input id="middleName" placeholder={t('students.fields.middleNamePlaceholder')} {...form.register('middleName')} />
          </FormField>
          <div className="grid gap-4 sm:grid-cols-3">
            <FormField label={t('students.fields.class')} error={errors.classId}>
              <Controller
                control={form.control}
                name="classId"
                render={({ field }) => (
                  <Select value={field.value} onValueChange={field.onChange}>
                    <SelectTrigger>
                      <SelectValue placeholder="—" />
                    </SelectTrigger>
                    <SelectContent>
                      {classes.data?.map((c) => (
                        <SelectItem key={c.id} value={c.id}>
                          {c.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              />
            </FormField>
            <FormField label={t('students.fields.gender')}>
              <Controller
                control={form.control}
                name="gender"
                render={({ field }) => (
                  <Select value={field.value} onValueChange={field.onChange}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="MALE">{t('enums.gender.MALE')}</SelectItem>
                      <SelectItem value="FEMALE">{t('enums.gender.FEMALE')}</SelectItem>
                    </SelectContent>
                  </Select>
                )}
              />
            </FormField>
            <FormField label={t('students.fields.birthDate')} htmlFor="birthDate" error={errors.birthDate}>
              <Input id="birthDate" type="date" {...form.register('birthDate')} />
            </FormField>
          </div>
          <FormField label={t('students.fields.device')}>
            <Controller
              control={form.control}
              name="device"
              render={({ field }) => (
                <Select value={field.value} onValueChange={field.onChange}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {(['ANDROID', 'IOS', 'NONE'] as const).map((d) => (
                      <SelectItem key={d} value={d}>
                        {t(`enums.device.${d}`)}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
          </FormField>

          {!editing && (
            <>
              <Separator />
              <p className="text-sm font-semibold">{t('students.fields.guardianSection')}</p>
              <div className="grid gap-4 sm:grid-cols-2">
                <FormField label={t('students.fields.guardianName')} htmlFor="guardianName">
                  <Input id="guardianName" {...form.register('guardianName')} />
                </FormField>
                <FormField label={t('students.fields.guardianPhone')} htmlFor="guardianPhone" hint="+998 90 123 45 67">
                  <Input id="guardianPhone" inputMode="tel" {...form.register('guardianPhone')} />
                </FormField>
              </div>
              <FormField label={t('students.fields.relation')}>
                <Controller
                  control={form.control}
                  name="guardianRelation"
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
            </>
          )}

          <DialogFooter className="mt-2">
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" loading={pending}>
              {t('common.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
