'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { useEffect } from 'react';
import { Controller, useForm } from 'react-hook-form';

import { FormField } from '@/components/common/form-field';
import { AttendanceBadge } from '@/components/common/status-badges';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Textarea } from '@/components/ui/textarea';
import type { IsoDate } from '@/data/contracts';
import type { StudentDayRow } from '@/data/mock/services/attendance';
import { correctionSchema, type CorrectionInput } from '@/data/schemas/attendance';
import { useI18n } from '@/i18n';
import { useCorrectAttendance } from '../hooks';
import { ALL_STATUSES, fromIsoDate } from '../lib';

/** O'tgan kun holatini tuzatish — yangi holat + majburiy sabab (tarixga yoziladi). */
export function CorrectionDialog({ row, date, onClose }: { row: StudentDayRow | null; date: IsoDate; onClose: () => void }) {
  const { t, formatDate } = useI18n();
  const correct = useCorrectAttendance();
  const current = row?.record?.status ?? null;
  const form = useForm<CorrectionInput>({
    resolver: zodResolver(correctionSchema),
    defaultValues: { studentId: '', date, status: 'EXCUSED', reason: '' },
  });

  useEffect(() => {
    if (!row) return;
    const firstOther = ALL_STATUSES.find((s) => s !== row.record?.status) ?? 'EXCUSED';
    form.reset({ studentId: row.studentId, date, status: firstOther, reason: '' });
  }, [row, date, form]);

  const submit = form.handleSubmit(async (values) => {
    await correct.mutateAsync(values);
    onClose();
  });

  const { errors } = form.formState;

  return (
    <Dialog open={Boolean(row)} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t('attendance.correction.title')}</DialogTitle>
          <DialogDescription>
            {t('attendance.correction.description', { name: row?.name ?? '', date: formatDate(fromIsoDate(date), 'd MMMM yyyy') })}
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4" noValidate>
          <div className="flex items-center justify-between rounded-xl bg-white/50 px-3.5 py-2.5 text-sm ring-1 ring-inset ring-border/60 dark:bg-white/[0.03]">
            <span className="text-muted-foreground">{t('attendance.correction.current')}</span>
            <AttendanceBadge status={current} />
          </div>
          <FormField label={t('attendance.correction.newStatus')} error={errors.status}>
            <Controller
              control={form.control}
              name="status"
              render={({ field }) => (
                <Select value={field.value} onValueChange={field.onChange}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {ALL_STATUSES.filter((s) => s !== current).map((s) => (
                      <SelectItem key={s} value={s}>
                        {t(`enums.attendanceStatus.${s}`)}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
          </FormField>
          <FormField label={t('attendance.correction.reason')} htmlFor="correction-reason" error={errors.reason} hint={t('attendance.correction.reasonHint')}>
            <Textarea id="correction-reason" rows={3} placeholder={t('attendance.correction.reasonPlaceholder')} {...form.register('reason')} />
          </FormField>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" loading={correct.isPending}>
              {t('attendance.correction.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
