'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { useEffect, useRef, useState } from 'react';
import { useForm } from 'react-hook-form';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { clockMinute } from '@/data/mock/clock';
import type { StudentRow } from '@/data/mock/services/students';
import { earlyExitInputSchema, type EarlyExitInput } from '@/data/schemas/attendance';
import { useI18n } from '@/i18n';
import { minutesToHhmm } from '@/lib/utils';
import { useCreateEarlyExit } from '../hooks';
import { StudentPicker } from './student-picker';

const LEAD_MINUTES = 30;
const ROUND_TO = 5;
const LATEST_MINUTE = 23 * 60 + 55;

/** Taklif etilgan ketish vaqti: hozirdan ~30 daqiqa keyin, 5 daqiqaga yaxlitlangan. */
function suggestedTime(): string {
  const minute = Math.ceil((clockMinute() + LEAD_MINUTES) / ROUND_TO) * ROUND_TO;
  return minutesToHhmm(Math.min(minute, LATEST_MINUTE));
}

const EMPTY: EarlyExitInput = { studentId: '', time: '12:00', reason: '', pickupBy: '' };

export function EarlyExitDialog({
  open,
  onOpenChange,
  defaultStudent,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** O'quvchi kartasidan ochilganda — tanlangan holda keladi (o'zgartirish mumkin). */
  defaultStudent?: StudentRow | null;
}) {
  const { t } = useI18n();
  const create = useCreateEarlyExit();
  const [student, setStudent] = useState<StudentRow | null>(null);
  const form = useForm<EarlyExitInput>({ resolver: zodResolver(earlyExitInputSchema), defaultValues: EMPTY });

  // Faqat ochilganda to'ldiriladi (jonli yangilanishda tanlov o'chmasin).
  const defaultId = defaultStudent?.id ?? null;
  const defaultRef = useRef(defaultStudent ?? null);
  defaultRef.current = defaultStudent ?? null;
  useEffect(() => {
    if (!open) return;
    const initial = defaultRef.current;
    setStudent(initial);
    form.reset({ ...EMPTY, studentId: initial?.id ?? '', time: suggestedTime() });
  }, [open, defaultId, form]);

  const pick = (next: StudentRow | null) => {
    setStudent(next);
    form.setValue('studentId', next?.id ?? '', { shouldValidate: form.formState.isSubmitted });
  };

  const submit = form.handleSubmit(async (values) => {
    await create.mutateAsync(values);
    onOpenChange(false);
  });

  const { errors } = form.formState;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{t('attendance.earlyExit.createTitle')}</DialogTitle>
          <DialogDescription>{t('attendance.earlyExit.createHint')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4" noValidate>
          <FormField label={t('attendance.earlyExit.fields.student')} error={errors.studentId ? { message: 'errors.form.required' } : undefined}>
            <StudentPicker value={student} onChange={pick} invalid={Boolean(errors.studentId)} />
          </FormField>
          <div className="grid gap-4 sm:grid-cols-[140px_1fr]">
            <FormField label={t('attendance.earlyExit.fields.time')} htmlFor="exit-time" error={errors.time}>
              <Input id="exit-time" type="time" {...form.register('time')} />
            </FormField>
            <FormField label={t('attendance.earlyExit.fields.pickupBy')} htmlFor="exit-pickup" error={errors.pickupBy}>
              <Input id="exit-pickup" placeholder={t('attendance.earlyExit.fields.pickupByPlaceholder')} {...form.register('pickupBy')} />
            </FormField>
          </div>
          {student && student.guardianNames.length > 0 && (
            <div className="-mt-2 flex flex-wrap items-center gap-2 text-xs">
              <span className="text-muted-foreground">{t('attendance.earlyExit.fields.guardianSuggestions')}:</span>
              {student.guardianNames.map((name) => (
                <button
                  key={name}
                  type="button"
                  onClick={() => form.setValue('pickupBy', name, { shouldValidate: true })}
                  className="rounded-full bg-white/60 px-2.5 py-1 font-medium ring-1 ring-inset ring-border/60 transition-colors hover:bg-primary/[0.06] hover:text-primary dark:bg-white/[0.04]"
                >
                  {name}
                </button>
              ))}
            </div>
          )}
          <FormField label={t('attendance.earlyExit.fields.reason')} htmlFor="exit-reason" error={errors.reason}>
            <Textarea id="exit-reason" rows={3} placeholder={t('attendance.earlyExit.fields.reasonPlaceholder')} {...form.register('reason')} />
          </FormField>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" loading={create.isPending}>
              {t('common.create')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
