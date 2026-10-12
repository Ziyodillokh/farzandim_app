'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { useEffect } from 'react';
import { Controller, useForm } from 'react-hook-form';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Switch } from '@/components/ui/switch';
import { Textarea } from '@/components/ui/textarea';
import type { ReminderRepeat } from '@/data/contracts';
import { clockNow } from '@/data/mock/clock';
import type { ReminderRow } from '@/data/mock/services/comms';
import { reminderInputSchema, type ReminderInput } from '@/data/schemas/comms';
import { AudiencePicker } from '@/features/messages/components/audience-picker';
import { MessagePhonePreview } from '@/features/messages/components/message-preview';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useCreateReminder, useUpdateReminder } from '../hooks';
import { KindIcon, REMINDER_KINDS } from './kind-icon';

const REPEATS: readonly ReminderRepeat[] = ['NONE', 'WEEKLY', 'MONTHLY'];
const DEFAULT_HOUR = 9;

function tomorrowAt(hour: number): string {
  const d = clockNow();
  d.setDate(d.getDate() + 1);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(hour)}:00`;
}

function emptyValues(): ReminderInput {
  return { kind: 'MEETING', title: '', body: '', audience: { kind: 'SCHOOL', classIds: [], guardianIds: [] }, sendAt: tomorrowAt(DEFAULT_HOUR), repeat: 'NONE', active: true };
}

/** Yangi eslatma yoki tahrirlash — chapda forma, o'ngda telefon maketida jonli ko'rinish. */
export function ReminderFormDialog({ open, onOpenChange, reminder }: { open: boolean; onOpenChange: (open: boolean) => void; reminder?: ReminderRow | null }) {
  const { t, formatDate } = useI18n();
  const create = useCreateReminder();
  const update = useUpdateReminder();
  const form = useForm<ReminderInput>({ resolver: zodResolver(reminderInputSchema), defaultValues: emptyValues() });

  useEffect(() => {
    if (!open) return;
    form.reset(
      reminder
        ? { kind: reminder.kind, title: reminder.title, body: reminder.body, audience: reminder.audience, sendAt: reminder.sendAt.slice(0, 16), repeat: reminder.repeat, active: reminder.active }
        : emptyValues(),
    );
  }, [open, reminder, form]);

  const values = form.watch();
  const { errors } = form.formState;
  const sendDate = values.sendAt ? new Date(values.sendAt) : null;
  const sendLabel = sendDate && !Number.isNaN(sendDate.getTime()) ? formatDate(sendDate, 'd MMM, HH:mm') : '—';
  const audienceError = errors.audience?.classIds?.message ?? errors.audience?.guardianIds?.message;

  const submit = form.handleSubmit(async (input) => {
    const changed = !reminder || input.sendAt !== reminder.sendAt.slice(0, 16);
    if (changed && new Date(input.sendAt).getTime() <= clockNow().getTime()) {
      form.setError('sendAt', { message: t('reminders.form.futureOnly') });
      return;
    }
    try {
      if (reminder) await update.mutateAsync({ id: reminder.id, input });
      else await create.mutateAsync(input);
      onOpenChange(false);
    } catch {
      // Xato toast orqali ko'rsatildi.
    }
  });

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-5xl">
        <DialogHeader>
          <DialogTitle>{reminder ? t('reminders.form.editTitle') : t('reminders.form.createTitle')}</DialogTitle>
          <DialogDescription>{t('reminders.subtitle')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={(e) => void submit(e)} noValidate className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_290px]">
          <div className="min-w-0 space-y-4">
            <FormField label={t('reminders.form.kind')}>
              <div className="grid grid-cols-2 gap-2 sm:grid-cols-3" role="radiogroup">
                {REMINDER_KINDS.map((kind) => (
                  <button
                    key={kind}
                    type="button"
                    role="radio"
                    aria-checked={values.kind === kind}
                    onClick={() => form.setValue('kind', kind)}
                    className={cn(
                      'flex items-center gap-2.5 rounded-xl border p-2 text-left text-sm font-medium transition-all',
                      values.kind === kind ? 'border-primary bg-primary/[0.06] ring-1 ring-primary/30' : 'hover:border-primary/40',
                    )}
                  >
                    <KindIcon kind={kind} className="h-8 w-8 rounded-lg [&_svg]:size-4" />
                    <span className="leading-tight">{t(`enums.reminderKind.${kind}`)}</span>
                  </button>
                ))}
              </div>
            </FormField>
            <FormField label={t('reminders.form.title')} htmlFor="rem-title" error={errors.title}>
              <Input id="rem-title" placeholder={t('reminders.form.titlePlaceholder')} {...form.register('title')} />
            </FormField>
            <FormField label={t('reminders.form.body')} htmlFor="rem-body" error={errors.body}>
              <Textarea id="rem-body" rows={3} placeholder={t('reminders.form.bodyPlaceholder')} {...form.register('body')} />
            </FormField>
            <div className="grid gap-4 sm:grid-cols-2">
              <FormField label={t('reminders.form.sendAt')} htmlFor="rem-at" error={errors.sendAt}>
                <Input id="rem-at" type="datetime-local" {...form.register('sendAt')} />
              </FormField>
              <FormField label={t('reminders.form.repeat')}>
                <Controller
                  control={form.control}
                  name="repeat"
                  render={({ field }) => (
                    <Select value={field.value} onValueChange={field.onChange}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {REPEATS.map((r) => (
                          <SelectItem key={r} value={r}>
                            {t(`enums.reminderRepeat.${r}`)}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
              </FormField>
            </div>
            <FormField label={t('reminders.form.audience')}>
              <AudiencePicker
                value={{ kind: values.audience.kind, classIds: values.audience.classIds ?? [], guardianIds: values.audience.guardianIds ?? [] }}
                onChange={(next) => form.setValue('audience', next, { shouldValidate: form.formState.isSubmitted })}
                canSchool
                error={audienceError}
              />
            </FormField>
            <label className="flex items-center justify-between gap-4 rounded-xl border p-3">
              <span>
                <span className="block text-sm font-medium">{t('reminders.form.active')}</span>
                <span className="block text-xs text-muted-foreground">{t('reminders.form.activeHint')}</span>
              </span>
              <Switch checked={values.active ?? true} onCheckedChange={(active) => form.setValue('active', active)} />
            </label>
          </div>

          <div className="hidden space-y-2 lg:block">
            <p className="text-center text-xs font-medium text-muted-foreground">{t('reminders.form.preview')}</p>
            <MessagePhonePreview
              className="w-[270px]"
              title={values.title}
              body={values.body}
              meta={t('reminders.previewMeta', { date: sendLabel })}
              time={values.sendAt?.slice(11, 16) || undefined}
            />
          </div>

          <DialogFooter className="gap-2 lg:col-span-2">
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
