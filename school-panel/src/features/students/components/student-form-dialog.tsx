'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { Plus, X } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { Controller, useForm, type UseFormReturn } from 'react-hook-form';
import { toast } from 'sonner';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Separator } from '@/components/ui/separator';
import type { Student } from '@/data/contracts';
import {
  isGuardianDraftFilled,
  studentCreateFormSchema,
  type GuardianDraft,
  type StudentCreateFormValues,
} from '@/data/schemas/students';
import { useI18n } from '@/i18n';
import { useClassOptions, useCreateStudent, useUpdateStudent } from '../hooks';

type FormValues = StudentCreateFormValues;

const emptyGuardian = (relation: GuardianDraft['relation']): GuardianDraft => ({ fullName: '', phone: '+998 ', relation });

const EMPTY: FormValues = {
  lastName: '',
  firstName: '',
  middleName: '',
  gender: 'MALE',
  birthDate: '2014-01-01',
  classId: '',
  device: 'ANDROID',
  guardians: [emptyGuardian('MOTHER'), emptyGuardian('FATHER')],
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
    resolver: zodResolver(studentCreateFormSchema),
    defaultValues: EMPTY,
  });
  const [secondOpen, setSecondOpen] = useState(false);

  // Formani faqat ochilganda to'ldiramiz: jonli simulyator so'rovlarni tez-tez
  // yangilaydi va `student` obyekti almashadi — yozilayotgan matn o'chmasin.
  const wasOpen = useRef(false);
  useEffect(() => {
    if (open && !wasOpen.current) {
      setSecondOpen(false);
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
    const { guardians, ...fields } = values;
    if (student) {
      await update.mutateAsync({ id: student.id, input: fields });
    } else {
      const created = await create.mutateAsync({
        ...fields,
        guardians: guardians
          .filter(isGuardianDraftFilled)
          .map((g) => ({ fullName: g.fullName.trim(), phone: g.phone, relation: g.relation })),
      });
      if (created.reusedGuardians.length > 0) {
        toast.info(t('students.guardiansReused', { names: created.reusedGuardians.map((g) => g.fullName).join(', ') }));
      }
    }
    onOpenChange(false);
  });

  const removeSecond = () => {
    form.setValue('guardians.1', emptyGuardian('FATHER'));
    form.clearErrors('guardians.1');
    setSecondOpen(false);
  };

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
              <GuardianFields form={form} index={0} />
              {secondOpen ? (
                <>
                  <div className="flex items-center justify-between gap-3">
                    <p className="text-sm font-semibold">{t('students.fields.guardian2Section')}</p>
                    <Button type="button" variant="ghost" size="sm" onClick={removeSecond}>
                      <X />
                      {t('students.fields.removeGuardian')}
                    </Button>
                  </div>
                  <GuardianFields form={form} index={1} />
                </>
              ) : (
                <Button type="button" variant="outline" size="sm" className="justify-self-start" onClick={() => setSecondOpen(true)}>
                  <Plus />
                  {t('students.fields.addSecondGuardian')}
                </Button>
              )}
              <p className="text-xs text-muted-foreground">{t('students.fields.guardianReuseHint')}</p>
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

/** Bitta ota-ona: F.I.Sh., telefon va kimligi (`guardians.<index>`). */
function GuardianFields({ form, index }: { form: UseFormReturn<FormValues>; index: 0 | 1 }) {
  const { t } = useI18n();
  const errors = form.formState.errors.guardians?.[index];
  return (
    <>
      <div className="grid gap-4 sm:grid-cols-2">
        <FormField label={t('students.fields.guardianName')} htmlFor={`guardian-${index}-name`} error={errors?.fullName}>
          <Input id={`guardian-${index}-name`} {...form.register(`guardians.${index}.fullName`)} />
        </FormField>
        <FormField label={t('students.fields.guardianPhone')} htmlFor={`guardian-${index}-phone`} error={errors?.phone} hint="+998 90 123 45 67">
          <Input id={`guardian-${index}-phone`} inputMode="tel" {...form.register(`guardians.${index}.phone`)} />
        </FormField>
      </div>
      <FormField label={t('students.fields.relation')}>
        <Controller
          control={form.control}
          name={`guardians.${index}.relation`}
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
  );
}
