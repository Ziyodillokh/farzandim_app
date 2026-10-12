'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { Coffee, GraduationCap, Trash2 } from 'lucide-react';
import { useEffect } from 'react';
import { Controller, useFieldArray, useForm, useWatch } from 'react-hook-form';

import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import type { BellPeriodKind, IsoWeekday } from '@/data/contracts';
import type { ShiftRow } from '@/data/mock/services/school-mode';
import { MAX_PERIODS, shiftUpdateSchema } from '@/data/schemas/school-mode';
import { useI18n } from '@/i18n';
import { cn, hhmmToMinutes, minutesToHhmm } from '@/lib/utils';
import { useUpdateShift } from '../hooks';
import { isMessageKey, SEG_OFF, SEG_ON, SEG_TRACK, TILE } from '../lib';

type FormValues = { weekdays: number[]; periods: Array<{ start: string; end: string; kind: BellPeriodKind }> };

const WEEKDAYS: readonly IsoWeekday[] = [1, 2, 3, 4, 5, 6, 7];
const DEFAULT_MINUTES: Record<BellPeriodKind, number> = { LESSON: 45, BREAK: 10 };

function toValues(shift: ShiftRow): FormValues {
  return { weekdays: [...shift.weekdays], periods: shift.periods.map(({ start, end, kind }) => ({ start, end, kind })) };
}

function WeekdayPicker({ value, onChange }: { value: number[]; onChange: (next: number[]) => void }) {
  const { t } = useI18n();
  return (
    <div className="flex flex-wrap gap-1.5">
      {WEEKDAYS.map((d) => {
        const on = value.includes(d);
        return (
          <button
            key={d}
            type="button"
            aria-pressed={on}
            title={t(`enums.weekday.${d}`)}
            onClick={() => onChange(on ? value.filter((x) => x !== d) : [...value, d].sort((a, b) => a - b))}
            className={cn(
              'h-9 w-11 rounded-lg text-sm font-semibold ring-1 ring-inset transition-colors',
              on ? 'bg-primary/10 text-primary ring-primary/35' : 'text-muted-foreground ring-border/60 hover:ring-primary/40',
            )}
          >
            {t(`enums.weekdayShort.${d}`)}
          </button>
        );
      })}
    </div>
  );
}

