'use client';

import { ArrowRight, CalendarDays, CalendarRange } from 'lucide-react';
import { useEffect, useState } from 'react';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Textarea } from '@/components/ui/textarea';
import { addMonthsIso, type PaymentRow } from '@/data/mock/services/comms';
import { MAX_SHIFT_MONTHS } from '@/data/schemas/comms';
import { Segmented } from '@/features/messages/components/compose-sections';
import { INNER_TILE } from '@/features/messages/styles';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useBulkShift, useShiftPayment } from '../hooks';

type Mode = 'months' | 'date';
const MONTH_OPTIONS = Array.from({ length: MAX_SHIFT_MONTHS }, (_, i) => i + 1);
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/**
 * Eslatma sanasini surish: bitta oila (aniq sana yoki N oy) yoki ommaviy
 * (masalan, 4 oy oldindan to'laganlar). Asos (izoh) majburiy — audit uchun.
 */
export function PaymentShiftDialog({ targets, onOpenChange, onDone }: { targets: PaymentRow[]; onOpenChange: (open: boolean) => void; onDone?: () => void }) {
  const { t, tc, formatDate } = useI18n();
  const open = targets.length > 0;
  const single = targets.length === 1 ? targets[0] : null;
  const shift = useShiftPayment();
  const bulk = useBulkShift();
  const [mode, setMode] = useState<Mode>('date');
  const [months, setMonths] = useState(1);
  const [date, setDate] = useState('');
  const [markPrepaid, setMarkPrepaid] = useState(true);
  const [note, setNote] = useState('');
  const [touched, setTouched] = useState(false);

  useEffect(() => {
    if (!open) return;
    setMode(single ? 'date' : 'months');
    setMonths(1);
    setDate(single?.nextDate ?? targets[0]?.nextDate ?? '');
    setMarkPrepaid(!single);
    setNote('');
    setTouched(false);
  }, [open, single, targets]);

  const noteMissing = note.trim().length === 0;
  const dateInvalid = mode === 'date' && !ISO_DATE.test(date);
  const preview = single && (mode === 'months' ? addMonthsIso(single.nextDate, months) : ISO_DATE.test(date) ? date : null);

  const submit = async () => {
    setTouched(true);
    if (noteMissing || dateInvalid) return;
    try {
      if (single && mode === 'date') await shift.mutateAsync({ id: single.id, input: { nextDate: date, note } });
      else await bulk.mutateAsync({ ids: targets.map((p) => p.id), months: mode === 'months' ? months : undefined, date: mode === 'date' ? date : undefined, note, markPrepaid: mode === 'months' && markPrepaid });
      onDone?.();
      onOpenChange(false);
    } catch {
      // Xato toast orqali ko'rsatildi.
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{single ? t('reminders.payments.shift.title') : t('reminders.payments.shift.bulkTitle')}</DialogTitle>
          <DialogDescription>
            {single ? `${single.guardianName} · ${t('reminders.payments.shift.current', { date: formatDate(single.nextDate, 'd MMMM yyyy') })}` : t('reminders.payments.shift.bulkDescription', { families: tc('reminders.payments.familiesCount', targets.length) })}
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <Segmented<Mode>
            value={mode}
            onChange={setMode}
            options={[
              { value: 'months', label: t('reminders.payments.shift.modeMonths'), icon: <CalendarRange /> },
              { value: 'date', label: t('reminders.payments.shift.modeDate'), icon: <CalendarDays /> },
            ]}
          />
          {mode === 'months' ? (
            <div className="space-y-3">
              <FormField label={t('reminders.payments.shift.months')}>
                <Select value={String(months)} onValueChange={(v) => setMonths(Number(v))}>
                  <SelectTrigger className="sm:w-48">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {MONTH_OPTIONS.map((m) => (
                      <SelectItem key={m} value={String(m)}>
                        {tc('reminders.payments.prepaidMonths', m)}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </FormField>
              <label className={cn(INNER_TILE, 'flex cursor-pointer items-start gap-3 p-3')}>
                <Checkbox checked={markPrepaid} onCheckedChange={(v) => setMarkPrepaid(v === true)} className="mt-0.5" />
                <span>
                  <span className="block text-sm font-medium">{t('reminders.payments.shift.markPrepaid')}</span>
                  <span className="block text-xs text-muted-foreground">{t('reminders.payments.shift.markPrepaidHint')}</span>
                </span>
              </label>
            </div>
          ) : (
            <FormField label={t('reminders.payments.shift.date')} htmlFor="pay-date" error={touched && dateInvalid ? { message: 'errors.form.invalidDate' } : undefined}>
              <Input id="pay-date" type="date" value={date} onChange={(e) => setDate(e.target.value)} className="sm:w-56" />
            </FormField>
          )}

          {single && preview && (
            <div className={cn(INNER_TILE, 'flex items-center gap-3 px-4 py-3 text-sm tabular-nums')}>
              <span className="text-muted-foreground">{formatDate(single.nextDate, 'd MMM yyyy')}</span>
              <ArrowRight className="h-4 w-4 text-primary" />
              <span className="font-semibold">{formatDate(preview, 'd MMM yyyy')}</span>
            </div>
          )}

          <FormField label={t('reminders.payments.shift.note')} htmlFor="pay-note" error={touched && noteMissing ? { message: 'errors.form.required' } : undefined}>
            <Textarea id="pay-note" rows={2} value={note} onChange={(e) => setNote(e.target.value)} placeholder={t('reminders.payments.shift.notePlaceholder')} />
          </FormField>
        </div>

        <DialogFooter className="gap-2">
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button onClick={() => void submit()} loading={shift.isPending || bulk.isPending}>
            {t('reminders.payments.shift.submit')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
