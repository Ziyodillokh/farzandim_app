'use client';

import { useEffect, useState } from 'react';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import type { VerificationRow } from '@/data/mock/services/comms';
import { MESSAGE_BODY_MAX } from '@/data/schemas/comms';
import { useI18n } from '@/i18n';
import { useAnswerVerification } from '../hooks';

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/** Ota-onaga javob; ixtiyoriy — bog'liq eslatma sanasini ham to'g'rilash. */
export function VerificationAnswerDialog({ request, onOpenChange }: { request: VerificationRow | null; onOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const answer = useAnswerVerification();
  const [text, setText] = useState('');
  const [changeDate, setChangeDate] = useState(false);
  const [date, setDate] = useState('');
  const [touched, setTouched] = useState(false);

  useEffect(() => {
    if (!request) return;
    setText(request.answer ?? '');
    setChangeDate(false);
    setDate(request.payment?.nextDate ?? '');
    setTouched(false);
  }, [request]);

  const textMissing = text.trim().length === 0;
  const textTooLong = text.length > MESSAGE_BODY_MAX;
  const dateInvalid = changeDate && !ISO_DATE.test(date);

  const submit = async () => {
    setTouched(true);
    if (!request || textMissing || textTooLong || dateInvalid) return;
    try {
      await answer.mutateAsync({ id: request.id, input: { text: text.trim(), newDate: changeDate ? date : null } });
      onOpenChange(false);
    } catch {
      // Xato toast orqali ko'rsatildi.
    }
  };

  const textError = touched && textMissing ? t('errors.form.required') : textTooLong ? t('errors.form.tooLong', { max: MESSAGE_BODY_MAX }) : null;

  return (
    <Dialog open={Boolean(request)} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{t('reminders.verifications.answerTitle')}</DialogTitle>
          <DialogDescription>{request?.guardianName}</DialogDescription>
        </DialogHeader>
        {request && <p className="rounded-xl bg-muted/60 p-3 text-sm italic text-muted-foreground">“{request.message}”</p>}
        <FormField label={t('reminders.verifications.answerLabel')} htmlFor="ver-answer" hint={t('reminders.verifications.answerHint')} error={textError ? { message: textError } : undefined}>
          <Textarea id="ver-answer" rows={4} value={text} onChange={(e) => setText(e.target.value)} placeholder={t('reminders.verifications.answerPlaceholder')} autoFocus />
        </FormField>
        {request?.payment && (
          <div className="space-y-3 rounded-xl border p-3">
            <label className="flex cursor-pointer items-center gap-3 text-sm font-medium">
              <Checkbox checked={changeDate} onCheckedChange={(v) => setChangeDate(v === true)} />
              {t('reminders.verifications.changeDate')}
            </label>
            {changeDate && (
              <FormField label={t('reminders.verifications.newDate')} htmlFor="ver-date" error={touched && dateInvalid ? { message: 'errors.form.invalidDate' } : undefined}>
                <Input id="ver-date" type="date" value={date} onChange={(e) => setDate(e.target.value)} className="sm:w-56" />
              </FormField>
            )}
          </div>
        )}
        <DialogFooter className="gap-2">
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button onClick={() => void submit()} loading={answer.isPending}>
            {t('reminders.verifications.submit')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