/** Smena jadvalini tahrirlash: hafta kunlari va davrlar (qo'shish/o'chirish/vaqt). */
export function ShiftEditDialog({ shift, onOpenChange }: { shift: ShiftRow | null; onOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const update = useUpdateShift();
  const form = useForm<FormValues>({ resolver: zodResolver(shiftUpdateSchema), defaultValues: { weekdays: [], periods: [] } });
  const { fields, append, remove } = useFieldArray({ control: form.control, name: 'periods' });
  const periods = useWatch({ control: form.control, name: 'periods' });

  useEffect(() => {
    if (shift) form.reset(toValues(shift));
  }, [shift, form]);

  const add = (kind: BellPeriodKind) => {
    const last = periods.at(-1);
    const start = last && /^\d{2}:\d{2}$/.test(last.end) ? last.end : (shift?.start ?? '08:00');
    append({ kind, start, end: minutesToHhmm(hhmmToMinutes(start) + DEFAULT_MINUTES[kind]) });
  };

  const submit = form.handleSubmit((values) => {
    if (!shift) return;
    update.mutate({ id: shift.id, input: values }, { onSuccess: () => onOpenChange(false) });
  });

  const { errors } = form.formState;
  const tr = (message: string | undefined) => (isMessageKey(message) ? t(message) : message);
  const listError = errors.periods?.root?.message ?? errors.periods?.message;

  return (
    <Dialog open={Boolean(shift)} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>{t('schoolMode.schedule.editTitle', { name: shift?.name ?? '' })}</DialogTitle>
          <DialogDescription>{t('schoolMode.schedule.editDescription')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-5" noValidate>
          <div className="space-y-2">
            <Label>{t('schoolMode.schedule.weekdays')}</Label>
            <Controller control={form.control} name="weekdays" render={({ field }) => <WeekdayPicker value={field.value} onChange={field.onChange} />} />
            {errors.weekdays && <p className="text-xs font-medium text-destructive">{tr(errors.weekdays.message ?? errors.weekdays.root?.message)}</p>}
          </div>

          <div className="space-y-2">
            <div className="hidden grid-cols-[1fr_7rem_7rem_4rem_2.25rem] gap-2 px-1 text-xs font-medium text-muted-foreground sm:grid">
              <span>{t('schoolMode.schedule.kind')}</span>
              <span>{t('schoolMode.schedule.start')}</span>
              <span>{t('schoolMode.schedule.end')}</span>
              <span />
              <span />
            </div>
            <ol className="space-y-2">
              {fields.map((field, i) => {
                const row = periods[i];
                const minutes = row ? hhmmToMinutes(row.end) - hhmmToMinutes(row.start) : Number.NaN;
                const rowError = errors.periods?.[i];
                return (
                  <li key={field.id} className="space-y-1">
                    <div className={cn('grid grid-cols-2 items-center gap-2 p-2 sm:grid-cols-[1fr_7rem_7rem_4rem_2.25rem]', TILE, row?.kind === 'BREAK' && 'bg-transparent dark:bg-transparent')}>
                      <Controller
                        control={form.control}
                        name={`periods.${i}.kind`}
                        render={({ field: kindField }) => (
                          <div className={cn('col-span-2 grid grid-cols-2 gap-1 sm:col-span-1', SEG_TRACK)} role="radiogroup" aria-label={t('schoolMode.schedule.kind')}>
                            {(['LESSON', 'BREAK'] as const).map((k) => (
                              <button
                                key={k}
                                type="button"
                                role="radio"
                                aria-checked={kindField.value === k}
                                onClick={() => kindField.onChange(k)}
                                className={cn(
                                  'flex h-8 items-center justify-center gap-1.5 rounded-lg px-2 text-xs font-medium transition-all [&_svg]:h-3.5 [&_svg]:w-3.5',
                                  kindField.value === k ? SEG_ON : SEG_OFF,
                                )}
                              >
                                {k === 'LESSON' ? <GraduationCap /> : <Coffee />}
                                {t(`enums.bellKind.${k}`)}
                              </button>
                            ))}
                          </div>
                        )}
                      />
                      <Input type="time" step={60} aria-label={t('schoolMode.schedule.start')} aria-invalid={Boolean(rowError?.start)} {...form.register(`periods.${i}.start`)} />
                      <Input type="time" step={60} aria-label={t('schoolMode.schedule.end')} aria-invalid={Boolean(rowError?.end)} {...form.register(`periods.${i}.end`)} />
                      <span className="text-center text-xs tabular-nums text-muted-foreground">{Number.isFinite(minutes) && minutes > 0 ? t('schoolMode.schedule.minutes', { count: minutes }) : '—'}</span>
                      <Button type="button" variant="ghost" size="icon-sm" onClick={() => remove(i)} aria-label={t('schoolMode.schedule.remove')} disabled={fields.length <= 1}>
                        <Trash2 />
                      </Button>
                    </div>
                    {(rowError?.start || rowError?.end) && (
                      <p className="px-1 text-xs font-medium text-destructive">{tr(rowError.start?.message ?? rowError.end?.message)}</p>
                    )}
                  </li>
                );
              })}
            </ol>
            {listError && <p className="text-xs font-medium text-destructive">{tr(listError)}</p>}
            <div className="flex gap-2">
              <Button type="button" variant="outline" size="sm" onClick={() => add('LESSON')} disabled={fields.length >= MAX_PERIODS}>
                <GraduationCap />+ {t('schoolMode.schedule.addLesson')}
              </Button>
              <Button type="button" variant="outline" size="sm" onClick={() => add('BREAK')} disabled={fields.length >= MAX_PERIODS}>
                <Coffee />+ {t('schoolMode.schedule.addBreak')}
              </Button>
            </div>
          </div>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" loading={update.isPending}>
              {t('common.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
