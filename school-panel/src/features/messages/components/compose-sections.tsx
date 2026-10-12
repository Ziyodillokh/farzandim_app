'use client';

import { CalendarClock, Send, Star } from 'lucide-react';
import type { ReactNode } from 'react';
import { Controller, type UseFormReturn } from 'react-hook-form';

import { FormField } from '@/components/common/form-field';
import { SectionCard } from '@/components/common/section-card';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import type { MessagePriority } from '@/data/contracts';
import type { MessageTemplate } from '@/data/mock/services/comms';
import { type AnnouncementInput, MESSAGE_BODY_MAX, MESSAGE_TITLE_MAX, SMS_SEGMENT } from '@/data/schemas/comms';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { TemplatePicker } from './template-picker';

export type ScheduleMode = 'now' | 'later';

/** Segmentli tanlov (2–3 variant). */
export function Segmented<T extends string>({ value, onChange, options }: { value: T; onChange: (v: T) => void; options: Array<{ value: T; label: string; icon?: ReactNode }> }) {
  return (
    <div className="inline-flex rounded-lg bg-muted p-1" role="radiogroup">
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          role="radio"
          aria-checked={value === o.value}
          onClick={() => onChange(o.value)}
          className={cn(
            'inline-flex items-center gap-1.5 rounded-md px-3 py-1.5 text-sm font-medium transition-all [&_svg]:size-4',
            value === o.value ? 'bg-card text-foreground shadow-soft' : 'text-muted-foreground hover:text-foreground',
          )}
        >
          {o.icon}
          {o.label}
        </button>
      ))}
    </div>
  );
}

/** Sarlavha, matn (belgi hisoblagichi + SMS qismlari), muhimlik va shablonlar. */
export function ContentSection({ form, onTemplate }: { form: UseFormReturn<AnnouncementInput>; onTemplate: (tpl: MessageTemplate) => void }) {
  const { t } = useI18n();
  const { errors } = form.formState;
  /** "Ko'pi bilan {max} ta belgi" — chegarani matnga qo'yib beradi. */
  const withMax = (error: { message?: string } | undefined, max: number) =>
    error?.message === 'errors.form.tooLong' ? { message: t('errors.form.tooLong', { max }) } : error;
  const body = form.watch('body') ?? '';
  const smsParts = Math.max(1, Math.ceil(body.length / SMS_SEGMENT));
  const over = body.length > MESSAGE_BODY_MAX;

  return (
    <SectionCard title={t('messages.compose.content')} actions={<TemplatePicker onPick={onTemplate} />}>
      <div className="space-y-4">
        <FormField label={t('messages.compose.titleLabel')} htmlFor="msg-title" error={withMax(errors.title, MESSAGE_TITLE_MAX)}>
          <Input id="msg-title" placeholder={t('messages.compose.titlePlaceholder')} {...form.register('title')} />
        </FormField>
        <FormField label={t('messages.compose.bodyLabel')} htmlFor="msg-body" error={withMax(errors.body, MESSAGE_BODY_MAX)}>
          <Textarea id="msg-body" rows={7} placeholder={t('messages.compose.bodyPlaceholder')} {...form.register('body')} />
          <div className="flex items-center justify-between text-2xs text-muted-foreground tabular-nums">
            <span>{t('messages.compose.smsParts', { count: smsParts })}</span>
            <span className={cn(over && 'font-semibold text-destructive')}>{t('messages.compose.chars', { count: body.length, max: MESSAGE_BODY_MAX })}</span>
          </div>
        </FormField>
        <Controller
          control={form.control}
          name="priority"
          render={({ field }) => (
            <FormField label={t('messages.compose.priority')} hint={t(`messages.compose.priorityHint.${field.value}`)}>
              <div>
                <Segmented<MessagePriority>
                  value={field.value}
                  onChange={field.onChange}
                  options={[
                    { value: 'NORMAL', label: t('enums.messagePriority.NORMAL') },
                    { value: 'IMPORTANT', label: t('enums.messagePriority.IMPORTANT'), icon: <Star className="text-warning" /> },
                  ]}
                />
              </div>
            </FormField>
          )}
        />
      </div>
    </SectionCard>
  );
}

/** Darhol yoki rejalashtirilgan yuborish. */
export function ScheduleSection({
  mode,
  onModeChange,
  value,
  onValueChange,
  invalid,
}: {
  mode: ScheduleMode;
  onModeChange: (mode: ScheduleMode) => void;
  value: string;
  onValueChange: (value: string) => void;
  invalid: boolean;
}) {
  const { t } = useI18n();
  return (
    <SectionCard title={t('messages.compose.when')}>
      <div className="flex flex-wrap items-end gap-4">
        <Segmented<ScheduleMode>
          value={mode}
          onChange={onModeChange}
          options={[
            { value: 'now', label: t('messages.compose.now'), icon: <Send /> },
            { value: 'later', label: t('messages.compose.later'), icon: <CalendarClock /> },
          ]}
        />
        {mode === 'later' && (
          <FormField label={t('messages.compose.scheduleAt')} htmlFor="msg-at" className="w-full sm:w-64" error={invalid ? { message: t('messages.compose.schedulePast') } : undefined}>
            <Input id="msg-at" type="datetime-local" value={value} onChange={(e) => onValueChange(e.target.value)} aria-invalid={invalid} />
          </FormField>
        )}
      </div>
    </SectionCard>
  );
}
